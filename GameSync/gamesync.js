#!/usr/bin/env node
// OSYNC GameSync - copy game folders from a SOURCE master to DESTINATION masters, changed files only.
//
//   source:       node gamesync.js serve           index the games (file list + sha256) and share them over HTTP
//                 node gamesync.js index           one index pass, then exit
//   destination:  node gamesync.js pull [--watch]  download what changed, move removed files to X:\_ลบได้
//                 node gamesync.js list            what pull would do, without downloading
//   both:         node gamesync.js status
//   options:      --only "<id or name, * allowed>"   --dry-run   --verify (destination: check every file)
//
// Settings: GameSync\gamesync.json (made from gamesync.example.json on first run, not in git: it holds the key).
// Data:     GameSync\_data\  (index\ on the source, state\ on the destination, gamesync.log)
// Runs on Node.js 18+ or on the GCafe app itself: set ELECTRON_RUN_AS_NODE=1 and start 0JAYSHOP.exe gamesync.js ...
// No packages needed. See GameSync\README-TH.md.
'use strict';
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const http = require('node:http');
const zlib = require('node:zlib');
const os = require('node:os');
const { execFileSync, spawn } = require('node:child_process');

const VERSION = 1;
const HERE = __dirname;
const OSYNC = path.dirname(HERE);
const CONFIG_FILE = process.env.GAMESYNC_CONFIG || path.join(HERE, 'gamesync.json');
const DATA = process.env.GAMESYNC_DATA || path.join(HERE, '_data');
const TRASH_NAME = '_ลบได้';                    // the shop rule: never delete, move here (same drive = instant)
const PART = '.gsync-part';                     // file being downloaded
const STAGE = '.gsync-new';                     // new game being downloaded (renamed into place when complete)
const HASH_CHUNK = 4 * 1024 * 1024;

// ---------------------------------------------------------------- small helpers
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const fmtBytes = (n) => (n >= 1 << 30 ? (n / (1 << 30)).toFixed(1) + ' GB' : n >= 1 << 20 ? (n / (1 << 20)).toFixed(1) + ' MB' : Math.round(n / 1024) + ' KB');
const safeName = (id) => id.replace(/[^A-Za-z0-9._-]+/g, '_').slice(0, 120) + '-' + crypto.createHash('sha1').update(id).digest('hex').slice(0, 8);
const sameMtime = (a, b) => Math.abs(a - b) < 2;   // ms; NTFS keeps 100 ns, Node gives float ms

let logStream = null;
function log(msg) {
  const line = `${new Date().toISOString().replace('T', ' ').slice(0, 19)} ${msg}`;
  console.log(line);
  try {
    if (!logStream) {
      fs.mkdirSync(DATA, { recursive: true });
      const f = path.join(DATA, 'gamesync.log');
      try { if (fs.statSync(f).size > 5 * 1024 * 1024) fs.renameSync(f, f + '.old'); } catch { }
      logStream = fs.createWriteStream(f, { flags: 'a' });
    }
    logStream.write(line + '\n');
  } catch { }
}

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch { return fallback; }
}
function writeJsonAtomic(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(obj));
  fs.renameSync(tmp, file);
}

// "02:00-08:00" (may cross midnight). Empty = always.
function inHours(spec, now = new Date()) {
  if (!spec) return true;
  const m = /^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/.exec(String(spec).trim());
  if (!m) return true;
  const a = +m[1] * 60 + +m[2], b = +m[3] * 60 + +m[4], t = now.getHours() * 60 + now.getMinutes();
  return a <= b ? t >= a && t < b : t >= a || t < b;
}

