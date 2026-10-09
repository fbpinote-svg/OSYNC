const { app, BrowserWindow, screen, ipcMain, Tray, Menu, shell, nativeImage } = require('electron');
const path = require('path');
const http = require('http');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

// ── Windows App Identity ──
if (process.platform === 'win32') {
  app.setAppUserModelId('0JAYSHOP.Client');
}

// tools\Build-GameList: "0JAYSHOP.exe --imagetool <jobs.json>" renders posters and exits (no window, no single-instance lock)
const imagetoolArg = process.argv.indexOf('--imagetool');
if (imagetoolArg > 0) {
  require(path.join(gcafeRoot(), 'tools', '_system', 'imagetool', 'render.js'))(process.argv[imagetoolArg + 1]);
  return;
}

// one copy per PC: a second start just brings the HUD back
if (!app.requestSingleInstanceLock()) {
  app.quit();
}

let mainWindow = null;
let dialogWindow = null;
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
function localImageUrl(p) {
  if (!p || /^(https?:|data:|\/)/i.test(p)) return p || '';
  return '/poster/' + encodeURIComponent(path.resolve(gcafeRoot(), p));
}

function loadConfig() {
  const cfg = readJson(path.join(gcafeRoot(), 'config.json'), {});
  const defaultLogo = path.join(gcafeRoot(), 'data', 'brand', 'logo.png');
  return {
    brandName: cfg.brandName || '0JAYSHOP',
    brandBadge: cfg.brandBadge || 'VIP',
    brandLogo: localImageUrl(cfg.brandLogo || (fs.existsSync(defaultLogo) ? defaultLogo : '')),
    apiUrl: cfg.apiUrl || '',                 // empty = offline (game menu works from games.json)
    machineId: cfg.machineId || os.hostname(),
  };
}

function loadGames() {
  const list = readJson(path.join(gcafeRoot(), 'data', 'games.json'), []);
  return Array.isArray(list) ? list : [];
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
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
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
    if (reqUrl.startsWith('/poster/')) {
      const file = decodeURIComponent(req.url.split('?')[0].slice('/poster/'.length));
      const ext = path.extname(file).toLowerCase();
      if (!POSTER_TYPES.has(ext)) { res.writeHead(404); res.end(); return; }
      fs.readFile(file, (err, content) => {
        if (err) { res.writeHead(404); res.end(); return; }
        res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'image/jpeg', 'Cache-Control': 'max-age=86400' });
        res.end(content);
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
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    });
  });
  server.listen(0, '127.0.0.1', () => {
    serverPort = server.address().port;
    callback(serverPort);
  });
}

// ── Main Window (HUD Widget) ──
function createMainWindow(port) {
  const { width: screenW } = screen.getPrimaryDisplay().workAreaSize;
  const winW = 310, winH = 460;

  mainWindow = new BrowserWindow({
    title: loadConfig().brandName,
    icon: getAppIcon(),
    width: winW, height: winH,
    x: Math.max(10, screenW - winW - 20), y: 30,
    frame: false, transparent: true, alwaysOnTop: true,
    resizable: false, hasShadow: false, skipTaskbar: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false, contextIsolation: true,
    },
  });
  mainWindow.loadURL(`http://127.0.0.1:${port}`);

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

// ── Show / Restore Main Window ──
function showMainWindow() {
  if (!mainWindow) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.setAlwaysOnTop(true);
  mainWindow.focus();
}

// ── System Tray ──
function createTray() {
  if (tray) return;
  const brand = loadConfig().brandName;
  tray = new Tray(getAppIcon());
  tray.setToolTip(brand);

  tray.setContextMenu(Menu.buildFromTemplate([
    { label: `🖥️ แสดงหน้าต่าง ${brand}`, click: showMainWindow },
    { label: '🕹️ เปิดเกมเมนู', click: () => openCenterDialog('gamemenu') },
    { label: '🛒 ร้านไอดีเกม', click: () => openCenterDialog('shop') },
    { label: '🔑 คลังรหัสที่ซื้อ', click: () => openCenterDialog('inventory') },
    { type: 'separator' },
    { label: '🚪 ออกจากโปรแกรม', click: () => { app.isQuitting = true; app.quit(); } },
  ]));

  tray.on('click', showMainWindow);
  tray.on('double-click', showMainWindow);
  tray.on('balloon-click', showMainWindow);
}

