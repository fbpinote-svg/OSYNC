const { contextBridge, ipcRenderer } = require('electron');

// settings from <GCafe>\config.json (brand, station id = PC name, API url; empty url = offline)
contextBridge.exposeInMainWorld('appConfig', ipcRenderer.sendSync('config:get'));

contextBridge.exposeInMainWorld('electronAPI', {
  // Main window controls
  minimize: () => ipcRenderer.send('window-minimize'),
  fitHud: (height) => ipcRenderer.send('hud:fit', height),   // HUD page height (window px) → window follows it
  close: () => ipcRenderer.send('window-close'),
  quitApp: () => ipcRenderer.send('quit-app'),

  // Dialog window
  openDialog: (tab) => ipcRenderer.send('open-dialog', tab),
  closeDialog: () => ipcRenderer.send('close-dialog'),
  maximizeDialog: () => ipcRenderer.send('dialog-maximize'),
  minimizeDialog: () => ipcRenderer.send('dialog-minimize'),

  // Offline game menu (data\games.json)
  getGames: () => ipcRenderer.invoke('games:list'),
  launch: (game) => ipcRenderer.invoke('games:launch', game),
  launchGame: (cmd) => ipcRenderer.send('launch-game', cmd),
  // 17 Nov: GTA V / FiveM graphics picker - this PC's screen + card, and "write the chosen level, then start"
  gtaInfo: () => ipcRenderer.invoke('gta:info'),
  launchGta: (game, level, extras) => ipcRenderer.invoke('games:launch-gta', game, level, extras),
  // FiveM extras (ReShade / mods) that can be turned on in the picker, and whether they are on now
  fivemState: (game) => ipcRenderer.invoke('fivem:state', game),
  // right-click on a game card: where it is on disk / open that place in Explorer (looked up by id in main.js)
  gameLocation: (id) => ipcRenderer.invoke('games:location', id),
  revealGame: (id) => ipcRenderer.invoke('games:reveal', id),
  // 19 Nov: "ขอเกม Steam" - this PC's request on the master (job), send a link / AppID, cancel it
  steamReq: {
    job: () => ipcRenderer.invoke('steamreq:job'),
    send: (text) => ipcRenderer.invoke('steamreq:send', text),
    cancel: () => ipcRenderer.invoke('steamreq:cancel'),
  },

  // IPC listeners
  onOpenSettings: (cb) => ipcRenderer.on('open-settings', () => cb()),
  onSwitchTab: (cb) => ipcRenderer.on('switch-tab', (_e, tab) => cb(tab)),
  onOrderNotify: (cb) => ipcRenderer.on('order-notify', (_e, data) => cb(data)),

  // Cross-window messaging (dialog → HUD toast after a real purchase / top-up)
  sendOrder: (data) => ipcRenderer.send('order-placed', data),

  // Shop system (Cooper Agent 1.20+): live state from the agent + calls to the shop web (token stays in main.js)
  agent: {
    get: () => ipcRenderer.invoke('agent:get'),
    onUpdate: (cb) => ipcRenderer.on('agent:update', (_e, v) => cb(v)),
    api: (method, p, body) => ipcRenderer.invoke('api:call', method, p, body),
  },
});