// "*" wildcard match on game id or name, case-insensitive
function matches(game, patterns) {
  return patterns.some((p) => {
    const re = new RegExp('^' + String(p).split('*').map((s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*') + '$', 'i');
    return re.test(game.id) || re.test(game.name) || re.test(game.title || '');
  });
}
function selected(game, opt) {
  if (opt.only.length) return matches(game, opt.only);
  if (opt.include.length && !matches(game, opt.include)) return false;
  return !(opt.exclude.length && matches(game, opt.exclude));
}

// throttle: bytes per second shared by everything that calls take()
class Limiter {
  constructor(mbps) { this.rate = (+mbps || 0) * 1024 * 1024; this.next = 0; }
  async take(n) {
    if (!this.rate) return;
    const now = Date.now();
    const start = Math.max(now, this.next);
    this.next = start + (n / this.rate) * 1000;
    if (start > now) await sleep(start - now);
  }
}

async function hashFile(file, limiter, from = 0, hash = crypto.createHash('sha256')) {
  const fh = await fsp.open(file, 'r');
  try {
    const buf = Buffer.allocUnsafe(HASH_CHUNK);
    let pos = from;
    for (;;) {
      const { bytesRead } = await fh.read(buf, 0, buf.length, pos);
      if (!bytesRead) break;
      if (limiter) await limiter.take(bytesRead);
      hash.update(buf.subarray(0, bytesRead));
      pos += bytesRead;
    }
    return hash;
  } finally { await fh.close(); }
}

// ---------------------------------------------------------------- settings
const DEFAULTS = {
  key: '',
  source: {
    drives: 'EFHI', categories: ['Online', 'Mobile', 'PvP', 'Single Player', 'Web', 'Common'], steam: true,
    include: [], exclude: [], port: 18765, bind: '0.0.0.0', readLimitMBps: 0, indexHours: '', reindexMinutes: 60,
  },
  pull: {
    url: '', drives: '', include: [], exclude: [], hours: '', everyMinutes: 30, parallel: 4, downloadLimitMBps: 0,
    moveRemoved: true, skipAutoSyncFolders: true, afterSync: 'update-all',
  },
};

function loadConfig() {
  if (!fs.existsSync(CONFIG_FILE)) {
    const ex = path.join(HERE, 'gamesync.example.json');
    if (fs.existsSync(ex) && !process.env.GAMESYNC_CONFIG) fs.copyFileSync(ex, CONFIG_FILE);
  }
  const raw = readJson(CONFIG_FILE, {});
  const cfg = { key: raw.key || '', source: { ...DEFAULTS.source, ...(raw.source || {}) }, pull: { ...DEFAULTS.pull, ...(raw.pull || {}) } };
  return { cfg, raw };
}
function ensureKey(cfg, raw) {
  if (cfg.key) return cfg.key;
  cfg.key = raw.key = crypto.randomBytes(18).toString('base64url');
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(raw, null, 2));
  log(`made a new key in ${CONFIG_FILE} - copy it to the "key" of each destination`);
  return cfg.key;
}

// "EFHI" -> {E:'E:\\', ...};  {"E":"E:\\", "T":"D:\\test"} kept;  {"E":"H"} -> {E:'H:\\'}
function parseDrives(spec) {
  const out = {};
  if (typeof spec === 'string') { for (const c of spec.toUpperCase().replace(/[^A-Z]/g, '')) out[c] = c + ':\\'; return out; }
  for (const [k, v] of Object.entries(spec || {})) {
    const s = String(v);
    out[k.toUpperCase()[0]] = /^[A-Za-z]:?\\?$/.test(s) ? s[0].toUpperCase() + ':\\' : path.resolve(s);
  }
  return out;
}

// ---------------------------------------------------------------- AutoSync (old game system) - read only
// Its game list is one JSON object per line: game_name, dir (e.g. "E:\\Online"), first_exe (start exe), poster_game.
// Lines are only ever added: a later line with the same _id replaces the earlier one, {"$$deleted":true} removes it.
function readAutoSyncGames() {
  const out = new Map();
  const file = path.join(process.env.LOCALAPPDATA || '', 'AutoSync', 'db', 'gameClient.db');
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch { return out; }
  const byId = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue;
    try { const g = JSON.parse(line); if (g.$$deleted) byId.delete(g._id); else byId.set(g._id, g); } catch { }
  }
  for (const g of byId.values()) {
    if (g.game_name && g.dir) out.set(path.join(g.dir, g.game_name).toLowerCase(), { exe: g.first_exe || '', poster: g.poster_game || '' });
  }
  return out;
}

// ---------------------------------------------------------------- SOURCE: find games
function listDirs(dir) {
  try { return fs.readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory() && !d.name.startsWith('$') && !d.name.endsWith(STAGE)); } catch { return []; }
}
function parseAcf(text) {
  const get = (k) => (new RegExp(`"${k}"\\s+"([^"]*)"`, 'i').exec(text) || [])[1] || '';
  return { appid: get('appid'), name: get('name'), installdir: get('installdir'), state: get('StateFlags') };
}

function discoverGames(scfg) {
  const games = [];
  const autosync = readAutoSyncGames();
  for (const [letter, root] of Object.entries(parseDrives(scfg.drives))) {
    for (const cat of scfg.categories) {
      for (const d of listDirs(path.join(root, cat))) {
        const gameRoot = path.join(root, cat, d.name);
        const a = autosync.get(gameRoot.toLowerCase());
        games.push({ id: `${letter}/${cat}/${d.name}`, kind: 'folder', drive: letter, cat, name: d.name, title: d.name, root: gameRoot,
          start: a && a.exe ? a.exe : '', poster: fs.existsSync(path.join(gameRoot, 'zPoster.jpg')) ? 'zPoster.jpg' : '', autosync: !!a });
      }
    }
    if (!scfg.steam) continue;
    // Steam libraries on this drive: X:\SteamLibrary and a Steam install folder X:\steam
    for (const libRel of ['SteamLibrary', 'steam', 'Steam']) {
      const apps = path.join(root, libRel, 'steamapps');
      let names = [];
      try { names = fs.readdirSync(apps).filter((n) => /^appmanifest_\d+\.acf$/i.test(n)); } catch { continue; }
      for (const n of names) {
        const acf = parseAcf(fs.readFileSync(path.join(apps, n), 'utf8'));
        if (!acf.appid || !acf.installdir || !fs.existsSync(path.join(apps, 'common', acf.installdir))) continue;
        if (games.some((g) => g.id === `${letter}/steam/${acf.appid}`)) continue;   // "steam" and "Steam" are the same folder
        games.push({ id: `${letter}/steam/${acf.appid}`, kind: 'steam', drive: letter, cat: 'Steam', name: acf.installdir, title: acf.name || acf.installdir,
          root: apps, libRel, steam: { appid: acf.appid, installdir: acf.installdir, acf: n, ready: acf.state === '4' } });
      }
    }
  }
  return games;
}

