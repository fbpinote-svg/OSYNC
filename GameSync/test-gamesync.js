// End-to-end test of GameSync on one PC: a fake source drive and fake destination drives in %TEMP%.
// Run: node GameSync\test-gamesync.js   (needs nothing else; never touches the real game drives)
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const http = require('node:http');
const { spawn, spawnSync } = require('node:child_process');

const GS = process.argv[2] || path.join(__dirname, 'gamesync.js');
const T = path.join(require('node:os').tmpdir(), 'osync-gamesync-test');
fs.rmSync(T, { recursive: true, force: true });
const SRC = path.join(T, 'src'), PORT = 18765, KEY = 'test-key-123';
let failures = 0;
const ok = (cond, msg) => { console.log(`${cond ? 'PASS' : 'FAIL'}  ${msg}`); if (!cond) failures++; };
const sha = (f) => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const write = (f, data) => { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, data); };

// ---- fake source: one folder game, one Steam game, one game that is "being written"
const game = path.join(SRC, 'Online', 'Test Game');
write(path.join(game, 'TestGame.exe'), crypto.randomBytes(300 * 1024));
write(path.join(game, 'data', 'big.pak'), crypto.randomBytes(25 * 1024 * 1024));
write(path.join(game, 'data', 'sub', 'a.txt'), 'hello');
write(path.join(game, 'remove-me.txt'), 'old file');
write(path.join(game, 'zPoster.jpg'), 'jpg');
fs.mkdirSync(path.join(game, 'logs-empty'), { recursive: true });
const lib = path.join(SRC, 'SteamLibrary', 'steamapps');
write(path.join(lib, 'appmanifest_999.acf'), '"AppState"\n{\n\t"appid"\t\t"999"\n\t"name"\t\t"Fake Steam Game"\n\t"StateFlags"\t\t"4"\n\t"installdir"\t\t"FakeSteam"\n}\n');
write(path.join(lib, 'common', 'FakeSteam', 'fake.exe'), crypto.randomBytes(200 * 1024));
write(path.join(lib, 'common', 'FakeSteam', 'bin', 'x.dll'), crypto.randomBytes(50 * 1024));
write(path.join(lib, 'common', 'OtherNotInstalled', 'junk.bin'), 'not in any manifest');
write(path.join(lib, 'appmanifest_998.acf'), '"AppState"\n{\n\t"appid"\t\t"998"\n\t"name"\t\t"Updating Game"\n\t"StateFlags"\t\t"1026"\n\t"installdir"\t\t"Upd"\n}\n');
write(path.join(lib, 'common', 'Upd', 'u.bin'), 'half');

function cfgFile(name, obj) { const f = path.join(T, name + '.json'); write(f, JSON.stringify(obj)); return f; }
const srcCfg = cfgFile('source', { key: KEY, source: { drives: { T: SRC }, categories: ['Online'], steam: true, port: PORT, bind: '127.0.0.1' } });
const dstCfg = (name, root, extra = {}) => cfgFile(name, { key: KEY, pull: { url: `http://127.0.0.1:${PORT}`, drives: { T: root }, hours: '', parallel: 3, afterSync: 'none', ...extra } });
const env = (cfg, data) => ({ ...process.env, GAMESYNC_CONFIG: cfg, GAMESYNC_DATA: data, GAMESYNC_TEST_STEAM_CLOSED: '1' });

let server = null;
function startServer() {
  return new Promise((resolve, reject) => {
    server = spawn(process.execPath, [GS, 'serve'], { env: env(srcCfg, path.join(T, 'src-data')) });
    let out = '';
    const t = setTimeout(() => reject(new Error('server did not finish indexing:\n' + out)), 60000);
    server.stdout.on('data', (d) => { out += d; if (/index: done/.test(out)) { clearTimeout(t); resolve(out); } });
    server.stderr.on('data', (d) => { out += d; });
  });
}
const stopServer = () => new Promise((r) => { server.once('exit', r); server.kill(); });
function pull(cfg, data, args = []) {
  const r = spawnSync(process.execPath, [GS, 'pull', ...args], { env: env(cfg, data), encoding: 'utf8' });
  return r.stdout + r.stderr;
}
function get(p, key = KEY) {
  return new Promise((resolve) => http.get({ host: '127.0.0.1', port: PORT, path: p, headers: { 'X-OSYNC-Key': key } }, (res) => { res.resume(); resolve(res.statusCode); }));
}
function sameTree(a, b, skip = []) {
  const list = (root) => { const out = []; const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const f = path.join(d, e.name); if (e.isDirectory()) walk(f); else out.push(path.relative(root, f)); } }; walk(root); return out.sort(); };
  const la = list(a).filter((f) => !skip.includes(f)), lb = list(b);
  if (JSON.stringify(la) !== JSON.stringify(lb)) return `file lists differ: ${la.length} vs ${lb.length}`;
  for (const f of la) {
    if (sha(path.join(a, f)) !== sha(path.join(b, f))) return `content differs: ${f}`;
    if (Math.abs(fs.statSync(path.join(a, f)).mtimeMs - fs.statSync(path.join(b, f)).mtimeMs) > 2) return `time differs: ${f}`;
  }
  return '';
}

