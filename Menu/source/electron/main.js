const { app, BrowserWindow, screen, ipcMain, Tray, Menu, shell, nativeImage } = require('electron');
const path = require('path');
const http = require('http');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

// ── Windows App Identity ──
if (process.platform === 'win32') {
  app.setAppUserModelId(loadConfig().brandName);   // the shop name (config.json), shown by Windows for this app
}

// tools\Build-GameList: "0JAYSHOP.exe --imagetool <jobs.json>" renders posters and exits (no window, no single-instance lock)
const imagetoolArg = process.argv.indexOf('--imagetool');
if (imagetoolArg > 0) {
  require(path.join(gcafeRoot(), 'tools', '_system', 'imagetool', 'render.js'))(process.argv[imagetoolArg + 1]);
  return;
}

// one copy per PC: a second start just brings the window that is showing (HUD or game menu) back
if (!app.requestSingleInstanceLock()) {
  app.quit();
  return;
}

// one window at a time (13 Nov): the HUD and the game menu never show together, so the taskbar has one button.
// opening the game menu hides the HUD; closing it (✕, starting a game, lock screen) brings the HUD back where it was
let mainWindow = null;
let dialogWindow = null;
let pendingOrders = [];   // purchase toasts made while the game menu was open: the HUD shows them when it comes back
let server = null;
let serverPort = null;
let tray = null;
let appIcon = null;
app.isQuitting = false;

// ── GCafe folder layout ──
//   <root>\app\0JAYSHOP.exe        packaged client (what PCs run)
//   <root>\config.json             brand / station / API settings
//   <root>\data\games.json         offline game catalog (tools\Build-GameList)
//   <root>\source\electron\        this file during development
function gcafeRoot() {
  return app.isPackaged
    ? path.resolve(path.dirname(process.execPath), '..')
    : path.resolve(__dirname, '..', '..');
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  } catch {
    return fallback;
  }
}

// a local picture (absolute, or relative to the GCafe folder) is served through /poster/
// ?v=<file time>: a replaced picture (new logo, banner) gets a new address, so no PC keeps showing an old cached copy
function localImageUrl(p) {
  if (!p || /^(https?:|data:|\/)/i.test(p)) return p || '';
  const abs = path.resolve(gcafeRoot(), p);
  let v = '';
  try { v = '?v=' + Math.floor(fs.statSync(abs).mtimeMs).toString(36); } catch { /* missing file: plain address */ }
  return '/poster/' + encodeURIComponent(abs) + v;
}

// build time of this menu (out\index.html), shown small on the lock screen so each PC's build can be checked
function buildStamp() {
  if (buildStamp.v !== undefined) return buildStamp.v;
  let v = '';
  try {
    const d = fs.statSync(path.join(__dirname, '..', 'out', 'index.html')).mtime;
    const p2 = (n) => String(n).padStart(2, '0');
    v = `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())} ${p2(d.getHours())}:${p2(d.getMinutes())}`;
  } catch { /* no build folder (dev) */ }
  buildStamp.v = v;
  return v;
}

// config.json "ui" (all optional): font, hudSize/menuSize/lockSize (% zoom 80-130), hudBanner ('' = card without
// picture, 'off' = hidden, or a picture path), hudBannerTag, hudBannerText, featured (game ids), categoryNames ({cat: name})
// (the font list lives inside the function: loadConfig() already runs at the top of this file, before module-level consts exist)
function loadUi(cfg) {
  const UI_FONTS = ['Kanit', 'Prompt', 'Chakra Petch', 'Leelawadee UI', 'Tahoma'];
  const u = (cfg && cfg.ui && typeof cfg.ui === 'object') ? cfg.ui : {};
  const pct = (v) => { const n = Math.round(Number(v)); return n >= 80 && n <= 130 ? n : 100; };
  const text = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
  const banner = text(u.hudBanner, 400);
  const names = {};
  if (u.categoryNames && typeof u.categoryNames === 'object') {
    for (const [k, v] of Object.entries(u.categoryNames)) if (typeof v === 'string' && v.trim()) names[String(k).slice(0, 40)] = v.trim().slice(0, 40);
  }
  return {
    font: UI_FONTS.includes(u.font) ? u.font : 'Kanit',
    hudSize: pct(u.hudSize), menuSize: pct(u.menuSize), lockSize: pct(u.lockSize),
    hudBanner: banner.toLowerCase() === 'off' ? 'off' : localImageUrl(banner),
    hudBannerTag: text(u.hudBannerTag, 24),
    hudBannerText: text(u.hudBannerText, 140),
    featured: Array.isArray(u.featured) ? u.featured.filter((x) => typeof x === 'string').slice(0, 6) : [],
    categoryNames: names,
    // 17 Nov (owner): these games ask "graphics low / medium / high" before they start (GTA V Legacy + FiveM)
    graphicsPicker: Array.isArray(u.graphicsPicker) ? u.graphicsPicker.filter((x) => typeof x === 'string').slice(0, 10) : ['steam-271590', 'fivem'],
    // 17 Nov (owner): menuOnly = the game menu is the whole program (no HUD / time left / shop tabs); sidePanel false = no right column
    menuOnly: u.menuOnly === true,
    sidePanel: u.sidePanel !== false,
    // 19 Nov (owner): "ขอเกม Steam" button - true = the master from Settings\settings.txt, or a URL (tests); else no button
    steamRequest: u.steamRequest === true || (typeof u.steamRequest === 'string' && /^https?:\/\/[^\s/]+\/?$/i.test(u.steamRequest)) || !!process.env.GCAFE_STEAMREQ_URL,
  };
}

function loadConfig() {
  const cfg = readJson(path.join(gcafeRoot(), 'config.json'), {});
  const defaultLogo = path.join(gcafeRoot(), 'data', 'brand', 'logo.png');
  // small-size version of the logo (no text) for the 30 px spots: config.json brandMark, else data\brand\logo-mark.png
  const defaultMark = path.join(gcafeRoot(), 'data', 'brand', 'logo-mark.png');
  return {
    brandName: cfg.brandName || '0JAYSHOP',
    brandBadge: cfg.brandBadge || 'VIP',
    brandLogo: localImageUrl(cfg.brandLogo || (fs.existsSync(defaultLogo) ? defaultLogo : '')),
    brandMark: localImageUrl(cfg.brandMark || (fs.existsSync(defaultMark) ? defaultMark : '')),
    icons: launcherIcons(),
    apiUrl: cfg.apiUrl || '',                 // empty = offline (game menu works from games.json)
    machineId: cfg.machineId || os.hostname(),
    ui: loadUi(cfg),
    build: buildStamp(),
  };
}

// program icons the game-list script already pulled out of each launcher / game (data\posters\_auto\icons\<id>.png):
// the game menu shows them on the category buttons and as the small badge on each card (no logo files of our own)
function iconFile(id) {
  return path.join(gcafeRoot(), 'data', 'posters', '_auto', 'icons', `${String(id).replace(/[\\/:*?"<>|]/g, '')}.png`);
}
function launcherIcons() {   // platform / category name → icon url (only the ones that exist on this PC)
  const map = {
    Steam: 'launcher-steam', Riot: 'launcher-riot', EA: 'launcher-ea', 'EA app': 'launcher-ea', Epic: 'launcher-epic',
    Garena: 'launcher-garena', Rockstar: 'launcher-rockstar', Ubisoft: 'launcher-ubisoft', HoYoPlay: 'launcher-hoyoplay',
    'Battle.net': 'launcher-battlenet', Discord: 'tool-discordptb', Roblox: 'launcher-roblox', Amazon: 'launcher-amazon',
  };
  const out = {};
  for (const [k, id] of Object.entries(map)) { const f = iconFile(id); if (fs.existsSync(f)) out[k] = localImageUrl(f); }
  return out;
}
function withIcons(list) {   // + "icon" on games that have their own extracted icon
  return list.map((g) => {
    if (!g || g.icon || !g.id) return g;
    const f = iconFile(g.id);
    return fs.existsSync(f) ? { ...g, icon: localImageUrl(f) } : g;
  });
}