// ---------------------------------------------------------------- SOURCE: index one game
// Manifest: files [[relPath, size, mtimeMs, sha256]], dirs [relPath] (keeps empty folders), links [[relPath, target]].
// The sha256 of a file is kept while its size and time stay the same, so a re-index only reads what changed.
async function walk(root, onlyPrefix) {
  const files = [], dirs = [], links = [];
  const stack = [''];
  while (stack.length) {
    const rel = stack.pop();
    let ents;
    try { ents = await fsp.readdir(path.join(root, rel), { withFileTypes: true }); } catch { continue; }
    for (const e of ents) {
      const r = rel ? rel + '/' + e.name : e.name;
      if (onlyPrefix && !onlyPrefix.some((p) => r === p || r.startsWith(p + '/') || p.startsWith(r + '/'))) continue;
      if (e.name.endsWith(PART) || e.name.endsWith('.tmp-gsync')) continue;
      if (e.isSymbolicLink()) { try { links.push([r, await fsp.readlink(path.join(root, r))]); } catch { } continue; }
      if (e.isDirectory()) { dirs.push(r); stack.push(r); continue; }
      if (e.isFile()) files.push(r);
    }
  }
  return { files, dirs, links };
}

async function indexGame(game, limiter) {
  const file = path.join(DATA, 'index', safeName(game.id) + '.json');
  const prev = readJson(file, null);
  const old = new Map((prev && prev.files || []).map((f) => [f[0], f]));
  const startedAt = Date.now();
  const only = game.kind === 'steam' ? ['common/' + game.steam.installdir, game.steam.acf] : null;
  const w = await walk(game.root, only);
  const files = [];
  let total = 0, hashed = 0, unstable = '';
  let lastShow = Date.now(), lastSave = Date.now();
  for (const rel of w.files.sort()) {
    const full = path.join(game.root, rel);
    let st;
    try { st = await fsp.stat(full); } catch { continue; }
    const o = old.get(rel);
    let sha = o && o[1] === st.size && sameMtime(o[2], st.mtimeMs) ? o[3] : '';
    if (!sha) {
      try { sha = (await hashFile(full, limiter)).digest('hex'); } catch (e) { unstable = `cannot read ${rel}: ${e.code || e.message}`; break; }
      hashed += st.size;
      const after = await fsp.stat(full).catch(() => null);
      if (!after || after.size !== st.size || !sameMtime(after.mtimeMs, st.mtimeMs)) { unstable = `${rel} changed while reading`; break; }
      // big games take a while: show progress, and keep the hashes done so far in case the window is closed
      if (Date.now() - lastShow > (+process.env.GAMESYNC_PROGRESS_MS || 60000)) { lastShow = Date.now(); log(`index: ${game.id}  reading... ${fmtBytes(hashed)} so far`); }
      if (Date.now() - lastSave > (+process.env.GAMESYNC_SAVE_MS || 300000)) {
        lastSave = Date.now();
        const done = new Set(files.map((f) => f[0]));
        writeJsonAtomic(file, { ...game, files: [...files, [rel, st.size, st.mtimeMs, sha], ...[...old.values()].filter((f) => !done.has(f[0]) && f[0] !== rel)], dirs: [], links: [], size: 0, version: '', unstable: 'index not finished' });
      }
    }
    // written since this index began (a time far in the future is a wrong clock in the file, not a write)
    if (st.mtimeMs > startedAt && st.mtimeMs < Date.now() + 60000) { unstable = `${rel} is being written`; break; }
    files.push([rel, st.size, st.mtimeMs, sha]);
    total += st.size;
  }
  if (game.kind === 'steam' && !game.steam.ready) unstable = 'Steam is updating it (StateFlags is not 4)';
  const version = crypto.createHash('sha256').update(JSON.stringify(files.map((f) => [f[0], f[1], f[3]]))).update(JSON.stringify(w.links)).digest('hex').slice(0, 20);
  const man = { ...game, files, dirs: w.dirs.sort(), links: w.links, size: total, version, indexedAt: new Date().toISOString(), unstable };
  writeJsonAtomic(file, man);
  return { man, hashed };
}

