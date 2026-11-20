# 0JAYSHOP Client — source

Source of the game menu that runs on the client PCs (`Menu\app\<shop name>.exe`).
Electron 44 (main process) + Next.js 16 / React 19 (pages, static export to `out\`).

Full documentation, function by function: [`System/Docs/06-MENU.md`](../../System/Docs/06-MENU.md).
Shop system / time system (off at this shop: `apiUrl` is empty, `ui.menuOnly` is `true`): [`System/Docs/SHOP-API.md`](../../System/Docs/SHOP-API.md).

## Layout

```
electron/main.js      main process: local HTTP server (127.0.0.1, random port) for out\ and /poster/,
                      windows (HUD, game menu, lock screen), tray, IPC, game launch, GTA graphics picker,
                      "ขอเกม Steam" requests to the master
electron/preload.js   window.appConfig + window.electronAPI (the only bridge from the pages)
src/app/dialog/       game menu window (the page customers use) + shop tabs
src/app/page.jsx      HUD (time left) - hidden when ui.menuOnly is true
src/app/lock/         full-screen lock screen - only with Cooper Agent files on the PC
src/components/       ShopTabs, TopupPanel (shop system), Icons (line icons)
src/lib/config.js     reads the shop values (window.appConfig = ..\config.json)
src/lib/api.js        REST client for apiUrl (offline when empty) + gamesService
src/lib/totp.js       2-Step codes for bought game IDs
```

At run time the program reads `..\config.json` and `..\data\games.json` (the `Menu\` folder above `app\`).
Editing those needs no rebuild.

## Build

Build on the master, with the menu closed there:

- `OSYNC.bat > 7 > 3` ("Build the menu program"), or
- `Menu\tools\Build-App.bat` (`tools\_system\Build-App.ps1`, `-NoTest` skips the self-test)

No Node.js install is needed: Build-App runs `node_modules\electron\dist\electron.exe` as Node
(`ELECTRON_RUN_AS_NODE=1`) for `next build`, copies the Electron runtime plus `electron\` and `out\`
into `Menu\app\`, writes the shop name and `data\brand\app.ico` into the .exe, then runs a self-test
(results in `Menu\_build\selftest\`). If `node_modules` is missing: install Node.js LTS and run `npm ci` here.

Clients start the program from `Menu\app\` on the shared game disk, so they see a new build after a reboot.

`npm run dist` (electron-packager) is not used by the shop.

## Development

- `npm run dev` — Next.js dev server in a browser (no `window.electronAPI`, so no game list / launch)
- `npm run build` then `npm start` — the Electron app from this folder (serves `out\`)