// last list read OK: on a diskless client, games.json rewritten on the master after this PC booted reads as
// garbage until a reboot, so keep showing the list read at start instead of an empty menu
let lastGoodGames = null;
function loadGames() {
  const list = readJson(path.join(gcafeRoot(), 'data', 'games.json'), null);
  if (Array.isArray(list) && list.length) { lastGoodGames = list; return list; }
  return lastGoodGames || (Array.isArray(list) ? list : []);
}

// ── Shop system bridge (Cooper Agent 1.20+) ──
// The agent (runs elevated) writes, in %ProgramData%\CooperAgent:
//   state.json  - live session / clock offset / messages (read every second)
//   gcafe.json  - shop web address + a menu token for THIS PC (rotated when a rental starts/ends)
// We write gcafe\alive.json every 2 s so the agent hides its own idle-lock / time panel while we show ours.
// The token never reaches the pages: they call window.electronAPI.agent.api(...) and main.js does the HTTPS call.
// No gcafe.json (old agent / no agent) = offline mode exactly as before (no lock screen from us).
const AGENT_DIR = path.join(process.env.ProgramData || 'C:\\ProgramData', 'CooperAgent');
const AGENT_STATE = path.join(AGENT_DIR, 'state.json');
const AGENT_GCAFE = path.join(AGENT_DIR, 'gcafe.json');
const AGENT_ALIVE_DIR = path.join(AGENT_DIR, 'gcafe');
const AGENT_ALIVE = path.join(AGENT_ALIVE_DIR, 'alive.json');
// phase 1: lock screen + logout · phase 2: top-up / extend / ID shop / code inventory / QR login / time tickets · cash coupons (12 Nov)
// phase 3 (12 Nov): chat with the shop · account tab · game-launch stats
const API_PATHS = new Set(['state', 'login', 'start', 'logout', 'panel', 'extend', 'topup', 'shop', 'buy', 'orders', 'steam-guard', 'qr-login', 'ticket', 'coupon', 'chat', 'account', 'launch']);

let agentView = { integrated: false, session: null, serverOffsetMs: 0, online: false, shop: '', machineName: '', site: '', ending: null, updatedAt: 0 };
let agentCfg = null;      // { server, token } - main process only
let lockWindows = [];
let lockedNow = false;