// ---------------------------------------------------------------- SOURCE: serve
function publicEntry(m) {
  const { files, dirs, links, root, ...meta } = m;
  return { ...meta, fileCount: files.length };
}

async function serve(cfg, opt, raw) {
  const key = ensureKey(cfg, raw);
  const scfg = cfg.source;
  const limiter = new Limiter(scfg.readLimitMBps);
  const published = new Map();           // id -> manifest (only games that indexed cleanly)
  const fileIndex = new Map();           // id -> Map(rel -> file entry)
  const gzCache = new Map();             // id -> gzipped manifest

  // a game being updated (or gone) is taken off the list until it indexes cleanly again
  function publish(man) {
    gzCache.delete(man.id);
    if (man.unstable || man.gone) { published.delete(man.id); fileIndex.delete(man.id); return; }
    published.set(man.id, man);
    fileIndex.set(man.id, new Map(man.files.map((f) => [f[0], f])));
  }
  fs.mkdirSync(path.join(DATA, 'index'), { recursive: true });
  for (const f of fs.readdirSync(path.join(DATA, 'index')).filter((n) => n.endsWith('.json'))) {
    const m = readJson(path.join(DATA, 'index', f), null);
    if (m && m.id && fs.existsSync(m.root)) publish(m);
  }
  log(`source: ${published.size} games ready from the last index`);

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    const send = (code, body, type = 'application/json') => { res.writeHead(code, { 'Content-Type': type }); res.end(typeof body === 'string' ? body : JSON.stringify(body)); };
    const given = Buffer.from(String(req.headers['x-osync-key'] || ''));
    const want = Buffer.from(key);
    if (given.length !== want.length || !crypto.timingSafeEqual(given, want)) return send(401, { error: 'wrong key' });
    try {
      if (url.pathname === '/api/ping') return send(200, { ok: true, name: os.hostname(), version: VERSION, games: published.size });
      if (url.pathname === '/api/catalog') return send(200, { name: os.hostname(), games: [...published.values()].map(publicEntry) });
      const id = url.searchParams.get('id') || '';
      const man = published.get(id);
      if (url.pathname === '/api/manifest') {
        if (!man) return send(404, { error: 'no such game' });
        let gz = gzCache.get(id);
        if (!gz) { const { root, ...rest } = man; gz = zlib.gzipSync(JSON.stringify(rest)); gzCache.set(id, gz); }
        res.writeHead(200, { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip', 'Content-Length': gz.length });
        return res.end(gz);
      }
      if (url.pathname === '/api/file') {
        const entry = man && fileIndex.get(id).get(url.searchParams.get('path') || '');
        if (!entry) return send(404, { error: 'no such file' });       // only files from the index: nothing else can be read
        const full = path.join(man.root, entry[0]);
        const st = await fsp.stat(full).catch(() => null);
        if (!st || st.size !== entry[1] || !sameMtime(st.mtimeMs, entry[2])) return send(409, { error: 'changed on the source, try again after the next index' });
        let start = 0, end = st.size - 1;
        const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || '');
        if (range) { start = +range[1]; if (range[2]) end = Math.min(+range[2], end); }
        if (start > end && st.size > 0) return send(416, { error: 'bad range' });
        res.writeHead(range ? 206 : 200, {
          'Content-Type': 'application/octet-stream', 'Content-Length': st.size ? end - start + 1 : 0, 'Accept-Ranges': 'bytes', ETag: entry[3],
          ...(range ? { 'Content-Range': `bytes ${start}-${end}/${st.size}` } : {}),
        });
        if (!st.size) return res.end();
        const rs = fs.createReadStream(full, { start, end, highWaterMark: 1 << 20 });
        res.on('close', () => rs.destroy());
        try {
          for await (const chunk of rs) {
            await limiter.take(chunk.length);
            if (!res.write(chunk)) await new Promise((r) => { res.once('drain', r); res.once('close', r); });
            if (res.destroyed) break;
          }
          return res.end();
        } catch { return res.destroy(); }
      }
      return send(404, { error: 'unknown' });
    } catch (e) { return send(500, { error: e.message }); }
  });
  server.keepAliveTimeout = 30000;
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(scfg.port, scfg.bind, resolve); });
  log(`source: sharing on http://${scfg.bind}:${scfg.port}  (destinations need the key in ${path.basename(CONFIG_FILE)})`);

  // index now and every reindexMinutes, only inside indexHours (reading every game is heavy for the game disks)
  for (;;) {
    if (inHours(scfg.indexHours)) await indexPass(cfg, opt, limiter, publish);
    else log(`source: index waits for indexHours ${scfg.indexHours}`);
    await sleep(Math.max(1, +scfg.reindexMinutes || 60) * 60000);
  }
}

