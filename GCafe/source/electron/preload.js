const { contextBridge, ipcRenderer } = require('electron');

// settings from <GCafe>\config.json (brand, station id = PC name, API url; empty url = offline)
contextBridge.exposeInMainWorld('appConfig', ipcRenderer.sendSync('config:get'));

contextBridge.exposeInMainWorld('electronAPI', {
  // Main window controls
  minimize: () => ipcRenderer.send('window-minimize'),
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

  // IPC listeners
  onOpenSettings: (cb) => ipcRenderer.on('open-settings', () => cb()),
  onSwitchTab: (cb) => ipcRenderer.on('switch-tab', (_e, tab) => cb(tab)),
  onOrderNotify: (cb) => ipcRenderer.on('order-notify', (_e, data) => cb(data)),
  onTimeAdded: (cb) => ipcRenderer.on('time-added', (_e, sec) => cb(sec)),

  // Cross-window messaging
  sendOrder: (data) => ipcRenderer.send('order-placed', data),
  addTime: (sec) => ipcRenderer.send('add-time', sec),
});