function readAgent() {
  const st = readJson(AGENT_STATE, null);
  const g = readJson(AGENT_GCAFE, null);
  const fresh = !!(st && st.updatedAt && Math.abs(Date.now() - Number(st.updatedAt)) < 60000);
  const ok = !!(g && typeof g.token === 'string' && g.token.startsWith('gt_') && /^https?:\/\//i.test(String(g.server || '')));
  agentCfg = ok ? { server: String(g.server).replace(/\/+$/, ''), token: g.token } : null;
  const s = st && st.session;
  agentView = {
    integrated: ok && fresh,
    session: s ? {
      id: s.id, mode: s.mode, source: s.source || 'web', user: s.user || '',
      startedAt: Number(s.startedAt) || 0, endsAt: s.endsAt == null ? null : Number(s.endsAt),
      balanceText: s.balanceText || '', rateText: s.rateText || '',
    } : null,
    serverOffsetMs: Number(st && st.serverOffsetMs) || 0,
    online: !!(st && st.online),
    shop: (st && st.shop) || (g && g.shop) || '',
    machineName: (st && st.machineName) || (g && g.machineName) || os.hostname(),
    site: ok ? agentCfg.server : '',
    ending: st && st.ending && Number(st.ending.until) > Date.now() ? { text: String(st.ending.text || ''), until: Number(st.ending.until) } : null,
    updatedAt: Date.now(),
  };
  return agentView;
}

function broadcast() {
  for (const w of [mainWindow, dialogWindow, ...lockWindows]) {
    if (w && !w.isDestroyed()) w.webContents.send('agent:update', agentView);
  }
}

function writeAlive() {
  try {
    if (!fs.existsSync(AGENT_ALIVE_DIR)) return;   // the agent creates it (with write access for normal users)
    fs.writeFileSync(AGENT_ALIVE, JSON.stringify({ at: Date.now(), pid: process.pid, managed: agentView.integrated, showing: lockedNow ? 'lock' : 'hud', version: app.getVersion() }));
  } catch { /* the agent shows its own lock screen if this stops */ }
}

// one full-screen lock window per display; the primary one shows the login page
function showLock() {
  if (lockWindows.length) return;
  const displays = screen.getAllDisplays();
  const primary = screen.getPrimaryDisplay();
  for (const d of displays) {
    const isPrimary = d.id === primary.id;
    const w = new BrowserWindow({
      title: loadConfig().brandName,
      icon: getAppIcon(),
      x: d.bounds.x, y: d.bounds.y, width: d.bounds.width, height: d.bounds.height,
      frame: false, resizable: false, movable: false, minimizable: false, maximizable: false,
      closable: false, skipTaskbar: true, fullscreenable: true, kiosk: true, show: false, alwaysOnTop: true, backgroundColor: '#070a18',
      webPreferences: { preload: path.join(__dirname, 'preload.js'), nodeIntegration: false, contextIsolation: true },
    });
    w.$display = d.id;
    w.$primary = isPrimary;
    // kiosk/full screen only takes effect reliably once the window is visible; the taskbar goes behind a full-screen window that is in front
    w.once('ready-to-show', () => { if (!w.isDestroyed()) { w.show(); keepLockOnTop(w, true); } });
    w.setAlwaysOnTop(true, 'screen-saver');
    w.on('close', (e) => { if (!app.isQuitting && lockedNow) e.preventDefault(); });
    w.on('page-title-updated', (e) => e.preventDefault());
    w.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    w.webContents.on('will-navigate', (e, url) => { if (!url.startsWith(`http://127.0.0.1:${serverPort}`)) e.preventDefault(); });
    w.loadURL(isPrimary ? `http://127.0.0.1:${serverPort}/lock/` : 'data:text/html,<body style="background:%23070a18;margin:0"></body>');
    lockWindows.push(w);
  }
  if (mainWindow) mainWindow.hide();
  // the game menu is closed (not just hidden): the next customer starts from the HUD, without the last one's search / tab
  if (dialogWindow && !dialogWindow.isDestroyed()) dialogWindow.destroy();
}

// keep a lock window covering its whole display, above the taskbar (both are top-most: the last one raised wins → raise ours again)
let lockFocusAt = 0;
function keepLockOnTop(w, force) {
  if (!w || w.isDestroyed() || !w.isVisible()) return;
  try {
    const d = screen.getAllDisplays().find((x) => x.id === w.$display) || screen.getPrimaryDisplay();
    if (!w.isKiosk()) w.setKiosk(true);
    const b = w.getBounds();
    if (b.x !== d.bounds.x || b.y !== d.bounds.y || b.width !== d.bounds.width || b.height !== d.bounds.height) w.setBounds(d.bounds);
    if (force || !w.isAlwaysOnTop()) w.setAlwaysOnTop(true, 'screen-saver');
    w.moveTop();
    if (w.$primary && !w.isFocused() && (force || Date.now() - lockFocusAt > 3000)) { lockFocusAt = Date.now(); w.focus(); }
  } catch { /* display changed - next tick */ }
}

function hideLock() {
  const list = lockWindows;
  lockWindows = [];
  for (const w of list) { try { if (!w.isDestroyed()) w.destroy(); } catch { /* gone */ } }
}

// every second: follow the agent's state (rental started/ended) and keep the lock screen in sync
function agentTick() {
  readAgent();
  const wantLock = agentView.integrated && !agentView.session && !agentView.ending;
  if (wantLock !== lockedNow) {
    lockedNow = wantLock;
    if (wantLock) showLock();
    else { hideLock(); showMainWindow(); }
  } else if (wantLock) {
    for (const w of lockWindows) keepLockOnTop(w, false);
  }
  broadcast();
}

async function apiCall(method, p, body) {
  if (!API_PATHS.has(p)) return { ok: false, status: 0, data: { error: 'not allowed' } };
  readAgent();
  if (!agentCfg) return { ok: false, status: 0, data: { error: 'ระบบร้านยังไม่พร้อม (ไม่พบเอเจนต์รุ่น 1.20+)' } };
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 10000);
  try {
    const res = await fetch(`${agentCfg.server}/api/gcafe/${p}`, {
      method: method === 'POST' ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${agentCfg.token}`, 'Content-Type': 'application/json' },
      body: method === 'POST' ? JSON.stringify(body || {}) : undefined,
      signal: ctrl.signal,
    });
    let data = null;
    try { data = await res.json(); } catch { data = null; }
    return { ok: res.ok && !!(data && data.ok !== false), status: res.status, data: data || {} };
  } catch (e) {
    return { ok: false, status: 0, data: { error: e.name === 'AbortError' ? 'เชื่อมต่อร้านไม่ได้ (หมดเวลา)' : 'เชื่อมต่อร้านไม่ได้' } };
  } finally {
    clearTimeout(t);
  }
}

function launchGame(game) {
  const cmd = (game && (game.cmd || game.title)) || '';
  if (!cmd) return { ok: false, error: 'no command' };
  try {
    if (/^[a-z0-9+.-]+:\/\//i.test(cmd)) {
      shell.openExternal(cmd);
    } else {
      const opts = { shell: true, detached: true, stdio: 'ignore', windowsHide: true };
      if (game.cwd && fs.existsSync(game.cwd)) opts.cwd = game.cwd;
      spawn(cmd, opts).unref();
    }
    // phase 3 (12 Nov): game stats for the shop (admin → สถิติเกม) — only the game's display name, fire-and-forget, never blocks the launch
    const title = String((game && (game.title || game.name)) || '').trim().slice(0, 80);
    if (title) apiCall('POST', 'launch', { title }).catch(() => {});
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// ── 16 Nov: right-click on a game card → "เปิดตำแหน่งไฟล์" / "คัดลอกที่อยู่" (everyone, owner's choice) ──
// The location is worked out here from data\games.json by game id only — a page can never ask to open any other path.
//   exe games = the exe (Explorer opens its folder with it selected) · Steam -applaunch = the real game folder (libraryfolders.vdf → appmanifest)
//   Riot.vbs <product> = Riot's own install path (ProgramData\Riot Games\Metadata) · Roblox.vbs = Launchers\Roblox · else the card's cwd
function splitCmd(cmd) {
  const out = [];
  const re = /"([^"]*)"|(\S+)/g;
  let m;
  while ((m = re.exec(cmd))) out.push(m[1] != null ? m[1] : m[2]);
  return out;
}

function steamAppDir(steamExe, appId) {
  const root = path.dirname(steamExe);
  const libs = [root];
  try {
    const vdf = fs.readFileSync(path.join(root, 'steamapps', 'libraryfolders.vdf'), 'utf8');
    for (const m of vdf.matchAll(/"path"\s+"([^"]+)"/g)) libs.push(m[1].replace(/\\\\/g, '\\'));
  } catch { /* no library list: only the Steam folder itself */ }
  for (const lib of libs) {
    try {
      const acf = fs.readFileSync(path.join(lib, 'steamapps', `appmanifest_${appId}.acf`), 'utf8');
      const m = /"installdir"\s+"([^"]+)"/.exec(acf);
      if (m) {
        const d = path.join(lib, 'steamapps', 'common', m[1]);
        if (fs.existsSync(d)) return d;
      }
    } catch { /* not in this library */ }
  }
  return '';
}

function riotProductDir(product) {
  if (!/^[a-z_]+$/.test(product)) return '';
  try {
    const y = fs.readFileSync(path.join(process.env.ProgramData || 'C:\\ProgramData', 'Riot Games', 'Metadata', `${product}.live`, `${product}.live.product_settings.yaml`), 'utf8');
    const m = /product_install_full_path:\s*"?([^"\r\n]+)"?/.exec(y);
    if (m) {
      const d = path.normalize(m[1].trim());
      if (fs.existsSync(d)) return d;
    }
  } catch { /* Riot never installed this product here */ }
  return '';
}

function gameLocation(game) {
  const parts = splitCmd(String((game && game.cmd) || ''));
  const exe = parts[0] || '';
  const base = path.basename(exe).toLowerCase();
  let loc = null;
  if (base === 'steam.exe') {
    const i = parts.findIndex((p) => p.toLowerCase() === '-applaunch');
    const dir = i >= 0 && /^\d+$/.test(parts[i + 1] || '') ? steamAppDir(exe, parts[i + 1]) : '';
    loc = dir ? { path: dir, file: false } : { path: exe, file: true };
  } else if (base === 'wscript.exe' || base === 'cscript.exe') {
    const vi = parts.findIndex((p) => /\.vbs$/i.test(p));
    const vbs = vi >= 0 ? parts[vi] : '';
    const arg = String(parts[vi + 1] || '').toLowerCase();
    const name = path.basename(vbs).toLowerCase();
    const autosync = vbs ? path.dirname(path.dirname(path.dirname(vbs))) : '';   // <Autosync>\System\Client\x.vbs
    if (name === 'riot.vbs') {
      const d = arg && arg !== 'riotclient' && arg !== 'background' ? riotProductDir(arg) : '';
      loc = { path: d || path.join(autosync, 'Launchers', 'Riot Client'), file: false };
    } else if (name === 'roblox.vbs') {
      loc = { path: path.join(autosync, 'Launchers', 'Roblox'), file: false };
    } else if (game.cwd) {
      loc = { path: game.cwd, file: false };
    }
  } else if (exe && path.isAbsolute(exe)) {
    loc = { path: exe, file: true };
  } else if (game.cwd) {
    loc = { path: game.cwd, file: false };
  }
  if (!loc || !loc.path || !fs.existsSync(loc.path)) return { ok: false, error: 'ไม่พบตำแหน่งไฟล์ของเกมนี้บนเครื่อง' };
  return { ok: true, path: loc.path, file: loc.file };
}

function gameById(id) {
  return loadGames().find((g) => g && String(g.id) === String(id || '')) || null;
}

// ── Window / Tray Icon: <GCafe>\data\brand\app.ico (tools\_system\Make-Brand.ps1), else the built-in one ──
function getAppIcon() {
  if (appIcon) return appIcon;
  for (const iconPath of [path.join(gcafeRoot(), 'data', 'brand', 'app.ico'), path.join(__dirname, 'tray-icon.png')]) {
    if (fs.existsSync(iconPath)) {
      appIcon = nativeImage.createFromPath(iconPath);
      if (!appIcon.isEmpty()) break;
    }
  }
  if (!appIcon || appIcon.isEmpty()) {
    const fallback = 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAj0lEQVR4nO3WQQ6AIAwEwP7Am/7B7/lxr5zwTkyhsO1qUpJe2QETWZG/rXLtVRtKqCum3XQ7TnVgCGswFLISrEHCw6cQ6PAWQQkfQnhcvelTeId3b0EDyF2nZwjQOz0S8IpIQAISQAfQf0SfAtAeo4gHidoJzI2IVsnQCEgzDq/lKxBYsIYYHUi4FeMS6rkeEwuHG3zPONYAAAAASUVORK5CYII=';
    appIcon = nativeImage.createFromDataURL('data:image/png;base64,' + fallback);
  }
  return appIcon;
}

// ── Static File Server ──
const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.json': 'application/json; charset=UTF-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.gif': 'image/gif', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.woff2': 'font/woff2', '.woff': 'font/woff',
  '.ttf': 'font/ttf', '.txt': 'text/plain; charset=UTF-8',
};
const POSTER_TYPES = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif']);

function startServer(outDir, callback) {
  server = http.createServer((req, res) => {
    let reqUrl = decodeURI(req.url.split('?')[0]);

    // /poster/<encoded absolute path> -> cover image stored next to a game (e.g. zPoster.jpg)
    // no-cache + ETag (13 Nov): the browser asks every time and gets "not changed" (304) unless the file was replaced,
    // so a new logo / poster shows on the first start (it used to keep the old picture for up to a day)
    if (reqUrl.startsWith('/poster/')) {
      const file = decodeURIComponent(req.url.split('?')[0].slice('/poster/'.length));
      const ext = path.extname(file).toLowerCase();
      if (!POSTER_TYPES.has(ext)) { res.writeHead(404); res.end(); return; }
      fs.stat(file, (err, st) => {
        if (err || !st.isFile()) { res.writeHead(404); res.end(); return; }
        const headers = {
          'Content-Type': MIME_TYPES[ext] || 'image/jpeg', 'Cache-Control': 'no-cache',
          ETag: `W/"${st.size.toString(16)}-${Math.floor(st.mtimeMs).toString(16)}"`, 'Last-Modified': st.mtime.toUTCString(),
        };
        if (req.headers['if-none-match'] === headers.ETag) { res.writeHead(304, headers); res.end(); return; }
        fs.readFile(file, (err2, content) => {
          if (err2) { res.writeHead(404); res.end(); return; }
          res.writeHead(200, headers);
          res.end(content);
        });
      });
      return;
    }

    if (reqUrl === '/') reqUrl = '/index.html';
    let filePath = path.join(outDir, reqUrl);
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      const maybeIndex = path.join(filePath, 'index.html');
      const maybeHtml = filePath + '.html';
      if (fs.existsSync(maybeIndex)) filePath = maybeIndex;
      else if (fs.existsSync(maybeHtml)) filePath = maybeHtml;
      else filePath = path.join(outDir, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
      if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }); res.end('Not Found'); return; }
      res.writeHead(200, ext === '.html' ? { 'Content-Type': contentType, 'Cache-Control': 'no-cache' } : { 'Content-Type': contentType });
      res.end(content);
    });
  });
  server.listen(0, '127.0.0.1', () => {
    serverPort = server.address().port;
    callback(serverPort);
  });
}

// ── Main Window (HUD Widget) ──
// HUD: 310 px wide (x hudSize); the page reports its real height (hud:fit) and the window follows it,
// so a bigger font / zoom / long names never push the bottom buttons under the window edge
const HUD_W = 310, HUD_H = 460;
function hudScale() { return loadConfig().ui.hudSize / 100; }

function createMainWindow(port) {
  const { width: screenW } = screen.getPrimaryDisplay().workAreaSize;
  const winW = Math.round(HUD_W * hudScale()), winH = Math.round(HUD_H * hudScale());

  mainWindow = new BrowserWindow({
    title: loadConfig().brandName,
    icon: getAppIcon(),
    width: winW, height: winH,
    x: Math.max(10, screenW - winW - 20), y: 30,
    frame: false, transparent: true, alwaysOnTop: true,
    resizable: false, hasShadow: false, skipTaskbar: false,
    show: !loadConfig().ui.menuOnly,   // menu-only (17 Nov): the HUD (time left) is never shown
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false, contextIsolation: true,
    },
  });
  mainWindow.loadURL(`http://127.0.0.1:${port}`);
  mainWindow.on('page-title-updated', (e) => e.preventDefault());   // keep the shop name (the page title is fixed text)

  mainWindow.on('close', (event) => {
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      if (dialogWindow) dialogWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
    if (dialogWindow) { dialogWindow.close(); dialogWindow = null; }
    if (server) { server.close(); server = null; }
    app.quit();
  });
}

// ── Show / Restore the program's window (tray, a second start, the end of the lock screen) ──
// the game menu, when open, is the program's one window: bring it back instead of putting the HUD next to it
function showMainWindow() {
  if (lockedNow) { const w = lockWindows[0]; if (w && !w.isDestroyed()) w.focus(); return; }   // no rental: the lock screen stays in front
  if (loadConfig().ui.menuOnly) { openCenterDialog('gamemenu'); return; }   // menu-only: the program's window is the game menu
  if (dialogWindow && !dialogWindow.isDestroyed()) {
    if (dialogWindow.isMinimized()) dialogWindow.restore();
    dialogWindow.show();
    dialogWindow.focus();
    if (mainWindow && mainWindow.isVisible()) mainWindow.hide();
    return;
  }
  if (!mainWindow) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.setAlwaysOnTop(true);
  mainWindow.focus();
}

// the game menu has closed: the HUD comes back where it was (without taking focus when a game was just started)
function backToHud(focus) {
  if (app.isQuitting || !mainWindow || mainWindow.isDestroyed()) return;
  if (loadConfig().ui.menuOnly) return;   // menu-only: there is no HUD to come back to
  if (lockedNow) { pendingOrders = []; showMainWindow(); return; }   // the rental ended: no old toasts for the next customer
  if (focus) showMainWindow();
  else {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.showInactive();
    mainWindow.setAlwaysOnTop(true);
  }
  const list = pendingOrders;
  pendingOrders = [];
  for (const d of list) mainWindow.webContents.send('order-notify', d);
}

function closeDialog(focusHud) {
  const w = dialogWindow;
  if (!w || w.isDestroyed()) { backToHud(focusHud); return; }
  w.$focusHud = focusHud;
  w.close();   // 'closed' brings the HUD back
}

// ── System Tray ──
function createTray() {
  if (tray) return;
  const brand = loadConfig().brandName;
  tray = new Tray(getAppIcon());
  tray.setToolTip(brand);

  tray.setContextMenu(Menu.buildFromTemplate(loadConfig().ui.menuOnly ? [
    { label: 'เปิดเกมเมนู', click: () => openCenterDialog('gamemenu') },
  ] : [
    { label: `แสดงหน้าต่าง ${brand}`, click: showMainWindow },
    { label: 'เปิดเกมเมนู', click: () => openCenterDialog('gamemenu') },
    { label: 'ร้านไอดีเกม', click: () => openCenterDialog('shop') },
    { label: 'คลังรหัสที่ซื้อ', click: () => openCenterDialog('inventory') },
    // no "quit" here: customers must not close the shop program (the agent shows its own lock screen if it stops)
  ]));

  tray.on('click', showMainWindow);
  tray.on('double-click', showMainWindow);
  tray.on('balloon-click', showMainWindow);
}

// ── Center Dialog Window ──
function openCenterDialog(tab) {
  if (lockedNow) return;   // nothing behind the lock screen until a rental starts
  const targetTab = tab || 'gamemenu';
  if (dialogWindow && !dialogWindow.isDestroyed()) {
    if (dialogWindow.isMinimized()) dialogWindow.restore();
    dialogWindow.show();
    dialogWindow.focus();
    if (mainWindow && mainWindow.isVisible()) mainWindow.hide();
    dialogWindow.webContents.send('switch-tab', targetTab);
    return;
  }

  // the dialog grows with menuSize (the page is zoomed by the same amount), never past the screen
  const wa = screen.getPrimaryDisplay().workAreaSize;
  const m = loadConfig().ui.menuSize / 100;
  const fitW = (v) => Math.min(Math.round(v * m), wa.width - 20);
  const fitH = (v) => Math.min(Math.round(v * m), wa.height - 20);
  const w = new BrowserWindow({
    title: loadConfig().brandName,   // same name as the HUD: to the customer it is the same program window
    icon: getAppIcon(),
    width: fitW(1080), height: fitH(680), minWidth: fitW(880), minHeight: fitH(560),
    center: true, frame: false, transparent: true, show: false,
    alwaysOnTop: !loadConfig().ui.menuOnly, resizable: true, hasShadow: false,   // menu-only: a normal window
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false, contextIsolation: true,
    },
  });
  dialogWindow = w;
  // menu-only (17 Nov): the game menu IS the program - closing it (X, starting a game, Alt+F4) only minimizes it to the taskbar
  w.on('close', (e) => { if (loadConfig().ui.menuOnly && !app.isQuitting) { e.preventDefault(); w.minimize(); } });

  // swap: the game menu appears once its page is drawn, then the HUD steps aside (never both, never neither for long)
  let shown = false;
  const reveal = () => {
    if (shown || w.isDestroyed() || dialogWindow !== w) return;
    shown = true;
    w.show();
    w.focus();
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.hide();
  };
  w.once('ready-to-show', reveal);
  setTimeout(reveal, 2500);

  w.loadURL(`http://127.0.0.1:${serverPort}/dialog/?tab=${encodeURIComponent(targetTab)}`);
  w.on('page-title-updated', (e) => e.preventDefault());
  w.webContents.once('did-finish-load', () => {
    if (!w.isDestroyed()) w.webContents.send('switch-tab', targetTab);
  });
  w.on('closed', () => {
    if (dialogWindow === w) dialogWindow = null;
    backToHud(w.$focusHud !== false);
  });
}

// ── IPC Handlers ──
ipcMain.on('config:get', (e) => { e.returnValue = loadConfig(); });
ipcMain.handle('games:list', () => withIcons(loadGames()));
ipcMain.handle('games:launch', (_e, game) => {
  const r = launchGame(game);
  // the game window should not sit behind our always-on-top dialog: back to the small HUD (it does not take the focus)
  if (r.ok && dialogWindow) closeDialog(false);
  return r;
});

// ── 17 Nov (owner's choice): GTA V / FiveM graphics picker - the customer picks low / medium / high every time they press play ──
// <OSYNC>\Settings\gta5_settings.xml = lowest (the shop file), gta5_settings-medium.xml, gta5_settings-high.xml.
// Written for the customer playing now: Documents\Rockstar Games\GTA V\settings.xml (GTA V) + AppData\Roaming\CitizenFX\gta5_settings.xml (FiveM)
// with THIS PC's screen (size + Hz of the main screen), its graphics card (the DirectX name GTA checks - a different name makes GTA
// reset everything) and borderless. Anything going wrong here never stops the game: it starts with what is there and it is logged.
// GCAFE_GTA_TESTDIR=<folder>: write into <folder>\Documents\... and <folder>\AppData\Roaming\..., do NOT start the game (tests).
const GTA_LEVEL_FILES = { low: 'gta5_settings.xml', medium: 'gta5_settings-medium.xml', high: 'gta5_settings-high.xml' };
const GPU_VIRTUAL = /Microsoft Basic|Basic Render|SwiftShader|Remote Display|Virtual|Parsec|Mirage|Meta Display|Citrix|VMware|Hyper-V|Indirect|IddSample|Dummy/i;
function gtaLog(line) {
  try { fs.appendFileSync(path.join(os.tmpdir(), 'gcafe-gta-graphics.log'), `${new Date().toISOString()} ${line}\r\n`); } catch { /* never blocks */ }
}
let gtaGpuCache = null;
async function gtaGpuName() {
  if (gtaGpuCache !== null) return gtaGpuCache;
  let name = '';
  try {
    // the adapter Chromium (DirectX / ANGLE) renders on = the one GTA sees: "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 (0x00002503) Direct3D11 ..."
    const info = await app.getGPUInfo('complete');
    const devs = (info && info.gpuDevice) || [];
    const dev = devs.find((d) => d.active) || devs[0];
    const r = String((info && info.auxAttributes && info.auxAttributes.glRenderer) || '');
    const m = /^ANGLE \([^,]*,\s*(.+?)\s*\(0x[0-9a-f]+\)/i.exec(r);
    for (const c of [dev && dev.deviceString, dev && dev.description, m && m[1]]) {
      if (c && !GPU_VIRTUAL.test(c)) { name = String(c).trim(); break; }
    }
  } catch (e) { gtaLog(`gpu info: ${e.message}`); }
  if (!name) {
    // Windows' own list (same as the boot script): a real card, NVIDIA / AMD first
    try {
      const out = require('child_process').execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
        'Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }'], { encoding: 'utf8', timeout: 8000, windowsHide: true });
      const rank = (s) => (/NVIDIA|GeForce|Quadro/i.test(s) ? 0 : /AMD|Radeon/i.test(s) ? 1 : 2);
      const real = out.split(/\r?\n/).map((s) => s.trim()).filter((s) => s && !GPU_VIRTUAL.test(s)).sort((a, b) => rank(a) - rank(b));
      name = real[0] || '';
    } catch (e) { gtaLog(`gpu wmi: ${e.message}`); }
  }
  gtaGpuCache = name;
  return name;
}
async function gtaInfo() {
  const d = screen.getPrimaryDisplay();
  const sf = d.scaleFactor || 1;
  return { width: Math.round(d.size.width * sf), height: Math.round(d.size.height * sf), hz: Math.round(d.displayFrequency || 0), gpu: await gtaGpuName() };
}
function xmlText(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
async function gtaWrite(level) {
  const info = await gtaInfo();
  const file = GTA_LEVEL_FILES[level] || GTA_LEVEL_FILES.low;
  let x = fs.readFileSync(path.join(path.dirname(gcafeRoot()), 'Settings', file), 'utf8').replace(/^﻿/, '');
  const setVal = (tag, v) => { x = x.replace(new RegExp(`<${tag} value="[^"]*"`), `<${tag} value="${v}"`); };
  if (info.width > 0 && info.height > 0) { setVal('ScreenWidth', info.width); setVal('ScreenHeight', info.height); }
  if (info.hz > 1) setVal('RefreshRate', info.hz);
  setVal('Windowed', 2);   // borderless (owner's choice)
  if (info.gpu) x = x.replace(/<VideoCardDescription>[\s\S]*?<\/VideoCardDescription>/, () => `<VideoCardDescription>${xmlText(info.gpu)}</VideoCardDescription>`);
  const test = process.env.GCAFE_GTA_TESTDIR;
  const docs = test ? path.join(test, 'Documents') : app.getPath('documents');
  const roam = test ? path.join(test, 'AppData', 'Roaming') : app.getPath('appData');
  const written = [];
  for (const f of [path.join(docs, 'Rockstar Games', 'GTA V', 'settings.xml'), path.join(roam, 'CitizenFX', 'gta5_settings.xml')]) {
    try {
      fs.mkdirSync(path.dirname(f), { recursive: true });
      try { fs.chmodSync(f, 0o666); } catch { /* new file or not read-only */ }
      fs.writeFileSync(f, x, 'utf8');
      written.push(f);
    } catch (e) { gtaLog(`write ${f}: ${e.message}`); }
  }
  gtaLog(`${level} (${file}) ${info.width}x${info.height} ${info.hz}Hz card "${info.gpu || 'not found - shop file text'}" -> ${written.length} file(s)`);
  return { info, written };
}
// ── 17 Nov (owner): FiveM extras in the same picker - ReShade (<OSYNC>\Tools\FiveM-ReShade) and mods (<OSYNC>\Tools\FiveM-Mods\<name>) ──
// Turned on: copied into <FiveM>\FiveM.app\plugins (ReShade64.dll as dxgi.dll) / \mods of THIS PC; turned off: only those files are
// removed (a list of what was copied: osync-installed.json next to them). On a diskless client a reboot removes them anyway.
function osyncRoot() { return path.dirname(gcafeRoot()); }
function fivemApp(game) {
  if (process.env.GCAFE_GTA_TESTDIR) return path.join(process.env.GCAFE_GTA_TESTDIR, 'FiveM.app');
  const exe = splitCmd(String((game && game.cmd) || ''))[0] || '';
  if (!/fivem\.exe$/i.test(exe)) return '';
  const dir = path.join(path.dirname(exe), 'FiveM.app');
  return fs.existsSync(dir) ? dir : '';
}
function listFiles(dir) {   // relative paths of every file under dir
  const out = [];
  const walk = (d, rel) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const r = rel ? path.join(rel, e.name) : e.name;
      if (e.isDirectory()) walk(path.join(d, e.name), r); else out.push(r);
    }
  };
  try { if (fs.existsSync(dir)) walk(dir, ''); } catch { /* unreadable = nothing */ }
  return out;
}
const reshadeDir = () => path.join(osyncRoot(), 'Tools', 'FiveM-ReShade');
const modsDir = () => path.join(osyncRoot(), 'Tools', 'FiveM-Mods');
function reshadeFiles() {   // [source, path inside plugins]
  const d = reshadeDir();
  if (!fs.existsSync(path.join(d, 'ReShade64.dll'))) return [];
  return listFiles(d).filter((r) => !/^SOURCE\.txt$/i.test(r)).map((r) => [path.join(d, r), /^ReShade64\.dll$/i.test(r) ? 'dxgi.dll' : r]);
}
function modNames() {
  try {
    return fs.readdirSync(modsDir(), { withFileTypes: true })
      .filter((e) => e.isDirectory() && !e.name.startsWith('_') && listFiles(path.join(modsDir(), e.name)).length).map((e) => e.name);
  } catch { return []; }
}
const manifestOf = (dir) => readJson(path.join(dir, 'osync-installed.json'), {});
function manifestSave(dir, m) { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, 'osync-installed.json'), JSON.stringify(m, null, 1)); }
function fivemState(game) {
  const appDir = fivemApp(game);
  if (!appDir) return { ok: false };
  const pm = manifestOf(path.join(appDir, 'plugins'));
  const mm = manifestOf(path.join(appDir, 'mods'));
  return {
    ok: true,
    reshade: { available: reshadeFiles().length > 0, on: !!(pm.reshade && pm.reshade.length) },
    mods: modNames().map((n) => ({ name: n, on: !!(mm[n] && mm[n].length) })),
  };
}
function copyIn(destDir, pairs) {
  const done = [];
  for (const [src, rel] of pairs) {
    const t = path.join(destDir, rel);
    fs.mkdirSync(path.dirname(t), { recursive: true });
    fs.copyFileSync(src, t);
    done.push(rel);
  }
  return done;
}
function removeOnly(destDir, rels) { for (const rel of rels || []) { try { fs.unlinkSync(path.join(destDir, rel)); } catch { /* gone already */ } } }
// FiveM blocks ReShade 5+ unless FiveM.app\CitizenFX.ini has, under [Addons], the line it prints in F8 (seen on clients 17 Nov:
// files in plugins but no ReShade). Its source (citizenfx/fivem code/components/rage-graphics-five/src/ReShadeFixups.cpp):
//   ReShade5=ID:%08x acknowledged that ReShade 5.x has a bug that will lead to game crashes
// with %08x = HashString(getenv("COMPUTERNAME")) - Jenkins one-at-a-time over the lower-cased name (code/client/shared/Utils.h).
// So each PC gets its own line, written here when ReShade goes on and taken out again when it goes off.
function fivemReshadeAck() {
  let h = 0;
  for (const c of Buffer.from(process.env.COMPUTERNAME || 'a', 'latin1')) {
    h = (h + (c >= 65 && c <= 90 ? c + 32 : c)) >>> 0;
    h = (h + (h << 10)) >>> 0;
    h = (h ^ (h >>> 6)) >>> 0;
  }
  h = (h + (h << 3)) >>> 0;
  h = (h ^ (h >>> 11)) >>> 0;
  h = (h + (h << 15)) >>> 0;
  return `ID:${h.toString(16).padStart(8, '0')} acknowledged that ReShade 5.x has a bug that will lead to game crashes`;
}
// set (value) or take out (null) one key of one [section] in an ini file; returns true when the file changed
function iniSet(file, section, key, value) {
  let t = '';
  try { t = fs.readFileSync(file, 'latin1'); } catch { /* new file */ }
  const nl = /\r\n/.test(t) || !t ? '\r\n' : '\n';
  const lines = t ? t.split(/\r?\n/) : [];
  let sec = -1;
  for (let i = 0; i < lines.length; i++) if (lines[i].trim().toLowerCase() === `[${section.toLowerCase()}]`) { sec = i; break; }
  let end = lines.length;
  if (sec >= 0) for (let i = sec + 1; i < lines.length; i++) if (/^\s*\[/.test(lines[i])) { end = i; break; }
  let at = -1;
  if (sec >= 0) for (let i = sec + 1; i < end; i++) if (lines[i].split('=')[0].trim().toLowerCase() === key.toLowerCase()) { at = i; break; }
  const want = value == null ? null : `${key}=${value}`;
  if (want == null) { if (at < 0) return false; lines.splice(at, 1); }
  else if (at >= 0) { if (lines[at] === want) return false; lines[at] = want; }
  else if (sec >= 0) { let ins = end; while (ins > sec + 1 && !lines[ins - 1].trim()) ins--; lines.splice(ins, 0, want); }
  else { while (lines.length && !lines[lines.length - 1].trim()) lines.pop(); lines.push('', `[${section}]`, want, ''); }
  fs.writeFileSync(file, lines.join(nl), 'latin1');
  return true;
}
function fivemApply(game, extras) {
  const appDir = fivemApp(game);
  if (!appDir || !extras || typeof extras !== 'object') return;
  const plug = path.join(appDir, 'plugins');
  const mods = path.join(appDir, 'mods');
  if (typeof extras.reshade === 'boolean') {
    const m = manifestOf(plug);
    const has = !!(m.reshade && m.reshade.length);
    const ini = path.join(appDir, 'CitizenFX.ini');
    if (extras.reshade && !has) { m.reshade = copyIn(plug, reshadeFiles()); gtaLog(`fivem: ReShade on -> ${m.reshade.length} file(s) in ${plug}`); manifestSave(plug, m); }
    else if (!extras.reshade && has) { removeOnly(plug, m.reshade); delete m.reshade; gtaLog('fivem: ReShade off (its files removed)'); manifestSave(plug, m); }
    // the [Addons] line follows ReShade (also fixes a ReShade turned on before this line existed)
    try {
      if (extras.reshade) { if (iniSet(ini, 'Addons', 'ReShade5', fivemReshadeAck())) { m.ackLine = true; manifestSave(plug, m); gtaLog(`fivem: ${ini} [Addons] ReShade5 set for ${process.env.COMPUTERNAME}`); } }
      else if (m.ackLine) { iniSet(ini, 'Addons', 'ReShade5', null); delete m.ackLine; manifestSave(plug, m); gtaLog('fivem: [Addons] ReShade5 taken out'); }
    } catch (e) { gtaLog(`fivem: CitizenFX.ini: ${e.message}`); }
  }
  if (extras.mods && typeof extras.mods === 'object') {
    const m = manifestOf(mods);
    const names = modNames();
    let changed = false;
    for (const [name, on] of Object.entries(extras.mods)) {
      if (!names.includes(name)) continue;
      const has = !!(m[name] && m[name].length);
      if (on && !has) { const src = path.join(modsDir(), name); m[name] = copyIn(mods, listFiles(src).map((r) => [path.join(src, r), r])); changed = true; gtaLog(`fivem: mod ${name} on`); }
      else if (!on && has) { removeOnly(mods, m[name]); delete m[name]; changed = true; gtaLog(`fivem: mod ${name} off`); }
    }
    if (changed) manifestSave(mods, m);
  }
}
ipcMain.handle('gta:info', () => gtaInfo().catch((e) => ({ error: e.message })));
ipcMain.handle('fivem:state', (_e, game) => { try { return fivemState(game); } catch (e) { return { ok: false, error: e.message }; } });
ipcMain.handle('games:launch-gta', async (_e, game, level, extras) => {
  const lv = Object.prototype.hasOwnProperty.call(GTA_LEVEL_FILES, level) ? level : 'low';
  let w = null;
  try { w = await gtaWrite(lv); } catch (e) { gtaLog(`${lv}: ${e.message} - the game starts with the settings it has`); }
  try { if (extras) fivemApply(game, extras); } catch (e) { gtaLog(`fivem extras: ${e.message} - the game starts anyway`); }
  if (process.env.GCAFE_GTA_TESTDIR) return { ok: true, test: true, level: lv, written: w ? w.written : [], info: w ? w.info : null, five: fivemState(game) };
  const r = launchGame(game);
  if (r.ok && dialogWindow) closeDialog(false);
  return r;
});

// ── 19 Nov (owner): "ขอเกม Steam" ──
// The customer types a Steam store link or AppID; the master queues it and downloads it with DepotDownloader, signed in by the
// customer's own Steam app (QR) - System\Scripts\Master-SteamQueue.ps1. The master's LAN listener (Master-ClientReports.ps1,
// port ClientReportPort 4670) keeps one job per client IP. config.json ui.steamRequest: true = MasterIP + ClientReportPort
// from Settings\settings.txt; a URL = that one (env GCAFE_STEAMREQ_URL overrides both, for the self-test).
function steamReqBase() {
  if (process.env.GCAFE_STEAMREQ_URL) return process.env.GCAFE_STEAMREQ_URL.replace(/\/$/, '');
  const cfg = readJson(path.join(gcafeRoot(), 'config.json'), {});
  const v = cfg.ui && cfg.ui.steamRequest;
  if (typeof v === 'string' && /^https?:\/\/[^\s/]+\/?$/i.test(v)) return v.replace(/\/$/, '');
  if (v !== true) return '';
  try {
    const txt = fs.readFileSync(path.resolve(gcafeRoot(), '..', 'Settings', 'settings.txt'), 'utf8');
    const get = (k) => { const m = txt.match(new RegExp('^\\s*' + k + '\\s*=\\s*([^\\r\\n#]*)', 'mi')); return m ? m[1].trim() : ''; };
    const ip = get('MasterIP');
    const port = (get('ClientReportPort') || '4670').replace(/\D/g, '') || '4670';
    return /^\d{1,3}(\.\d{1,3}){3}$/.test(ip) ? `http://${ip}:${port}` : '';
  } catch { return ''; }
}
function steamReqCall(method, p, body) {
  const base = steamReqBase();
  if (!base) return Promise.resolve({ ok: false, off: true, message: 'ร้านปิดระบบขอเกมไว้' });
  return new Promise((resolve) => {
    let u;
    try { u = new URL(base + p); } catch { resolve({ ok: false, message: 'ที่อยู่เครื่องแม่ไม่ถูกต้อง' }); return; }
    const data = body ? Buffer.from(JSON.stringify(body), 'utf8') : null;
    const req = http.request({ hostname: u.hostname, port: u.port || 80, path: u.pathname, method, timeout: 8000,
      headers: data ? { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': data.length } : {} }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8').replace(/^﻿/, ''))); }
        catch { resolve({ ok: false, message: 'เครื่องแม่ตอบกลับผิดรูปแบบ' }); }
      });
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', () => resolve({ ok: false, offline: true, message: 'ติดต่อเครื่องแม่ไม่ได้ ลองใหม่อีกครั้ง หรือแจ้งพนักงาน' }));
    if (data) req.write(data);
    req.end();
  });
}
ipcMain.handle('steamreq:job', () => steamReqCall('GET', '/steam/job'));
ipcMain.handle('steamreq:send', (_e, text) => steamReqCall('POST', '/steam/request', { app: String(text || '').slice(0, 300), pc: loadConfig().machineId }));
ipcMain.handle('steamreq:cancel', () => steamReqCall('POST', '/steam/cancel', {}));