async function indexPass(cfg, opt, limiter, publish = () => { }) {
  const scfg = cfg.source;
  const sel = { only: opt.only, include: scfg.include, exclude: scfg.exclude };
  const games = discoverGames(scfg).filter((g) => selected(g, sel));
  fs.mkdirSync(path.join(DATA, 'index'), { recursive: true });
  log(`index: ${games.length} games`);
  let ok = 0, waiting = 0, read = 0;
  // games indexed before that are no longer there (deleted, or excluded now): off the list
  if (!opt.only.length) {
    const ids = new Set(games.map((g) => g.id));
    for (const n of fs.readdirSync(path.join(DATA, 'index')).filter((x) => x.endsWith('.json'))) {
      const m = readJson(path.join(DATA, 'index', n), null);
      if (m && !ids.has(m.id)) { publish({ id: m.id, gone: true }); fs.rmSync(path.join(DATA, 'index', n), { force: true }); log(`index: ${m.id} is gone, off the list`); }
    }
  }
  for (const g of games) {
    if (!inHours(scfg.indexHours)) { log('index: outside indexHours, stopping for now'); break; }
    try {
      const { man, hashed } = await indexGame(g, limiter);
      read += hashed;
      publish(man);
      if (man.unstable) { waiting++; log(`index: WAIT ${g.id} - ${man.unstable}`); continue; }
      ok++;
      if (hashed) log(`index: ${g.id}  ${man.files.length} files, ${fmtBytes(man.size)}, read ${fmtBytes(hashed)}`);
    } catch (e) { waiting++; log(`index: FAIL ${g.id} - ${e.message}`); }
  }
  log(`index: done  ready ${ok}, waiting ${waiting}, read ${fmtBytes(read)}`);
  return { ok, waiting };
}

// ---------------------------------------------------------------- DESTINATION: talk to the source
function client(cfg, key) {
  const base = new URL(cfg.pull.url);
  const agent = new http.Agent({ keepAlive: true, maxSockets: Math.max(1, +cfg.pull.parallel || 4) });
  function request(pathQuery, headers = {}) {
    return new Promise((resolve, reject) => {
      const req = http.get({ host: base.hostname, port: base.port || 80, path: pathQuery, agent, headers: { 'X-OSYNC-Key': key, ...headers }, timeout: 60000 }, resolve);
      req.on('timeout', () => req.destroy(new Error('timeout')));
      req.on('error', reject);
    });
  }
  async function json(pathQuery) {
    const res = await request(pathQuery, { 'Accept-Encoding': 'gzip' });
    const chunks = [];
    for await (const c of res) chunks.push(c);
    let body = Buffer.concat(chunks);
    if (res.headers['content-encoding'] === 'gzip') body = zlib.gunzipSync(body);
    const data = JSON.parse(body.toString('utf8') || '{}');
    if (res.statusCode !== 200) throw new Error(`source answered ${res.statusCode}: ${data.error || ''}`);
    return data;
  }
  return { request, json, close: () => agent.destroy() };
}