(async () => {
  const idx = await startServer();
  ok(/WAIT T\/steam\/998/.test(idx), 'Steam game that is updating is held back');
  ok(/T\/Online\/Test Game/.test(idx) && /T\/steam\/999/.test(idx), 'folder game and Steam game indexed');
  ok((await get('/api/catalog', 'wrong')) === 401, 'wrong key -> 401');
  ok((await get('/api/file?id=' + encodeURIComponent('T/Online/Test Game') + '&path=' + encodeURIComponent('../../source.json'))) === 404, 'path outside the index -> 404');
  ok((await get('/api/manifest?id=T%2Fsteam%2F998')) === 404, 'updating game not offered');

  // 1 new games
  const D1 = path.join(T, 'dst1');
  fs.mkdirSync(path.join(D1, 'SteamLibrary', 'steamapps', 'common'), { recursive: true });
  const c1 = dstCfg('dst1', D1), d1 = path.join(T, 'dst1-data');
  let out = pull(c1, d1);
  ok(/done\s+up to date 2, changed 2, problems 0/.test(out), 'first pull: 2 games copied');
  ok(sameTree(game, path.join(D1, 'Online', 'Test Game')) === '', 'folder game identical (bytes + times) ' + sameTree(game, path.join(D1, 'Online', 'Test Game')));
  ok(fs.existsSync(path.join(D1, 'Online', 'Test Game', 'logs-empty')), 'empty folder kept');
  ok(!fs.existsSync(path.join(D1, 'Online', 'Test Game.gsync-new')), 'no staging folder left');
  ok(sameTree(path.join(lib, 'common', 'FakeSteam'), path.join(D1, 'SteamLibrary', 'steamapps', 'common', 'FakeSteam')) === '', 'Steam game files identical');
  ok(fs.existsSync(path.join(D1, 'SteamLibrary', 'steamapps', 'appmanifest_999.acf')), 'Steam appmanifest written');
  ok(!fs.existsSync(path.join(D1, 'SteamLibrary', 'steamapps', 'common', 'OtherNotInstalled')), 'other Steam folders not copied');
  const synced = JSON.parse(fs.readFileSync(path.join(d1, 'synced.json'), 'utf8'));
  ok(synced['T/Online/Test Game'] && synced['T/Online/Test Game'].poster.endsWith('zPoster.jpg'), 'synced.json lists the game for the menu');

  // 2 nothing changed
  out = pull(c1, d1);
  ok(/up to date 2, changed 0/.test(out) && !/download \d+ files/.test(out), 'second pull: nothing to do');

  // 3 source changes: edit, add, remove -> re-index (restart) -> only those move
  await stopServer();
  write(path.join(game, 'data', 'sub', 'a.txt'), 'hello v2');
  write(path.join(game, 'new-file.dat'), crypto.randomBytes(1000));
  fs.rmSync(path.join(game, 'remove-me.txt'));
  await startServer();
  out = pull(c1, d1);
  ok(/download 2 files/.test(out), 'only the 2 changed/new files downloaded');
  ok(sameTree(game, path.join(D1, 'Online', 'Test Game')) === '', 'folder game identical after update');
  const trash = path.join(D1, '_ลบได้', 'GameSync');
  const moved = fs.existsSync(trash) && fs.readdirSync(trash).some((s) => fs.existsSync(path.join(trash, s, 'Online', 'Test Game', 'remove-me.txt')));
  ok(moved, 'file removed at the source was moved to _ลบได้ (not deleted)');

  // 4 existing copy with other file times (like a copy made by AutoSync) -> no download
  const D2 = path.join(T, 'dst2');
  fs.cpSync(game, path.join(D2, 'Online', 'Test Game'), { recursive: true, preserveTimestamps: false });
  const later = new Date(Date.now() - 86400000);
  for (const f of ['TestGame.exe', 'data/big.pak']) fs.utimesSync(path.join(D2, 'Online', 'Test Game', f), later, later);
  out = pull(dstCfg('dst2', D2, { include: ['T/Online/*'] }), path.join(T, 'dst2-data'));
  ok(/download 0 files/.test(out) && /re-timed [1-9]/.test(out), 'existing identical files used, not downloaded');
  ok(sameTree(game, path.join(D2, 'Online', 'Test Game')) === '', 'times fixed to match the source');

  // 5 resume: half-downloaded big file in the staging folder
  const D3 = path.join(T, 'dst3');
  const stage = path.join(D3, 'Online', 'Test Game.gsync-new');
  const big = fs.readFileSync(path.join(game, 'data', 'big.pak'));
  write(path.join(stage, 'data', 'big.pak.gsync-part'), big.subarray(0, 10 * 1024 * 1024));
  out = pull(dstCfg('dst3', D3, { include: ['T/Online/*'] }), path.join(T, 'dst3-data'));
  ok(/changed 1, problems 0/.test(out) && sameTree(game, path.join(D3, 'Online', 'Test Game')) === '', 'half-downloaded file continued and verified');

  // 6 corrupt partial file -> checksum catches it, next pull fixes it
  const D4 = path.join(T, 'dst4');
  const stage4 = path.join(D4, 'Online', 'Test Game.gsync-new');
  write(path.join(stage4, 'data', 'big.pak.gsync-part'), crypto.randomBytes(10 * 1024 * 1024));
  const c4 = dstCfg('dst4', D4, { include: ['T/Online/*'] }), d4 = path.join(T, 'dst4-data');
  out = pull(c4, d4);
  ok(/NOT complete/.test(out) && !fs.existsSync(path.join(D4, 'Online', 'Test Game')), 'bad bytes caught: game not put in place');
  out = pull(c4, d4);
  ok(/changed 1, problems 0/.test(out) && sameTree(game, path.join(D4, 'Online', 'Test Game')) === '', 'next pull repairs it');

  // 7 file in use on the destination -> reported, game marked not complete, fixed next time
  const lockFile = path.join(D1, 'Online', 'Test Game', 'data', 'sub', 'a.txt');
  await stopServer();
  write(path.join(game, 'data', 'sub', 'a.txt'), 'hello v3');
  await startServer();
  const holder = spawn('powershell.exe', ['-NoProfile', '-Command', `$f=[IO.File]::Open('${lockFile}','Open','Read','None'); Start-Sleep 12; $f.Close()`]);
  await new Promise((r) => setTimeout(r, 2500));
  out = pull(c1, d1);
  ok(/in use/.test(out) && /problems 1/.test(out), 'file in use reported, game marked not complete');
  await new Promise((r) => holder.once('exit', r));
  out = pull(c1, d1);
  ok(/changed 1, problems 0/.test(out) && fs.readFileSync(lockFile, 'utf8') === 'hello v3', 'next pull finishes it');

  // 8 dry run changes nothing
  const D5 = path.join(T, 'dst5');
  out = spawnSync(process.execPath, [GS, 'list'], { env: env(dstCfg('dst5', D5), path.join(T, 'dst5-data')), encoding: 'utf8' }).stdout;
  ok(/download \d+ files/.test(out) && !fs.existsSync(path.join(D5, 'Online')), 'list (dry run) writes nothing');

  await stopServer();
  const { safeRel, parseDrives, inHours } = require(GS);
  ok(!safeRel('../x') && !safeRel('a/../b') && !safeRel('C:/x') && !safeRel('/x') && !safeRel('') && safeRel('data/ok file.pak'), 'unsafe paths from a source are refused');
  ok(JSON.stringify(parseDrives('EF')) === JSON.stringify({ E: 'E:\\', F: 'F:\\' }) && parseDrives({ E: 'H' }).E === 'H:\\', 'drive settings');
  const at = (h, m) => new Date(2026, 0, 1, h, m);
  ok(inHours('02:00-08:00', at(3, 0)) && !inHours('02:00-08:00', at(9, 0)) && inHours('22:00-06:00', at(23, 0)) && inHours('22:00-06:00', at(5, 0)) && !inHours('22:00-06:00', at(12, 0)), 'pull hours (also across midnight)');
  fs.rmSync(T, { recursive: true, force: true });
  console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
  process.exit(failures ? 1 : 0);
})().catch(async (e) => { console.error(e); if (server) server.kill(); process.exit(1); });