// ── Center Dialog Window ──
function openCenterDialog(tab) {
  const targetTab = tab || 'gamemenu';
  if (dialogWindow) {
    if (dialogWindow.isMinimized()) dialogWindow.restore();
    dialogWindow.show();
    dialogWindow.focus();
    dialogWindow.webContents.send('switch-tab', targetTab);
    return;
  }

  dialogWindow = new BrowserWindow({
    title: `${loadConfig().brandName} - Game Launcher`,
    icon: getAppIcon(),
    width: 1080, height: 680, minWidth: 880, minHeight: 560,
    center: true, frame: false, transparent: true,
    alwaysOnTop: true, resizable: true, hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false, contextIsolation: true,
    },
  });

  dialogWindow.loadURL(`http://127.0.0.1:${serverPort}/dialog/?tab=${encodeURIComponent(targetTab)}`);
  dialogWindow.webContents.once('did-finish-load', () => {
    if (dialogWindow) dialogWindow.webContents.send('switch-tab', targetTab);
  });
  dialogWindow.on('closed', () => { dialogWindow = null; });
}

// ── IPC Handlers ──
ipcMain.on('config:get', (e) => { e.returnValue = loadConfig(); });
ipcMain.handle('games:list', () => loadGames());
ipcMain.handle('games:launch', (_e, game) => {
  const r = launchGame(game);
  // the game window should not sit behind our always-on-top dialog
  if (r.ok && dialogWindow) dialogWindow.minimize();
  return r;
});

ipcMain.on('window-minimize', () => { if (mainWindow) mainWindow.minimize(); });

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
ipcMain.on('quit-app', () => { app.isQuitting = true; app.quit(); });
ipcMain.on('open-dialog', (_e, tab) => openCenterDialog(tab));
ipcMain.on('close-dialog', () => { if (dialogWindow) { dialogWindow.close(); dialogWindow = null; } });

// legacy: plain command string
ipcMain.on('launch-game', (_e, cmd) => { if (cmd) launchGame({ cmd }); });

ipcMain.on('order-placed', (_e, data) => { if (mainWindow) mainWindow.webContents.send('order-notify', data); });
ipcMain.on('add-time', (_e, sec) => { if (mainWindow) mainWindow.webContents.send('time-added', sec); });

// ── App Lifecycle ──
app.on('second-instance', () => showMainWindow());

app.whenReady().then(() => {
  startServer(path.join(__dirname, '../out'), (port) => {
    createMainWindow(port);
    createTray();
    if (process.env.GCAFE_SELFTEST) runSelfTest(process.env.GCAFE_SELFTEST);
  });
});

// Build check (tools\Build-App): open the game menu, save screenshots + card count, quit.
function runSelfTest(outDir) {
  const save = (name, img) => fs.writeFileSync(path.join(outDir, name), img.toPNG());
  setTimeout(() => {
    openCenterDialog('gamemenu');
    setTimeout(async () => {
      const result = { games: loadGames().length };
      try {
        result.cards = await dialogWindow.webContents.executeJavaScript('document.querySelectorAll(".game-card").length');
        result.categories = await dialogWindow.webContents.executeJavaScript('Array.from(document.querySelectorAll(".cat-btn")).map(b => b.innerText.replace(/\\s+/g, " "))');
        if (process.env.GCAFE_SELFTEST_CAT) {
          await dialogWindow.webContents.executeJavaScript(`(() => { const b = Array.from(document.querySelectorAll('.cat-btn')).find(x => x.innerText.startsWith(${JSON.stringify(process.env.GCAFE_SELFTEST_CAT)})); if (b) b.click(); })()`);
          await new Promise((ok) => setTimeout(ok, 800));
        }
        // hover the first card so the screenshot shows the play button
        const r = await dialogWindow.webContents.executeJavaScript('(() => { const b = document.querySelector(".game-card").getBoundingClientRect(); return { x: b.x + b.width / 2, y: b.y + b.height / 2 }; })()');
        dialogWindow.webContents.sendInputEvent({ type: 'mouseMove', x: Math.round(r.x), y: Math.round(r.y) });
        await new Promise((ok) => setTimeout(ok, 600));
        save('selftest-hud.png', await mainWindow.webContents.capturePage());
        save('selftest-gamemenu.png', await dialogWindow.webContents.capturePage());
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