// a relative path from the source must stay inside the game folder
function safeRel(rel) {
  return typeof rel === 'string' && rel.length > 0 && !rel.split('/').some((s) => !s || s === '.' || s === '..' || /[:<>|?*"]/.test(s) || /^[\\/]/.test(s));
}

function steamRunning() {
  if (process.env.GAMESYNC_TEST_STEAM_CLOSED) return false;      // tests only
  try { return /steam\.exe/i.test(execFileSync('tasklist', ['/FI', 'IMAGENAME eq steam.exe', '/NH'], { encoding: 'utf8', windowsHide: true })); } catch { return false; }
}

// where a source game goes on this PC: same drive letter by default, or pull.drives {"E":"H"} / {"E":"D:\\test"}
function destinationOf(game, drives) {
  const dRoot = drives[game.drive];
  if (!dRoot) return null;
  const root = game.kind === 'steam' ? path.join(dRoot, game.libRel, 'steamapps') : path.join(dRoot, game.cat, game.name);
  const content = game.kind === 'steam' ? path.join(root, 'common', game.steam.installdir) : root;
  const prefix = game.kind === 'steam' ? 'common/' + game.steam.installdir + '/' : '';
  return { driveRoot: dRoot, root, content, prefix };
}

function trashPathFor(file, driveRoot, stamp) {
  const rel = path.relative(driveRoot, file);
  return path.join(driveRoot, TRASH_NAME, 'GameSync', stamp, rel);
}

async function downloadFile(api, game, entry, target, limiter) {
  const [rel, size, mtime, sha] = entry;
  const part = target + PART;
  await fsp.mkdir(path.dirname(target), { recursive: true });
  let have = 0;
  try { have = (await fsp.stat(part)).size; } catch { }
  if (have > size) { await fsp.rm(part, { force: true }); have = 0; }
  const hash = have ? await hashFile(part, null) : crypto.createHash('sha256');
  if (have < size) {
    const q = `/api/file?id=${encodeURIComponent(game.id)}&path=${encodeURIComponent(rel)}`;
    const res = await api.request(q, have ? { Range: `bytes=${have}-` } : {});
    if (res.statusCode !== 200 && res.statusCode !== 206) { res.resume(); throw new Error(`source answered ${res.statusCode}`); }
    if (have && res.statusCode === 200) { res.destroy(); await fsp.rm(part, { force: true }); return downloadFile(api, game, entry, target, limiter); }
    const ws = fs.createWriteStream(part, { flags: have ? 'a' : 'w' });
    try {
      for await (const chunk of res) {
        await limiter.take(chunk.length);
        hash.update(chunk);
        if (!ws.write(chunk)) await new Promise((r) => ws.once('drain', r));
      }
    } finally { await new Promise((r) => ws.end(r)); }
  }
  const got = (await fsp.stat(part)).size;
  if (got !== size) throw new Error(`size ${got} of ${size} (connection dropped, will continue next time)`);
  const digest = hash.digest('hex');
  if (digest !== sha) { await fsp.rm(part, { force: true }); throw new Error('checksum differs, downloaded again next time'); }
  await fsp.utimes(part, mtime / 1000, mtime / 1000);   // seconds as a number keeps sub-millisecond time (a Date does not)
  return part;
}

// sync one game; returns { changed, ok, failed[] }
async function syncGame(api, game, dst, cfg, opt, limiter, stamp) {
  const man = await api.json(`/api/manifest?id=${encodeURIComponent(game.id)}`);
  for (const f of man.files) if (!safeRel(f[0])) throw new Error(`unsafe path from source: ${f[0]}`);
  const isNew = !fs.existsSync(dst.content);
  const work = isNew ? dst.content + STAGE : dst.content;   // new game: build it next to its place, then rename
  const inContent = (rel) => !dst.prefix || rel.startsWith(dst.prefix);
  const where = (rel) => inContent(rel) ? path.join(work, ...rel.slice(dst.prefix.length).split('/')) : path.join(dst.root, ...rel.split('/'));
  const outside = man.files.filter((f) => !inContent(f[0]));   // e.g. Steam appmanifest: written last

  // 1 decide per file: keep / re-time (same bytes, other time - e.g. a copy made by AutoSync) / download
  const todo = [];
  let adopted = 0, kept = 0, needBytes = 0;
  for (const f of man.files) {
    const target = where(f[0]);
    const st = await fsp.stat(target).catch(() => null);
    if (st && st.size === f[1] && sameMtime(st.mtimeMs, f[2]) && !opt.verify) { kept++; continue; }
    if (st && st.size === f[1]) {
      let local = '';
      try { local = (await hashFile(target, limiter)).digest('hex'); } catch { }   // locked by a running game: treat as changed
      if (local === f[3]) {
        try { if (!opt.dryRun) await fsp.utimes(target, f[2] / 1000, f[2] / 1000); adopted++; continue; } catch { }
      }
    }
    todo.push(f); needBytes += f[1];
  }
  // 2 files here that the source does not have any more (inside the game folder only)
  const wanted = new Set(man.files.filter((f) => inContent(f[0])).map((f) => where(f[0]).toLowerCase()));
  const extras = [];
  if (!isNew && cfg.pull.moveRemoved) {
    const w = await walk(work, null);
    for (const r of w.files) { const full = path.join(work, ...r.split('/')); if (!wanted.has(full.toLowerCase()) && !r.endsWith(PART)) extras.push(full); }
  }
  log(`pull: ${game.id} -> ${dst.content}${isNew ? ' (new)' : ''}: download ${todo.length} files ${fmtBytes(needBytes)}, same ${kept}, re-timed ${adopted}, removed at source ${extras.length}`);
  if (opt.dryRun) return { changed: false, ok: true, failed: [], plan: { todo: todo.length, needBytes, extras: extras.length } };

  // 3 download (parallel), finished files replace the old ones one by one
  const failed = [];
  const finals = [];
  let next = 0, doneBytes = 0, lastShow = Date.now();
  async function worker() {
    while (next < todo.length) {
      if (!inHours(cfg.pull.hours)) return;
      const f = todo[next++];
      const target = where(f[0]);
      let err = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const part = await downloadFile(api, game, f, target, limiter);
          if (outside.includes(f)) finals.push([part, target]);
          else await fsp.rename(part, target);
          err = null; break;
        } catch (e) { err = e; if (/409|checksum/.test(e.message)) break; await sleep(1000 * attempt); }
      }
      if (err) failed.push(`${f[0]}: ${err.code === 'EPERM' || err.code === 'EBUSY' ? 'in use (game open?)' : err.message}`);
      doneBytes += f[1];
      if (Date.now() - lastShow > 15000) { lastShow = Date.now(); log(`pull: ${game.id}  ${fmtBytes(doneBytes)} / ${fmtBytes(needBytes)}`); }
    }
  }
  await Promise.all(Array.from({ length: Math.max(1, +cfg.pull.parallel || 4) }, worker));
  if (next < todo.length) failed.push(`stopped: outside pull hours ${cfg.pull.hours} (continues next time)`);

  // 4 empty folders, links
  for (const d of man.dirs || []) {
    if (!safeRel(d) || !inContent(d + '/') || d + '/' === dst.prefix) continue;   // only folders inside the game
    await fsp.mkdir(where(d), { recursive: true }).catch(() => { });
  }
  for (const [rel, target] of man.links || []) {
    if (!safeRel(rel)) continue;
    const at = where(rel);
    if (fs.existsSync(at)) continue;
    try { await fsp.symlink(target, at); } catch (e) { failed.push(`${rel}: link not made (${e.code}) - make it once as admin: mklink "${at}" "${target}"`); }
  }
  if (failed.length) {
    log(`pull: ${game.id} NOT complete, ${failed.length} problems (first: ${failed[0]})`);
    return { changed: todo.length > failed.length, ok: false, failed };
  }
  // 5 complete: new game into place, removed files to the trash, appmanifest last (Steam sees a finished game)
  if (isNew) await fsp.rename(work, dst.content);
  for (const file of extras) {
    const to = trashPathFor(file, dst.driveRoot, stamp);
    try { await fsp.mkdir(path.dirname(to), { recursive: true }); await fsp.rename(file, to); } catch (e) { log(`pull: could not move ${file} to ${TRASH_NAME}: ${e.code}`); }
  }
  for (const [part, target] of finals) await fsp.rename(part, target);
  return { changed: todo.length + extras.length > 0 || isNew, ok: true, failed };
}