// right-click menu on a game card (see gameLocation)
ipcMain.handle('games:location', (_e, id) => {
  const g = gameById(id);
  return g ? gameLocation(g) : { ok: false, error: 'ไม่พบเกมนี้ในรายชื่อ' };
});
ipcMain.handle('games:reveal', async (_e, id) => {
  const g = gameById(id);
  const r = g ? gameLocation(g) : { ok: false, error: 'ไม่พบเกมนี้ในรายชื่อ' };
  if (!r.ok) return r;
  if (r.file) shell.showItemInFolder(r.path);
  else {
    const err = await shell.openPath(r.path);
    if (err) return { ok: false, error: err };
  }
  // Explorer must not open behind our always-on-top dialog: back to the small HUD (same as launching a game)
  if (dialogWindow) closeDialog(false);
  return r;
});

ipcMain.on('window-minimize', () => { if (mainWindow) mainWindow.minimize(); });

// HUD page height in window pixels (already includes the page zoom) → resize the HUD window to it
ipcMain.on('hud:fit', (e, h) => {
  if (!mainWindow || mainWindow.isDestroyed() || e.sender !== mainWindow.webContents) return;
  const wa = screen.getPrimaryDisplay().workAreaSize;
  const W = Math.round(HUD_W * hudScale());
  const H = Math.max(200, Math.min(Math.ceil(Number(h) || HUD_H), wa.height - 40));
  const b = mainWindow.getBounds();
  if (b.width !== W || b.height !== H) mainWindow.setBounds({ x: b.x, y: b.y, width: W, height: H });
});