function acquireLock(name) {
  const file = path.join(DATA, name + '.lock');
  fs.mkdirSync(DATA, { recursive: true });
  try {
    const pid = +fs.readFileSync(file, 'utf8');
    if (pid && pid !== process.pid) { try { process.kill(pid, 0); return false; } catch { } }
  } catch { }
  fs.writeFileSync(file, String(process.pid));
  process.on('exit', () => { try { if (+fs.readFileSync(file, 'utf8') === process.pid) fs.rmSync(file); } catch { } });
  return true;
}

async function pullOnce(cfg, opt) {
  if (!cfg.pull.url) throw new Error(`set pull.url (e.g. http://100.64.0.10:18765) and key in ${CONFIG_FILE}`);
  if (!cfg.key) throw new Error(`set "key" in ${CONFIG_FILE} (copy it from the source)`);
  const drives = parseDrives(cfg.pull.drives || cfg.source.drives);
  const api = client(cfg, cfg.key);
  const limiter = new Limiter(cfg.pull.downloadLimitMBps);
  const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '');
  const autosync = cfg.pull.skipAutoSyncFolders ? readAutoSyncGames() : new Map();
  const stateDir = path.join(DATA, 'state');
  const synced = readJson(path.join(DATA, 'synced.json'), {});
  let changed = 0, okCount = 0, skipped = 0, failedGames = 0;
  try {
    const cat = await api.json('/api/catalog');
    const sel = { only: opt.only, include: cfg.pull.include, exclude: cfg.pull.exclude };
    const games = cat.games.filter((g) => selected(g, sel));
    log(`pull: source ${cat.name} has ${cat.games.length} games, ${games.length} selected`);
    let steamOpen = null;
    for (const g of games) {
      if (!inHours(cfg.pull.hours)) { log(`pull: outside pull hours ${cfg.pull.hours}, stopping`); break; }
      const dst = destinationOf(g, drives);
      if (!dst) { skipped++; continue; }
      if (autosync.has(dst.content.toLowerCase())) { skipped++; log(`pull: SKIP ${g.id} - AutoSync manages ${dst.content} on this PC`); continue; }
      const stFile = path.join(stateDir, safeName(g.id) + '.json');
      const st = readJson(stFile, null);
      if (st && st.ok && st.version === g.version && fs.existsSync(dst.content) && !opt.verify) { okCount++; continue; }
      if (g.kind === 'steam') {
        if (steamOpen === null) steamOpen = steamRunning();
        if (steamOpen && !opt.dryRun) { skipped++; log(`pull: SKIP ${g.id} - close Steam on this PC to sync Steam games`); continue; }
        if (!fs.existsSync(path.join(dst.driveRoot, g.libRel))) log(`pull: note ${g.id} - ${path.join(dst.driveRoot, g.libRel)} is new: add it as a library in Steam`);
      }
      try {
        const r = await syncGame(api, g, dst, cfg, opt, limiter, stamp);
        if (opt.dryRun) continue;
        if (r.changed) changed++;
        writeJsonAtomic(stFile, { id: g.id, version: r.ok ? g.version : (st && st.version) || '', ok: r.ok, at: new Date().toISOString(), failed: r.failed.slice(0, 50) });
        if (r.ok) {
          okCount++;
          synced[g.id] = { id: g.id, title: g.title, cat: g.cat, kind: g.kind, root: dst.content,
            start: g.start ? path.join(dst.content, g.start) : '', poster: g.poster ? path.join(dst.content, g.poster) : '' };
        } else failedGames++;
      } catch (e) { failedGames++; log(`pull: FAIL ${g.id} - ${e.message}`); }
    }
  } finally { api.close(); }
  if (!opt.dryRun) writeJsonAtomic(path.join(DATA, 'synced.json'), synced);
  log(`pull: done  up to date ${okCount}, changed ${changed}, problems ${failedGames}, skipped ${skipped}`);
  if (changed && !opt.dryRun && cfg.pull.afterSync === 'update-all') {
    const ps1 = path.join(OSYNC, '_system', 'Update-All.ps1');
    if (fs.existsSync(ps1)) {
      log('pull: games changed -> MASTER-Update-All (menu list + client data)');
      await new Promise((r) => spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1], { stdio: 'inherit', windowsHide: true }).on('exit', r));
    }
  }
  return { changed, failedGames };
}

// ---------------------------------------------------------------- status
function status(cfg) {
  const idx = path.join(DATA, 'index');
  const stDir = path.join(DATA, 'state');
  if (fs.existsSync(idx)) {
    const all = fs.readdirSync(idx).filter((n) => n.endsWith('.json')).map((n) => readJson(path.join(idx, n), null)).filter(Boolean);
    const ready = all.filter((m) => !m.unstable);
    console.log(`SOURCE index: ${ready.length} games ready, ${all.length - ready.length} waiting, ${fmtBytes(ready.reduce((a, m) => a + m.size, 0))}`);
    for (const m of all.sort((a, b) => a.id.localeCompare(b.id))) console.log(`  ${m.unstable ? 'WAIT ' : 'ready'}  ${m.id.padEnd(48)} ${fmtBytes(m.size).padStart(9)}  ${m.unstable || ''}`);
  }
  if (fs.existsSync(stDir)) {
    const all = fs.readdirSync(stDir).filter((n) => n.endsWith('.json')).map((n) => readJson(path.join(stDir, n), null)).filter(Boolean);
    console.log(`DESTINATION: ${all.filter((s) => s.ok).length} games up to date, ${all.filter((s) => !s.ok).length} not complete`);
    for (const s of all.sort((a, b) => a.id.localeCompare(b.id))) console.log(`  ${s.ok ? 'ok   ' : 'NOT  '}  ${s.id.padEnd(48)} ${s.at}  ${s.ok ? '' : (s.failed || [])[0] || ''}`);
  }
  if (!fs.existsSync(idx) && !fs.existsSync(stDir)) console.log('nothing yet - run "serve" (source) or "pull" (destination)');
}

// ---------------------------------------------------------------- main
async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0] || 'help';
  const opt = { only: [], dryRun: args.includes('--dry-run'), verify: args.includes('--verify'), watch: args.includes('--watch') };
  for (let i = 0; i < args.length; i++) if (args[i] === '--only' && args[i + 1]) opt.only.push(args[++i]);
  const { cfg, raw } = loadConfig();
  if (cmd === 'serve') {
    if (!acquireLock('source')) { log('source already running'); return; }
    return serve(cfg, opt, raw);
  }
  if (cmd === 'index') { if (!acquireLock('source')) { log('source already running (it indexes by itself)'); return; } await indexPass(cfg, opt, new Limiter(cfg.source.readLimitMBps)); return; }
  if (cmd === 'pull' || cmd === 'list') {
    if (cmd === 'list') opt.dryRun = true;
    if (!acquireLock('pull')) { log('pull already running'); return; }
    if (!opt.watch) { const r = await pullOnce(cfg, opt); process.exitCode = r.failedGames ? 1 : 0; return; }
    for (;;) {
      if (inHours(cfg.pull.hours)) { try { await pullOnce(cfg, opt); } catch (e) { log(`pull: ${e.message}`); } }
      await sleep(Math.max(1, +cfg.pull.everyMinutes || 30) * 60000);
    }
  }
  if (cmd === 'status') return status(cfg);
  console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 12).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
}

if (require.main === module) main().catch((e) => { log(`error: ${e.stack || e.message}`); process.exitCode = 1; });
module.exports = { parseDrives, inHours, safeRel, matches, discoverGames, indexGame, destinationOf };