ipcMain.on('window-close', () => {
  if (mainWindow) mainWindow.hide();
  if (dialogWindow) dialogWindow.hide();
  if (tray?.displayBalloon) {
    tray.displayBalloon({ title: loadConfig().brandName, content: 'โปรแกรมซ่อนอยู่ที่นี่ คลิกเพื่อเปิดกลับมา' });
  }
});

ipcMain.on('dialog-maximize', () => {
  if (dialogWindow) { dialogWindow.isMaximized() ? dialogWindow.unmaximize() : dialogWindow.maximize(); }
});
ipcMain.on('dialog-minimize', () => { if (dialogWindow) dialogWindow.minimize(); });
// legacy "quit" from the pages is ignored: logging out ends the rental through the shop system instead
ipcMain.on('quit-app', () => { if (mainWindow) mainWindow.hide(); if (dialogWindow) dialogWindow.hide(); });

// shop system bridge (see readAgent / apiCall above) - the token stays in this process
ipcMain.handle('agent:get', () => readAgent());
ipcMain.handle('api:call', (_e, method, p, body) => apiCall(String(method || 'GET'), String(p || ''), body));
ipcMain.on('open-dialog', (_e, tab) => openCenterDialog(tab));
ipcMain.on('close-dialog', () => closeDialog(true));

// legacy: plain command string
ipcMain.on('launch-game', (_e, cmd) => { if (cmd) launchGame({ cmd }); });

ipcMain.on('order-placed', (_e, data) => {
  if (dialogWindow && !dialogWindow.isDestroyed()) { pendingOrders.push(data); return; }   // the HUD is hidden: show it when it comes back
  if (mainWindow) mainWindow.webContents.send('order-notify', data);
});
// (the old 'add-time' IPC let the top-up page add time without any payment - removed: time only changes from real rentals now)

// ── App Lifecycle ──
app.on('second-instance', () => showMainWindow());

app.whenReady().then(() => {
  loadGames();   // read the game list once at start (right after boot it is always readable)
  startServer(path.join(__dirname, '../out'), (port) => {
    createMainWindow(port);
    createTray();
    if (process.env.GCAFE_SELFTEST) { runSelfTest(process.env.GCAFE_SELFTEST); return; }
    if (loadConfig().ui.menuOnly) openCenterDialog('gamemenu');   // menu-only: the game menu opens at start (no HUD)
    // shop system: follow the agent every second, tell it we are alive every 2 s
    agentTick();
    setInterval(agentTick, 1000);
    writeAlive();
    setInterval(writeAlive, 2000);
  });
});

// Build check (tools\Build-App): HUD screenshot, open the game menu, save screenshots + card count,
// check that only one window shows at a time and that closing the game menu brings the HUD back, quit.
function runSelfTest(outDir) {
  const save = (name, img) => fs.writeFileSync(path.join(outDir, name), img.toPNG());
  const visible = () => BrowserWindow.getAllWindows().filter((x) => !x.isDestroyed() && x.isVisible()).length;
  setTimeout(async () => {
    try { save('selftest-hud.png', await mainWindow.webContents.capturePage()); } catch { /* reported below */ }
    openCenterDialog('gamemenu');
    setTimeout(async () => {
      const result = { games: loadGames().length, build: buildStamp() };
      try {
        result.visibleWindows = visible();
        result.hudHidden = !mainWindow.isVisible();
        result.cards = await dialogWindow.webContents.executeJavaScript('document.querySelectorAll(".game-card").length');
        result.categories = await dialogWindow.webContents.executeJavaScript('Array.from(document.querySelectorAll(".cat-btn")).map(b => b.innerText.replace(/\\s+/g, " "))');
        if (process.env.GCAFE_SELFTEST_CAT) {
          await dialogWindow.webContents.executeJavaScript(`(() => { const c = ${JSON.stringify(process.env.GCAFE_SELFTEST_CAT)}; const b = Array.from(document.querySelectorAll('.cat-btn')).find(x => x.dataset.cat === c || x.innerText.trim().startsWith(c)); if (b) b.click(); })()`);
          await new Promise((ok) => setTimeout(ok, 800));
        }
        // hover the first card so the screenshot shows the play button
        const r = await dialogWindow.webContents.executeJavaScript('(() => { const b = document.querySelector(".game-card").getBoundingClientRect(); return { x: b.x + b.width / 2, y: b.y + b.height / 2 }; })()');
        dialogWindow.webContents.sendInputEvent({ type: 'mouseMove', x: Math.round(r.x), y: Math.round(r.y) });
        await new Promise((ok) => setTimeout(ok, 600));
        save('selftest-gamemenu.png', await dialogWindow.webContents.capturePage());
        // 17 Nov: graphics picker - click the FiveM card: the picker must open (and NOT the game); Esc must close it.
        // With GCAFE_GTA_TESTDIR set: pick "medium" instead -> the settings are written into that folder (no game is started).
        try {
          const js = (s) => dialogWindow.webContents.executeJavaScript(s);
          const clicked = await js(`(() => { const b = Array.from(document.querySelectorAll('.game-card')).find((x) => /FiveM/i.test(x.innerText)); if (b) b.click(); return !!b; })()`);
          await new Promise((ok) => setTimeout(ok, 1500));
          const g = { card: clicked, shown: await js('!!document.querySelector(".gfx-picker")'), levels: await js('document.querySelectorAll(".gfx-level").length') };
          g.text = await js('(() => { const p = document.querySelector(".gfx-picker"); return p ? p.innerText.replace(/\\s+/g, " ").slice(0, 300) : ""; })()');
          save('selftest-gfx.png', await dialogWindow.webContents.capturePage());
          if (process.env.GCAFE_GTA_TESTDIR) {
            await js('(() => { const b = document.querySelector(".gfx-medium"); if (b) b.click(); })()');
            g.reshadeRow = await js('!!document.querySelector(".gfx-reshade")');
            await js('(() => { const b = document.querySelector(".gfx-reshade"); if (b) b.click(); })()');
            await new Promise((ok) => setTimeout(ok, 500));
            save('selftest-gfx-five.png', await dialogWindow.webContents.capturePage());
            await js('(() => { const b = document.querySelector(".gfx-play"); if (b) b.click(); })()');
            await new Promise((ok) => setTimeout(ok, 2500));
            g.afterMedium = { pickerGone: !(await js('!!document.querySelector(".gfx-picker")')) };
          } else {
            dialogWindow.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'Escape' });
            await new Promise((ok) => setTimeout(ok, 800));
            g.afterEsc = { pickerGone: !(await js('!!document.querySelector(".gfx-picker")')), menuStillOpen: !!dialogWindow && dialogWindow.isVisible() };
          }
          g.info = await gtaInfo();
          result.gfx = g;
        } catch (e) { result.gfx = { error: e.message }; }
        // 19 Nov: "ขอเกม Steam" - only with GCAFE_STEAMREQ_URL (a test listener): open it, send GCAFE_STEAMREQ_APP (480),
        // wait for the job (QR when the master signs in with QR), screenshot, cancel, Esc
        if (process.env.GCAFE_STEAMREQ_URL) {
          const s = {};
          try {
            const js = (x) => dialogWindow.webContents.executeJavaScript(x);
            const wait = (ms) => new Promise((ok) => setTimeout(ok, ms));
            s.button = await js(`(() => { const b = document.querySelector('.steamreq-open'); if (b) b.click(); return !!b; })()`);
            await wait(1500);
            s.lastJob = await js('(() => { const p = document.querySelector(".steamreq-job"); return p ? p.className : ""; })()');
            await js(`(() => { const b = document.querySelector('.steamreq-again'); if (b) b.click(); })()`);   // a finished job is shown first
            await wait(500);
            s.form = await js('!!document.querySelector(".steamreq-input")');
            save('selftest-steamreq-form.png', await dialogWindow.webContents.capturePage());
            const app = JSON.stringify(process.env.GCAFE_STEAMREQ_APP || '480');
            await js(`(() => { const i = document.querySelector('.steamreq-input'); if (!i) return; const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; set.call(i, ${app}); i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
            await wait(300);
            await js(`(() => { const b = document.querySelector('.steamreq-send'); if (b) b.click(); })()`);
            for (let i = 0; i < 40; i++) { await wait(1000); if (await js('!!document.querySelector(".steamreq-qr") || !!document.querySelector(".steamreq-done, .steamreq-exists, .steamreq-failed")')) break; }
            s.qr = await js('!!document.querySelector(".steamreq-qr")');
            s.text = await js('(() => { const p = document.querySelector(".steamreq"); return p ? p.innerText.replace(/\\s+/g, " ").slice(0, 400) : ""; })()');
            save('selftest-steamreq.png', await dialogWindow.webContents.capturePage());
            const canceled = await js(`(() => { const b = document.querySelector('.steamreq-cancel'); if (b) b.click(); return !!b; })()`);
            if (canceled) { for (let i = 0; i < 20; i++) { await wait(1000); if (await js('!!document.querySelector(".steamreq-canceled, .steamreq-failed")')) break; } }
            s.afterCancel = await js('(() => { const p = document.querySelector(".steamreq-job"); return p ? p.className : ""; })()');
            save('selftest-steamreq-cancel.png', await dialogWindow.webContents.capturePage());
            dialogWindow.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'Escape' });
            await wait(800);
            s.closed = !(await js('!!document.querySelector(".steamreq")'));
          } catch (e) { s.error = e.message; }
          result.steamreq = s;
        }
        closeDialog(true);
        await new Promise((ok) => setTimeout(ok, 1000));
        result.afterClose = { menuOpen: !!dialogWindow, hudVisible: mainWindow.isVisible(), visibleWindows: visible() };
      } catch (e) { result.error = e.message; }
      fs.writeFileSync(path.join(outDir, 'selftest.json'), JSON.stringify(result, null, 2));
      app.isQuitting = true; app.quit();
    }, 6000);
  }, 3000);
}

app.on('window-all-closed', () => {
  if (server) server.close();
  if (process.platform !== 'darwin') app.quit();
});
