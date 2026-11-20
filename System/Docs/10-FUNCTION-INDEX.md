# 10 · ดัชนีฟังก์ชันทั้งหมด (สร้างจากโค้ดอัตโนมัติ)

ไฟล์โค้ด 85 ไฟล์ · ฟังก์ชัน 638 ตัว · สร้างเมื่อ 20 Nov 2026 21:28 จากโค้ดใน repo นี้

- **PowerShell** อ่านด้วยตัวแยกโค้ดของ PowerShell เอง (AST) จึงได้ชื่อ บรรทัด และพารามิเตอร์ตรงกับโค้ดจริงทุกตัว
- **JavaScript / JSX** (เมนูเกม) หาจากรูปแบบ `function x(` / `const x = (...) =>` / เมธอดในออบเจ็กต์ ตัวที่เขียนแบบอื่นอาจไม่อยู่ในรายการ
- คอลัมน์ **หมายเหตุในโค้ด** = คอมเมนต์ที่อยู่เหนือฟังก์ชันนั้นในโค้ด (ภาษาอังกฤษตามต้นฉบับ) · คำอธิบายภาษาไทยทีละฟังก์ชันอยู่ในบทที่ลิงก์ไว้ของแต่ละไฟล์
- คลิกชื่อฟังก์ชัน = เปิดโค้ดที่บรรทัดนั้น

## สารบัญ

- **[เครื่องแม่](03-MASTER.md)**
  - [System/Scripts/Master-CitizenFX.ps1](#system-scripts-master-citizenfx-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-ClientReports.ps1](#system-scripts-master-clientreports-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Master-FiveMShare.ps1](#system-scripts-master-fivemshare-ps1) — 14 ฟังก์ชัน
  - [System/Scripts/Master-GameList.ps1](#system-scripts-master-gamelist-ps1) — 10 ฟังก์ชัน
  - [System/Scripts/Master-Move-Launcher.ps1](#system-scripts-master-move-launcher-ps1) — 7 ฟังก์ชัน
  - [System/Scripts/Master-OslinkLogins.ps1](#system-scripts-master-oslinklogins-ps1) — 7 ฟังก์ชัน
  - [System/Scripts/Master-Setup.ps1](#system-scripts-master-setup-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Master-Snapshot-BattleNet.ps1](#system-scripts-master-snapshot-battlenet-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-Snapshot-EA.ps1](#system-scripts-master-snapshot-ea-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-Snapshot-Epic.ps1](#system-scripts-master-snapshot-epic-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-Snapshot-Riot.ps1](#system-scripts-master-snapshot-riot-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-Steam-Library.ps1](#system-scripts-master-steam-library-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Master-SteamQueue.ps1](#system-scripts-master-steamqueue-ps1) — 11 ฟังก์ชัน
  - [System/Scripts/Master-Update.ps1](#system-scripts-master-update-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Master-Watch.ps1](#system-scripts-master-watch-ps1) — 6 ฟังก์ชัน
  - [System/Scripts/SteamQueue-Lib.ps1](#system-scripts-steamqueue-lib-ps1) — 9 ฟังก์ชัน
- **[เครื่องลูก: การบูตและไดรเวอร์](04-CLIENT-BOOT.md)**
  - [System/Client/Boot.ps1](#system-client-boot-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Client-DesktopClean.ps1](#system-scripts-client-desktopclean-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Client-Firewall.ps1](#system-scripts-client-firewall-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Client-Install.ps1](#system-scripts-client-install-ps1) — 3 ฟังก์ชัน
  - [System/Scripts/Client-Menu.ps1](#system-scripts-client-menu-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Client-Mic.ps1](#system-scripts-client-mic-ps1) — 18 ฟังก์ชัน
  - [System/Scripts/Client-Parsec.ps1](#system-scripts-client-parsec-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Client-PopupGuard.ps1](#system-scripts-client-popupguard-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Client-Runtimes.ps1](#system-scripts-client-runtimes-ps1) — 4 ฟังก์ชัน
  - [System/Scripts/Client-Sunshine0J.ps1](#system-scripts-client-sunshine0j-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Client-Vdd.ps1](#system-scripts-client-vdd-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Client-WinRAR.ps1](#system-scripts-client-winrar-ps1) — 0 ฟังก์ชัน
- **[เครื่องลูก: เกม ตัวเปิดเกม บัญชี](05-CLIENT-GAMES.md)**
  - [System/Scripts/Client-ClearLogins.ps1](#system-scripts-client-clearlogins-ps1) — 8 ฟังก์ชัน
  - [System/Scripts/Client-EA-AntiCheat.ps1](#system-scripts-client-ea-anticheat-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Client-EA.ps1](#system-scripts-client-ea-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Client-EAC.ps1](#system-scripts-client-eac-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Client-Epic-Start.ps1](#system-scripts-client-epic-start-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Client-FiveMShare.ps1](#system-scripts-client-fivemshare-ps1) — 12 ฟังก์ชัน
  - [System/Scripts/Client-GameStart.ps1](#system-scripts-client-gamestart-ps1) — 3 ฟังก์ชัน
  - [System/Scripts/Client-GtaSettings.ps1](#system-scripts-client-gtasettings-ps1) — 5 ฟังก์ชัน
  - [System/Scripts/Client-NEWTHINGS.ps1](#system-scripts-client-newthings-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Client-OslinkDrivers.ps1](#system-scripts-client-oslinkdrivers-ps1) — 5 ฟังก์ชัน
  - [System/Scripts/Client-OslinkHelper.ps1](#system-scripts-client-oslinkhelper-ps1) — 7 ฟังก์ชัน
  - [System/Scripts/Client-OslinkLogin.ps1](#system-scripts-client-oslinklogin-ps1) — 7 ฟังก์ชัน
  - [System/Scripts/Client-OslinkReport.ps1](#system-scripts-client-oslinkreport-ps1) — 6 ฟังก์ชัน
  - [System/Scripts/Client-OslinkReset.ps1](#system-scripts-client-oslinkreset-ps1) — 5 ฟังก์ชัน
  - [System/Scripts/Client-Riot-Start.ps1](#system-scripts-client-riot-start-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Client-Roblox.ps1](#system-scripts-client-roblox-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Client-Steam-FirstRun.ps1](#system-scripts-client-steam-firstrun-ps1) — 6 ฟังก์ชัน
  - [System/Scripts/Client-SteamVerify.ps1](#system-scripts-client-steamverify-ps1) — 1 ฟังก์ชัน
- **[โปรแกรมเมนูเกม](06-MENU.md)**
  - [Menu/source/electron/main.js](#menu-source-electron-main-js) — 71 ฟังก์ชัน
  - [Menu/source/electron/preload.js](#menu-source-electron-preload-js) — 0 ฟังก์ชัน
  - [Menu/source/next.config.js](#menu-source-next-config-js) — 0 ฟังก์ชัน
  - [Menu/source/src/app/dialog/page.jsx](#menu-source-src-app-dialog-page-jsx) — 41 ฟังก์ชัน
  - [Menu/source/src/app/layout.jsx](#menu-source-src-app-layout-jsx) — 1 ฟังก์ชัน
  - [Menu/source/src/app/lock/page.jsx](#menu-source-src-app-lock-page-jsx) — 15 ฟังก์ชัน
  - [Menu/source/src/app/page.jsx](#menu-source-src-app-page-jsx) — 10 ฟังก์ชัน
  - [Menu/source/src/components/Icons.jsx](#menu-source-src-components-icons-jsx) — 1 ฟังก์ชัน
  - [Menu/source/src/components/ShopTabs.jsx](#menu-source-src-components-shoptabs-jsx) — 39 ฟังก์ชัน
  - [Menu/source/src/components/TopupPanel.jsx](#menu-source-src-components-topuppanel-jsx) — 7 ฟังก์ชัน
  - [Menu/source/src/lib/api.js](#menu-source-src-lib-api-js) — 18 ฟังก์ชัน
  - [Menu/source/src/lib/config.js](#menu-source-src-lib-config-js) — 15 ฟังก์ชัน
  - [Menu/source/src/lib/totp.js](#menu-source-src-lib-totp-js) — 9 ฟังก์ชัน
  - [Menu/tools/_system/imagetool/main.js](#menu-tools-_system-imagetool-main-js) — 0 ฟังก์ชัน
  - [Menu/tools/_system/imagetool/render.js](#menu-tools-_system-imagetool-render-js) — 0 ฟังก์ชัน
  - [Menu/tools/_system/Set-ExeInfo.mjs](#menu-tools-_system-set-exeinfo-mjs) — 2 ฟังก์ชัน
- **[คอนโซลแอดมินและคลังออนไลน์](07-CONSOLE-ONLINE-FUNCTIONS.md)**
  - [System/Console/index.html](#system-console-index-html) — 40 ฟังก์ชัน
  - [System/Scripts/Console-Server.ps1](#system-scripts-console-server-ps1) — 29 ฟังก์ชัน
  - [System/Scripts/Hub-Server.ps1](#system-scripts-hub-server-ps1) — 7 ฟังก์ชัน
  - [System/Scripts/Online-Library.ps1](#system-scripts-online-library-ps1) — 38 ฟังก์ชัน
  - [System/Scripts/Online-Torrent.ps1](#system-scripts-online-torrent-ps1) — 10 ฟังก์ชัน
  - [System/Scripts/Online-Upnp.ps1](#system-scripts-online-upnp-ps1) — 14 ฟังก์ชัน
  - [System/Tests/Fake-Igd.ps1](#system-tests-fake-igd-ps1) — 2 ฟังก์ชัน
  - [System/Tests/Sim-OnlineLibrary.ps1](#system-tests-sim-onlinelibrary-ps1) — 7 ฟังก์ชัน
  - [System/Tests/Test-Console.ps1](#system-tests-test-console-ps1) — 4 ฟังก์ชัน
- **[แกนกลางและเครื่องมือ](08-CORE-TOOLS.md)**
  - [System/Scripts/Branch-Runner.ps1](#system-scripts-branch-runner-ps1) — 10 ฟังก์ชัน
  - [System/Scripts/Common.ps1](#system-scripts-common-ps1) — 35 ฟังก์ชัน
  - [System/Scripts/Http-Lib.ps1](#system-scripts-http-lib-ps1) — 10 ฟังก์ชัน
  - [System/Scripts/OSYNC.ps1](#system-scripts-osync-ps1) — 5 ฟังก์ชัน
  - [System/Scripts/Setup-Install.ps1](#system-scripts-setup-install-ps1) — 13 ฟังก์ชัน
  - [System/Scripts/Setup-Plan.ps1](#system-scripts-setup-plan-ps1) — 3 ฟังก์ชัน
  - [System/Scripts/Tool-Check.ps1](#system-scripts-tool-check-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Tool-Folder-Icons.ps1](#system-scripts-tool-folder-icons-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Tool-LinkScan.ps1](#system-scripts-tool-linkscan-ps1) — 0 ฟังก์ชัน
  - [System/Scripts/Tool-Migrate.ps1](#system-scripts-tool-migrate-ps1) — 2 ฟังก์ชัน
  - [System/Scripts/Tool-Organize-Drive.ps1](#system-scripts-tool-organize-drive-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Tool-Pack.ps1](#system-scripts-tool-pack-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Tool-RiotDiag.ps1](#system-scripts-tool-riotdiag-ps1) — 1 ฟังก์ชัน
  - [System/Scripts/Tool-SunshineProfiles.ps1](#system-scripts-tool-sunshineprofiles-ps1) — 0 ฟังก์ชัน

## เครื่องแม่

คำอธิบายเต็ม: [03-MASTER.md](03-MASTER.md)

<a id="system-scripts-master-citizenfx-ps1"></a>
### System/Scripts/Master-CitizenFX.ps1

28 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Check` · [เปิดไฟล์](../Scripts/Master-CitizenFX.ps1)

<a id="system-scripts-master-clientreports-ps1"></a>
### System/Scripts/Master-ClientReports.ps1

111 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Install`, `Uninstall`, `Status`, `Port`, `Dir`, `AllowLoopback`, `MaxRequests` · [เปิดไฟล์](../Scripts/Master-ClientReports.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-LanIp`](../Scripts/Master-ClientReports.ps1#L55) | 55-60 | `ip` |  |

<a id="system-scripts-master-fivemshare-ps1"></a>
### System/Scripts/Master-FiveMShare.ps1

304 บรรทัด · 14 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Install`, `Uninstall`, `Status`, `Port`, `CacheDir`, `AllowLoopback`, `MaxRequests`, `NoProcessCheck` · [เปิดไฟล์](../Scripts/Master-FiveMShare.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-CacheDir`](../Scripts/Master-FiveMShare.ps1#L34) | 34-39 | - |  |
| 2 | [`Get-Fingerprint`](../Scripts/Master-FiveMShare.ps1#L41) | 41-46 | `db` | fingerprint of an index folder: names, sizes and times of its files (a client sees the master's values) |
| 3 | [`Test-FiveMRunning`](../Scripts/Master-FiveMShare.ps1#L47) | 47-47 | - |  |
| 4 | [`Log`](../Scripts/Master-FiveMShare.ps1#L89) | 89-94 | `s` |  |
| 5 | [`Test-LanIp`](../Scripts/Master-FiveMShare.ps1#L105) | 105-110 | `ip` |  |
| 6 | [`Send`](../Scripts/Master-FiveMShare.ps1#L112) | 112-118 | `stream`, `code`, `obj`, `Quiet` | -Quiet: the caller logs it itself (with more detail) |
| 7 | [`Get-Free`](../Scripts/Master-FiveMShare.ps1#L119) | 119-119 | - |  |
| 8 | [`Remove-Session`](../Scripts/Master-FiveMShare.ps1#L120) | 120-124 | `id` |  |
| 9 | [`Remove-OldSessions`](../Scripts/Master-FiveMShare.ps1#L125) | 125-127 | - |  |
| 10 | [`Get-MB`](../Scripts/Master-FiveMShare.ps1#L128) | 128-128 | `b` |  |
| 11 | [`Invoke-Adopt`](../Scripts/Master-FiveMShare.ps1#L130) | 130-150 | `sess` | adopt a client's index + its new files (called with everything checked) |
| 12 | [`Handle`](../Scripts/Master-FiveMShare.ps1#L152) | 152-288 | `c` |  |
| 13 | [`Read-Json`](../Scripts/Master-FiveMShare.ps1#L170) | 170-170 | - | small JSON bodies |
| 14 | [`Get-Sess`](../Scripts/Master-FiveMShare.ps1#L172) | 172-172 | `id` | a session of this PC (another PC's session id is "no session") |

<a id="system-scripts-master-gamelist-ps1"></a>
### System/Scripts/Master-GameList.ps1

330 บรรทัด · 10 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Out` · [เปิดไฟล์](../Scripts/Master-GameList.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Export-Icon`](../Scripts/Master-GameList.ps1#L31) | 31-39 | `file`, `png` | 256px icon of an .exe/.ico -&gt; png |
| 2 | [`Poster`](../Scripts/Master-GameList.ps1#L41) | 41-45 | `id`, `root` |  |
| 3 | [`SteamPoster`](../Scripts/Master-GameList.ps1#L48) | 48-67 | `appid` | Steam artwork: copy the header Steam already cached on this PC into posters\_auto (works offline on clients), else ask the Steam store for the header URL (ne... |
| 4 | [`Add-Game`](../Scripts/Master-GameList.ps1#L68) | 68-70 | `id`, `title`, `cat`, `cmd`, `cwd`, `img`, `platform` |  |
| 5 | [`Expand-Path`](../Scripts/Master-GameList.ps1#L149) | 149-149 | `p` | ---------- extra games + overrides (Settings\extra-games.json) ---------- |
| 6 | [`Slug`](../Scripts/Master-GameList.ps1#L179) | 179-179 | `s` |  |
| 7 | [`ExeScore`](../Scripts/Master-GameList.ps1#L181) | 181-186 | `e`, `folderName`, `folderPath` | start-exe score: launcher / portable wrapper &gt; start / play; + name like the folder; - each subfolder level |
| 8 | [`Find-StartExe`](../Scripts/Master-GameList.ps1#L187) | 187-191 | `folderPath`, `name` |  |
| 9 | [`Test-Covered`](../Scripts/Master-GameList.ps1#L200) | 200-200 | `fp` | a folder already listed: a listed path is the folder, inside it, or the folder is inside a listed game |
| 10 | [`Add-AutoGame`](../Scripts/Master-GameList.ps1#L201) | 201-210 | `fp`, `idName`, `title`, `cat`, `platform`, `exe` |  |

<a id="system-scripts-master-move-launcher-ps1"></a>
### System/Scripts/Master-Move-Launcher.ps1

345 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Launcher`, `OldPath`, `NewPath`, `DryRun` · [เปิดไฟล์](../Scripts/Master-Move-Launcher.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Say`](../Scripts/Master-Move-Launcher.ps1#L23) | 23-23 | `m` |  |
| 2 | [`RegVal`](../Scripts/Master-Move-Launcher.ps1#L24) | 24-24 | `k`, `n` |  |
| 3 | [`Clean`](../Scripts/Master-Move-Launcher.ps1#L25) | 25-25 | `p` |  |
| 4 | [`Repoint`](../Scripts/Master-Move-Launcher.ps1#L155) | 155-158 | `v` |  |
| 5 | [`Has`](../Scripts/Master-Move-Launcher.ps1#L159) | 159-159 | `v` |  |
| 6 | [`Stop-Old`](../Scripts/Master-Move-Launcher.ps1#L240) | 240-243 | - | 2) stop - several rounds: a crash reporter / helper can start while the launcher is being closed |
| 7 | [`Get-Holders`](../Scripts/Master-Move-Launcher.ps1#L245) | 245-248 | - | processes that have a file of the old folder loaded (they block the rename although they run from elsewhere) |

<a id="system-scripts-master-oslinklogins-ps1"></a>
### System/Scripts/Master-OslinkLogins.ps1

187 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Install`, `Uninstall`, `Status`, `Port`, `RecordDir`, `AllowLoopback`, `MaxRequests`, `ShopAccounts` · [เปิดไฟล์](../Scripts/Master-OslinkLogins.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-ShopAccountsDir`](../Scripts/Master-OslinkLogins.ps1#L30) | 30-39 | - | the accounts signed in on the master's OSLink = the shop's account(s): &lt;OSLink&gt;\userData\accounts\&lt;uid&gt;\userinfo.config |
| 2 | [`Get-ShopUids`](../Scripts/Master-OslinkLogins.ps1#L40) | 40-44 | - |  |
| 3 | [`Log`](../Scripts/Master-OslinkLogins.ps1#L88) | 88-93 | `s` |  |
| 4 | [`Test-LanIp`](../Scripts/Master-OslinkLogins.ps1#L99) | 99-105 | `ip` |  |
| 5 | [`Test-Record`](../Scripts/Master-OslinkLogins.ps1#L106) | 106-121 | `r` |  |
| 6 | [`Send`](../Scripts/Master-OslinkLogins.ps1#L122) | 122-127 | `stream`, `code`, `body` |  |
| 7 | [`Handle`](../Scripts/Master-OslinkLogins.ps1#L128) | 128-173 | `c` |  |

<a id="system-scripts-master-setup-ps1"></a>
### System/Scripts/Master-Setup.ps1

100 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun` · [เปิดไฟล์](../Scripts/Master-Setup.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Ask`](../Scripts/Master-Setup.ps1#L9) | 9-9 | `q` |  |
| 2 | [`Head`](../Scripts/Master-Setup.ps1#L10) | 10-10 | `t` |  |

<a id="system-scripts-master-snapshot-battlenet-ps1"></a>
### System/Scripts/Master-Snapshot-BattleNet.ps1

18 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Master-Snapshot-BattleNet.ps1)

<a id="system-scripts-master-snapshot-ea-ps1"></a>
### System/Scripts/Master-Snapshot-EA.ps1

70 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Master-Snapshot-EA.ps1)

<a id="system-scripts-master-snapshot-epic-ps1"></a>
### System/Scripts/Master-Snapshot-Epic.ps1

27 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Master-Snapshot-Epic.ps1)

<a id="system-scripts-master-snapshot-riot-ps1"></a>
### System/Scripts/Master-Snapshot-Riot.ps1

50 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `SharedDrives` · [เปิดไฟล์](../Scripts/Master-Snapshot-Riot.ps1)

<a id="system-scripts-master-steam-library-ps1"></a>
### System/Scripts/Master-Steam-Library.ps1

80 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `Target` · [เปิดไฟล์](../Scripts/Master-Steam-Library.ps1)

<a id="system-scripts-master-steamqueue-ps1"></a>
### System/Scripts/Master-SteamQueue.ps1

371 บรรทัด · 11 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `TestLibrary`, `Anonymous`, `IdleSeconds` · [เปิดไฟล์](../Scripts/Master-SteamQueue.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Master-SteamQueue.ps1#L29) | 29-29 | `m` |  |
| 2 | [`Set-SqState`](../Scripts/Master-SteamQueue.ps1#L70) | 70-73 | `J`, `State`, `Message`, `Progress` |  |
| 3 | [`Stop-SqJob`](../Scripts/Master-SteamQueue.ps1#L74) | 74-74 | `J`, `State`, `Message` |  |
| 4 | [`Get-SqAppInfo`](../Scripts/Master-SteamQueue.ps1#L76) | 76-82 | `App` |  |
| 5 | [`Get-SqDepots`](../Scripts/Master-SteamQueue.ps1#L84) | 84-101 | `Info` | the depots DepotDownloader takes by default on this PC: Windows, 64-bit or any, English or no language, no DLC / low violence |
| 6 | [`Get-SqLibraries`](../Scripts/Master-SteamQueue.ps1#L103) | 103-114 | - | Steam libraries: Get-SteamLibraries + the Steam folder from HKLM (this worker runs as SYSTEM: no HKCU Steam path) |
| 7 | [`Get-FreeBytes`](../Scripts/Master-SteamQueue.ps1#L115) | 115-115 | `Path` |  |
| 8 | [`Get-DirBytes`](../Scripts/Master-SteamQueue.ps1#L116) | 116-116 | `Path` |  |
| 9 | [`Get-QrRows`](../Scripts/Master-SteamQueue.ps1#L117) | 117-131 | `Lines` |  |
| 10 | [`Write-SqAppManifest`](../Scripts/Master-SteamQueue.ps1#L132) | 132-157 | `Lib`, `J`, `Info`, `Depots`, `Man`, `Sizes` |  |
| 11 | [`Invoke-SqJob`](../Scripts/Master-SteamQueue.ps1#L159) | 159-339 | `J` |  |

<a id="system-scripts-master-update-ps1"></a>
### System/Scripts/Master-Update.ps1

42 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `GameListOut` · [เปิดไฟล์](../Scripts/Master-Update.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Step`](../Scripts/Master-Update.ps1#L24) | 24-29 | `name`, `file`, `extra` |  |

<a id="system-scripts-master-watch-ps1"></a>
### System/Scripts/Master-Watch.ps1

198 บรรทัด · 6 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Register`, `Unregister`, `From`, `CheckSeconds`, `SettleMinutes`, `EveryMinutes` · [เปิดไฟล์](../Scripts/Master-Watch.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Master-Watch.ps1#L25) | 25-28 | `m` |  |
| 2 | [`Get-Apps`](../Scripts/Master-Watch.ps1#L30) | 30-35 | - |  |
| 3 | [`Test-Running`](../Scripts/Master-Watch.ps1#L36) | 36-36 | `app` |  |
| 4 | [`Start-App`](../Scripts/Master-Watch.ps1#L37) | 37-41 | `app` |  |
| 5 | [`Get-State`](../Scripts/Master-Watch.ps1#L102) | 102-120 | - | what Master-Update copies for clients (Riot / Epic / EA), which Steam games are installed, and the game folders / installed-apps entries (a game added by han... |
| 6 | [`Get-Busy`](../Scripts/Master-Watch.ps1#L122) | 122-129 | - |  |

<a id="system-scripts-steamqueue-lib-ps1"></a>
### System/Scripts/SteamQueue-Lib.ps1

116 บรรทัด · 9 ฟังก์ชัน · [เปิดไฟล์](../Scripts/SteamQueue-Lib.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-SqSettings`](../Scripts/SteamQueue-Lib.ps1#L15) | 15-25 | - |  |
| 2 | [`ConvertFrom-SqAppText`](../Scripts/SteamQueue-Lib.ps1#L28) | 28-35 | `Text` | "570", "https://store.steampowered.com/app/570/Dota_2/", "steam://rungameid/570" -&gt; 570 (0 = not understood) |
| 3 | [`Read-SqJob`](../Scripts/SteamQueue-Lib.ps1#L37) | 37-42 | `Path` |  |
| 4 | [`Write-SqJob`](../Scripts/SteamQueue-Lib.ps1#L43) | 43-50 | `Job` |  |
| 5 | [`Get-SqJobs`](../Scripts/SteamQueue-Lib.ps1#L51) | 51-54 | - |  |
| 6 | [`Test-SqCancel`](../Scripts/SteamQueue-Lib.ps1#L55) | 55-55 | `Job` |  |
| 7 | [`Get-SqView`](../Scripts/SteamQueue-Lib.ps1#L58) | 58-65 | `Job`, `All` | what a client may see of a job (no paths of the master, no log) |
| 8 | [`Start-SqWorker`](../Scripts/SteamQueue-Lib.ps1#L67) | 67-72 | - |  |
| 9 | [`Invoke-SqApi`](../Scripts/SteamQueue-Lib.ps1#L75) | 75-116 | `Method`, `Path`, `Body`, `Ip` | the listener's /steam/* calls -&gt; @{ code; body (hashtable -&gt; JSON) } |

## เครื่องลูก: การบูตและไดรเวอร์

คำอธิบายเต็ม: [04-CLIENT-BOOT.md](04-CLIENT-BOOT.md)

<a id="system-client-boot-ps1"></a>
### System/Client/Boot.ps1

4 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../Client/Boot.ps1)

<a id="system-scripts-client-desktopclean-ps1"></a>
### System/Scripts/Client-DesktopClean.ps1

120 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestDir` · [เปิดไฟล์](../Scripts/Client-DesktopClean.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-OwnIcon`](../Scripts/Client-DesktopClean.ps1#L22) | 22-25 | `f` |  |
| 2 | [`Test-MenuShortcut`](../Scripts/Client-DesktopClean.ps1#L27) | 27-32 | `f` | the game menu's own shortcut (Client-Menu.ps1): its names now and before, or anything that starts the menu |

<a id="system-scripts-client-firewall-ps1"></a>
### System/Scripts/Client-Firewall.ps1

27 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `From` · [เปิดไฟล์](../Scripts/Client-Firewall.ps1)

<a id="system-scripts-client-install-ps1"></a>
### System/Scripts/Client-Install.ps1

574 บรรทัด · 3 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Boot` · [เปิดไฟล์](../Scripts/Client-Install.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Run-Script`](../Scripts/Client-Install.ps1#L47) | 47-55 | `file`, `extra` |  |
| 2 | [`Step`](../Scripts/Client-Install.ps1#L57) | 57-64 | `name`, `body` |  |
| 3 | [`Stop-WoMicDriver`](../Scripts/Client-Install.ps1#L68) | 68-83 | - | 19 Nov 2026 (Apex): WO Mic's driver WOVAD off for this boot. Turning its device off was not enough (KORI23 15:03: "WOVAD Running" - Windows Audio still held ... |

<a id="system-scripts-client-menu-ps1"></a>
### System/Scripts/Client-Menu.ps1

42 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Uninstall`, `NoStart` · [เปิดไฟล์](../Scripts/Client-Menu.ps1)

<a id="system-scripts-client-mic-ps1"></a>
### System/Scripts/Client-Mic.ps1

417 บรรทัด · 18 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `WatchDefaults`, `WatchMinutes` · [เปิดไฟล์](../Scripts/Client-Mic.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-X64Exe`](../Scripts/Client-Mic.ps1#L33) | 33-33 | `p` | x64 program? (PE machine 0x8664) |
| 2 | [`Get-MediaDevice`](../Scripts/Client-Mic.ps1#L40) | 40-44 | `Pattern` |  |
| 3 | [`Get-WorkingDevice`](../Scripts/Client-Mic.ps1#L47) | 47-49 | `Pattern` | 20 Nov 2026: only a device that WORKS counts - Windows can keep a root device with no driver (empty class and name, only the HardwareID; the master has one f... |
| 4 | [`Find-WoMicClient`](../Scripts/Client-Mic.ps1#L50) | 50-62 | - |  |
| 5 | [`Invoke-Setup`](../Scripts/Client-Mic.ps1#L65) | 65-73 | `Exe`, `Arguments`, `Seconds` | runs a setup hidden; stops it (and what it started) when it is still busy after $Seconds - a setup waiting on a window nobody can see (SYSTEM at boot) must n... |
| 6 | [`Get-EndpointName`](../Scripts/Client-Mic.ps1#L138) | 138-142 | `Id` |  |
| 7 | [`Get-AudioDefaults`](../Scripts/Client-Mic.ps1#L143) | 143-148 | - |  |
| 8 | [`Show-AudioDefaults`](../Scripts/Client-Mic.ps1#L149) | 149-152 | `When` |  |
| 9 | [`Get-RealEndpoint`](../Scripts/Client-Mic.ps1#L156) | 156-160 | `Flow` | the PC's own active speaker (flow 0) / mic (flow 1): not ours, not another program's virtual device |
| 10 | [`WLog`](../Scripts/Client-Mic.ps1#L164) | 164-164 | `s` |  |
| 11 | [`Get-Devcon`](../Scripts/Client-Mic.ps1#L193) | 193-200 | - | x64 client) - then OSLink's x64 devcon is used (game disk, signed by its maker, the same one Client-OslinkDrivers uses) 19 Nov 2026: "UnknownError" = its roo... |
| 12 | [`Test-WoMicPackage`](../Scripts/Client-Mic.ps1#L204) | 204-216 | - | WO Mic's x64 driver for the direct install (Tools\WOMic\driver): 2.1.0.0 out of WOMicClientSetup6.4.exe, signed by Microsoft (Windows Hardware Compatibility ... |
| 13 | [`Format-DevconExit`](../Scripts/Client-Mic.ps1#L218) | 218-218 | `r` | devcon exit codes: 0 done, 1 done but Windows wants a restart, 2 failed |
| 14 | [`Show-Sound`](../Scripts/Client-Mic.ps1#L223) | 223-226 | `When` | Owner, 20 Nov 2026: only the sound / mic drivers of OUR menu system (WO Mic, VB-CABLE) are handled here - never the PC's own sound card, Windows' sound servi... |
| 15 | [`Get-VbBroken`](../Scripts/Client-Mic.ps1#L302) | 302-302 | - | root device(s) with VB-CABLE's HardwareID but no working driver (the setup / an old install left them) |
| 16 | [`Restore-AudioDefaults`](../Scripts/Client-Mic.ps1#L304) | 304-318 | `before` | Windows may switch the default to the new CABLE device a moment after it appears: watch ~20 s, put the old one back |
| 17 | [`Get-VbEndpoints`](../Scripts/Client-Mic.ps1#L382) | 382-393 | - | on "CABLE Output". A VB-CABLE speaker / mic that was disabled (in the image; several PCs show one renamed "NOT USE") is not seen at all - so they are enabled... |
| 18 | [`Format-EpState`](../Scripts/Client-Mic.ps1#L394) | 394-394 | `s` |  |

<a id="system-scripts-client-parsec-ps1"></a>
### System/Scripts/Client-Parsec.ps1

62 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly` · [เปิดไฟล์](../Scripts/Client-Parsec.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Invoke-Setup`](../Scripts/Client-Parsec.ps1#L23) | 23-31 | `Exe`, `Arguments`, `Seconds` | runs a setup hidden; stops it (and what it started) when it is still busy after $Seconds - a setup waiting on a window nobody can see (SYSTEM at boot) must n... |
| 2 | [`Get-ParsecState`](../Scripts/Client-Parsec.ps1#L32) | 32-40 | - |  |

<a id="system-scripts-client-popupguard-ps1"></a>
### System/Scripts/Client-PopupGuard.ps1

45 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `EverySec`, `Once` · [เปิดไฟล์](../Scripts/Client-PopupGuard.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Look`](../Scripts/Client-PopupGuard.ps1#L39) | 39-39 | - |  |

<a id="system-scripts-client-runtimes-ps1"></a>
### System/Scripts/Client-Runtimes.ps1

145 บรรทัด · 4 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestKey` · [เปิดไฟล์](../Scripts/Client-Runtimes.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-Off`](../Scripts/Client-Runtimes.ps1#L20) | 20-20 | `Name` |  |
| 2 | [`Open-Key`](../Scripts/Client-Runtimes.ps1#L25) | 25-30 | `Sub`, `Write` | ---------- registry roots (machine, or HKCU\&lt;TestKey&gt; for tests) ---------- |
| 3 | [`Add-MachinePath`](../Scripts/Client-Runtimes.ps1#L31) | 31-50 | `Dirs` |  |
| 4 | [`Get-WebView2Version`](../Scripts/Client-Runtimes.ps1#L53) | 53-60 | - | ---------- 1 WebView2 ---------- |

<a id="system-scripts-client-sunshine0j-ps1"></a>
### System/Scripts/Client-Sunshine0J.ps1

96 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Stop`, `Check`, `AutoStart`, `Service` · [เปิดไฟล์](../Scripts/Client-Sunshine0J.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Client-Sunshine0J.ps1#L21) | 21-21 | `m` |  |

<a id="system-scripts-client-vdd-ps1"></a>
### System/Scripts/Client-Vdd.ps1

45 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `AssumeNone` · [เปิดไฟล์](../Scripts/Client-Vdd.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-Vdd`](../Scripts/Client-Vdd.ps1#L20) | 20-23 | - |  |
| 2 | [`Get-VddState`](../Scripts/Client-Vdd.ps1#L24) | 24-28 | `d` |  |

<a id="system-scripts-client-winrar-ps1"></a>
### System/Scripts/Client-WinRAR.ps1

55 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly` · [เปิดไฟล์](../Scripts/Client-WinRAR.ps1)

## เครื่องลูก: เกม ตัวเปิดเกม บัญชี

คำอธิบายเต็ม: [05-CLIENT-GAMES.md](05-CLIENT-GAMES.md)

<a id="system-scripts-client-clearlogins-ps1"></a>
### System/Scripts/Client-ClearLogins.ps1

234 บรรทัด · 8 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `Boot`, `TestDir` · [เปิดไฟล์](../Scripts/Client-ClearLogins.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Say`](../Scripts/Client-ClearLogins.ps1#L32) | 32-32 | `s`, `c` |  |
| 2 | [`Test-Under`](../Scripts/Client-ClearLogins.ps1#L75) | 75-78 | `path`, `base` | ---------- helpers ---------- |
| 3 | [`Remove-One`](../Scripts/Client-ClearLogins.ps1#L80) | 80-102 | `path`, `what` | delete one file / folder (folder: links inside are removed, never followed) |
| 4 | [`Remove-Rel`](../Scripts/Client-ClearLogins.ps1#L104) | 104-117 | `base`, `rel`, `what` | base folder + relative path with a wildcard in any part (e.g. HYP\*\fedata) -&gt; every match under base |
| 5 | [`Get-Profiles`](../Scripts/Client-ClearLogins.ps1#L119) | 119-132 | - | user profiles (ProfileList S-1-5-21-*) + Default |
| 6 | [`Get-UserFolder`](../Scripts/Client-ClearLogins.ps1#L134) | 134-146 | `prof`, `name`, `fallback` | Documents / Local / Roaming of a profile: the user's own folder setting when the user is logged on, else the usual place |
| 7 | [`Clear-UserRegistry`](../Scripts/Client-ClearLogins.ps1#L148) | 148-169 | `hk`, `who` | registry of one user (an open RegistryKey = the user's HKCU): saved sign-in values |
| 8 | [`Clear-BnetConfig`](../Scripts/Client-ClearLogins.ps1#L171) | 171-180 | `file`, `who` | Battle.net.config: empty SavedAccountNames (the e-mails offered at sign-in), the rest of the settings stay |

<a id="system-scripts-client-ea-anticheat-ps1"></a>
### System/Scripts/Client-EA-AntiCheat.ps1

71 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun` · [เปิดไฟล์](../Scripts/Client-EA-AntiCheat.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-Ver`](../Scripts/Client-EA-AntiCheat.ps1#L45) | 45-45 | `p` |  |
| 2 | [`Get-SvcVer`](../Scripts/Client-EA-AntiCheat.ps1#L56) | 56-56 | - | version of the EA AntiCheat service on this PC now (the image may carry an older one than the game disk needs) |

<a id="system-scripts-client-ea-ps1"></a>
### System/Scripts/Client-EA.ps1

101 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Autostart`, `Uninstall`, `DryRun` · [เปิดไฟล์](../Scripts/Client-EA.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Say`](../Scripts/Client-EA.ps1#L19) | 19-19 | `m` |  |

<a id="system-scripts-client-eac-ps1"></a>
### System/Scripts/Client-EAC.ps1

81 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `Snapshot` · [เปิดไฟล์](../Scripts/Client-EAC.ps1)

<a id="system-scripts-client-epic-start-ps1"></a>
### System/Scripts/Client-Epic-Start.ps1

27 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `App` · [เปิดไฟล์](../Scripts/Client-Epic-Start.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Client-Epic-Start.ps1#L11) | 11-11 | `m` |  |

<a id="system-scripts-client-fivemshare-ps1"></a>
### System/Scripts/Client-FiveMShare.ps1

185 บรรทัด · 12 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CacheDir`, `Master`, `Once`, `Since`, `Hours`, `Base`, `Running`, `AheadAge`, `AheadMBps` · [เปิดไฟล์](../Scripts/Client-FiveMShare.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Send-Log`](../Scripts/Client-FiveMShare.ps1#L23) | 23-29 | `m` |  |
| 2 | [`Log`](../Scripts/Client-FiveMShare.ps1#L30) | 30-30 | `m` |  |
| 3 | [`Note`](../Scripts/Client-FiveMShare.ps1#L33) | 33-36 | `m` |  |
| 4 | [`Get-Fingerprint`](../Scripts/Client-FiveMShare.ps1#L48) | 48-53 | `dir` |  |
| 5 | [`Test-FiveMRunning`](../Scripts/Client-FiveMShare.ps1#L54) | 54-58 | - |  |
| 6 | [`Get-WebReason`](../Scripts/Client-FiveMShare.ps1#L60) | 60-63 | `e` | the master's reason when it refused (its JSON {reason}), else the error itself |
| 7 | [`Invoke-Json`](../Scripts/Client-FiveMShare.ps1#L64) | 64-72 | `method`, `path`, `obj` |  |
| 8 | [`Send-File`](../Scripts/Client-FiveMShare.ps1#L74) | 74-95 | `path`, `url`, `MBps` | one file to the master; -MBps &gt; 0: no faster than that (FiveM is running here). Returns the bytes sent. |
| 9 | [`Get-NewFiles`](../Scripts/Client-FiveMShare.ps1#L106) | 106-106 | - |  |
| 10 | [`Invoke-Offer`](../Scripts/Client-FiveMShare.ps1#L107) | 107-122 | `pre`, `files`, `dbFiles` |  |
| 11 | [`Send-Ahead`](../Scripts/Client-FiveMShare.ps1#L124) | 124-141 | - | while FiveM runs: send the finished new files ahead |
| 12 | [`Send-Final`](../Scripts/Client-FiveMShare.ps1#L143) | 143-171 | - | FiveM closed: the rest + the index, then the master takes it |

<a id="system-scripts-client-gamestart-ps1"></a>
### System/Scripts/Client-GameStart.ps1

134 บรรทัด · 3 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Id`, `Check` · [เปิดไฟล์](../Scripts/Client-GameStart.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Note`](../Scripts/Client-GameStart.ps1#L15) | 15-18 | `s` |  |
| 2 | [`Get-Ver`](../Scripts/Client-GameStart.ps1#L19) | 19-19 | `p` |  |
| 3 | [`Send-Master`](../Scripts/Client-GameStart.ps1#L107) | 107-112 | `result` | ---- tell the master (short line, never waits long) ----------------------------------------------------------------------- |

<a id="system-scripts-client-gtasettings-ps1"></a>
### System/Scripts/Client-GtaSettings.ps1

112 บรรทัด · 5 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestDir` · [เปิดไฟล์](../Scripts/Client-GtaSettings.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-GpuName`](../Scripts/Client-GtaSettings.ps1#L27) | 27-35 | - |  |
| 2 | [`Get-ScreenMode`](../Scripts/Client-GtaSettings.ps1#L38) | 38-43 | - | this PC's screen (17 Nov, owner's choice: the real screen, not the shop file's 2560x1440 180 Hz): the mode a card shows now; a real card first, else a virtua... |
| 3 | [`Get-Profiles`](../Scripts/Client-GtaSettings.ps1#L59) | 59-72 | - | user profiles (ProfileList) + Default |
| 4 | [`Get-UserFolder`](../Scripts/Client-GtaSettings.ps1#L74) | 74-86 | `prof`, `name`, `fallback` | Documents / Roaming of a profile: the user's own folder setting when the user is logged on (hive loaded), else the usual place |
| 5 | [`Write-IfChanged`](../Scripts/Client-GtaSettings.ps1#L87) | 87-97 | `file`, `content` |  |

<a id="system-scripts-client-newthings-ps1"></a>
### System/Scripts/Client-NEWTHINGS.ps1

73 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Path`, `FixThaiText` · [เปิดไฟล์](../Scripts/Client-NEWTHINGS.ps1)

<a id="system-scripts-client-oslinkdrivers-ps1"></a>
### System/Scripts/Client-OslinkDrivers.ps1

204 บรรทัด · 5 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestDir` · [เปิดไฟล์](../Scripts/Client-OslinkDrivers.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-FakeState`](../Scripts/Client-OslinkDrivers.ps1#L59) | 59-59 | `d` |  |
| 2 | [`Test-Loaded`](../Scripts/Client-OslinkDrivers.ps1#L62) | 62-67 | `d` | loaded = Windows runs the driver for at least one device (volatile Services\&lt;driver&gt;\Enum, written when it loads it) |
| 3 | [`Find-OslinkBin`](../Scripts/Client-OslinkDrivers.ps1#L74) | 74-86 | - | ---------- OSLink's bin folder ---------- |
| 4 | [`Test-PinnedSignature`](../Scripts/Client-OslinkDrivers.ps1#L91) | 91-102 | `File`, `Pins` | '' = valid signature made with a pinned certificate; else why not |
| 5 | [`Invoke-Tool`](../Scripts/Client-OslinkDrivers.ps1#L155) | 155-168 | `Exe`, `Arguments`, `Seconds` | ---------- install (hidden, at most 90 s each) ---------- |

<a id="system-scripts-client-oslinkhelper-ps1"></a>
### System/Scripts/Client-OslinkHelper.ps1

125 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `TestDir`, `Master`, `Once`, `Minutes` · [เปิดไฟล์](../Scripts/Client-OslinkHelper.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Client-OslinkHelper.ps1#L20) | 20-20 | `s` |  |
| 2 | [`Find-OslinkRoot`](../Scripts/Client-OslinkHelper.ps1#L27) | 27-35 | - |  |
| 3 | [`Get-Rcmac`](../Scripts/Client-OslinkHelper.ps1#L41) | 41-46 | `which` | ---------- this PC's sign-in as the master keeps it ---------- |
| 4 | [`Get-Signin`](../Scripts/Client-OslinkHelper.ps1#L47) | 47-57 | - |  |
| 5 | [`Get-Hash`](../Scripts/Client-OslinkHelper.ps1#L59) | 59-63 | `s` | same fingerprint as Client-OslinkLogin.ps1 writes into the state file ("baseline" = what it put back from the master) |
| 6 | [`Send-Signin`](../Scripts/Client-OslinkHelper.ps1#L64) | 64-70 | `s` |  |
| 7 | [`Try-AnswerNewPc`](../Scripts/Client-OslinkHelper.ps1#L76) | 76-97 | - |  |

<a id="system-scripts-client-oslinklogin-ps1"></a>
### System/Scripts/Client-OslinkLogin.ps1

202 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestDir`, `Master` · [เปิดไฟล์](../Scripts/Client-OslinkLogin.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Find-OslinkRoot`](../Scripts/Client-OslinkLogin.ps1#L29) | 29-37 | - |  |
| 2 | [`Get-Record`](../Scripts/Client-OslinkLogin.ps1#L45) | 45-59 | - | ---------- ask the master for this PC's record ---------- |
| 3 | [`Get-RcmacKeys`](../Scripts/Client-OslinkLogin.ps1#L77) | 77-102 | - |  |
| 4 | [`Get-RcmacNow`](../Scripts/Client-OslinkLogin.ps1#L105) | 105-110 | `which` | rcmac as the logon helper will read it back (machine = HKLM; user = the logged-on user's HKCU - unknown at boot as SYSTEM, '' then, which only means the help... |
| 5 | [`Close-Hives`](../Scripts/Client-OslinkLogin.ps1#L111) | 111-111 | - |  |
| 6 | [`Read-Settings`](../Scripts/Client-OslinkLogin.ps1#L113) | 113-119 | - |  |
| 7 | [`Write-Settings`](../Scripts/Client-OslinkLogin.ps1#L120) | 120-120 | `map` |  |

<a id="system-scripts-client-oslinkreport-ps1"></a>
### System/Scripts/Client-OslinkReport.ps1

305 บรรทัด · 6 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Phase`, `DelaySeconds`, `Print`, `WaitSteamMinutes`, `WaitFiveMMinutes`, `WaitRiotMinutes`, `WaitApexMinutes` · [เปิดไฟล์](../Scripts/Client-OslinkReport.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-SteamDirs`](../Scripts/Client-OslinkReport.ps1#L27) | 27-37 | - |  |
| 2 | [`Get-SteamLogSinceBoot`](../Scripts/Client-OslinkReport.ps1#L38) | 38-40 | `dir`, `since` |  |
| 3 | [`Get-FiveMLogs`](../Scripts/Client-OslinkReport.ps1#L41) | 41-45 | `since` |  |
| 4 | [`Get-RiotLogs`](../Scripts/Client-OslinkReport.ps1#L46) | 46-48 | `since` |  |
| 5 | [`Add`](../Scripts/Client-OslinkReport.ps1#L94) | 94-94 | `s` |  |
| 6 | [`Sec`](../Scripts/Client-OslinkReport.ps1#L95) | 95-95 | `s` |  |

<a id="system-scripts-client-oslinkreset-ps1"></a>
### System/Scripts/Client-OslinkReset.ps1

154 บรรทัด · 5 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `CheckOnly`, `TestDir` · [เปิดไฟล์](../Scripts/Client-OslinkReset.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Find-OslinkRoot`](../Scripts/Client-OslinkReset.ps1#L29) | 29-37 | - | the OSLink folder: from the service's program path, else &lt;shared drive&gt;:\LDPlayer\OSLink |
| 2 | [`Get-Profiles`](../Scripts/Client-OslinkReset.ps1#L57) | 57-67 | - | ---------- the device id (rcmac) in the registry ---------- |
| 3 | [`Get-RcmacPlaces`](../Scripts/Client-OslinkReset.ps1#L70) | 70-90 | `loadHives` |  |
| 4 | [`Close-Hives`](../Scripts/Client-OslinkReset.ps1#L91) | 91-91 | - |  |
| 5 | [`Use-Rcmac`](../Scripts/Client-OslinkReset.ps1#L93) | 93-106 | `delete` | who has a rcmac (and delete it when $delete) |

<a id="system-scripts-client-riot-start-ps1"></a>
### System/Scripts/Client-Riot-Start.ps1

84 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Product`, `NoLaunch`, `SkipRegistry`, `ProgramDataRoot` · [เปิดไฟล์](../Scripts/Client-Riot-Start.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Client-Riot-Start.ps1#L19) | 19-19 | `m` |  |
| 2 | [`Repair-Link`](../Scripts/Client-Riot-Start.ps1#L30) | 30-38 | `path` | 0) old images may have these folders as links into the removed AutoSync project; a link whose target is gone makes every read/write fail, so replace it with ... |

<a id="system-scripts-client-roblox-ps1"></a>
### System/Scripts/Client-Roblox.ps1

51 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Mode`, `DryRun` · [เปิดไฟล์](../Scripts/Client-Roblox.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Log`](../Scripts/Client-Roblox.ps1#L15) | 15-18 | `m` |  |

<a id="system-scripts-client-steam-firstrun-ps1"></a>
### System/Scripts/Client-Steam-FirstRun.ps1

160 บรรทัด · 6 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `SkipFailed` · [เปิดไฟล์](../Scripts/Client-Steam-FirstRun.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Read-Vdf`](../Scripts/Client-Steam-FirstRun.ps1#L26) | 26-29 | `text` | --- tiny VDF reader: a node is a list of {K, V}; V is a string or a nested list |
| 2 | [`Read-Node`](../Scripts/Client-Steam-FirstRun.ps1#L30) | 30-43 | - |  |
| 3 | [`Unescape`](../Scripts/Client-Steam-FirstRun.ps1#L44) | 44-44 | `s` | VDF: \\ -&gt; \ , \" -&gt; " |
| 4 | [`Get-V`](../Scripts/Client-Steam-FirstRun.ps1#L45) | 45-45 | `node`, `key` |  |
| 5 | [`Open-Key`](../Scripts/Client-Steam-FirstRun.ps1#L48) | 48-55 | `path`, `create` | Steam is 32-bit: plain HKEY_LOCAL_MACHINE means the 32-bit view; scripts may also say ..._WOW64_32 / ..._WOW64_64 |
| 6 | [`Expand`](../Scripts/Client-Steam-FirstRun.ps1#L56) | 56-56 | `s`, `dir` |  |

<a id="system-scripts-client-steamverify-ps1"></a>
### System/Scripts/Client-SteamVerify.ps1

134 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `AppId`, `Report`, `Quick`, `DelaySeconds`, `MaxList` · [เปิดไฟล์](../Scripts/Client-SteamVerify.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Say`](../Scripts/Client-SteamVerify.ps1#L55) | 55-55 | `s` |  |

## โปรแกรมเมนูเกม

คำอธิบายเต็ม: [06-MENU.md](06-MENU.md)

<a id="menu-source-electron-main-js"></a>
### Menu/source/electron/main.js

1090 บรรทัด · 71 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/electron/main.js)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`gcafeRoot`](../../Menu/source/electron/main.js#L42) | 42 | - | &lt;root&gt;\config.json brand / station / API settings &lt;root&gt;\data\games.json offline game catalog (tools\Build-GameList) &lt;root&gt;\source\electron... |
| 2 | [`readJson`](../../Menu/source/electron/main.js#L48) | 48 | `file`, `fallback` |  |
| 3 | [`localImageUrl`](../../Menu/source/electron/main.js#L58) | 58 | `p` | a local picture (absolute, or relative to the GCafe folder) is served through /poster/ ?v=&lt;file time&gt;: a replaced picture (new logo, banner) gets a new... |
| 4 | [`buildStamp`](../../Menu/source/electron/main.js#L67) | 67 | - | build time of this menu (out\index.html), shown small on the lock screen so each PC's build can be checked |
| 5 | [`p2`](../../Menu/source/electron/main.js#L72) | 72 | `n` |  |
| 6 | [`loadUi`](../../Menu/source/electron/main.js#L82) | 82 | `cfg` | config.json "ui" (all optional): font, hudSize/menuSize/lockSize (% zoom 80-130), hudBanner ('' = card without picture, 'off' = hidden, or a picture path), h... |
| 7 | [`pct`](../../Menu/source/electron/main.js#L85) | 85 | `v` |  |
| 8 | [`text`](../../Menu/source/electron/main.js#L86) | 86 | `v`, `max` |  |
| 9 | [`loadConfig`](../../Menu/source/electron/main.js#L110) | 110 | - |  |
| 10 | [`iconFile`](../../Menu/source/electron/main.js#L130) | 130 | `id` | program icons the game-list script already pulled out of each launcher / game (data\posters\_auto\icons\&lt;id&gt;.png): the game menu shows them on the cate... |
| 11 | [`launcherIcons`](../../Menu/source/electron/main.js#L133) | 133 | - | platform / category name → icon url (only the ones that exist on this PC) |
| 12 | [`withIcons`](../../Menu/source/electron/main.js#L143) | 143 | `list` | + "icon" on games that have their own extracted icon |
| 13 | [`loadGames`](../../Menu/source/electron/main.js#L154) | 154 | - |  |
| 14 | [`readAgent`](../../Menu/source/electron/main.js#L181) | 181 | - |  |
| 15 | [`broadcast`](../../Menu/source/electron/main.js#L206) | 206 | - |  |
| 16 | [`writeAlive`](../../Menu/source/electron/main.js#L212) | 212 | - |  |
| 17 | [`showLock`](../../Menu/source/electron/main.js#L220) | 220 | - | one full-screen lock window per display; the primary one shows the login page |
| 18 | [`keepLockOnTop`](../../Menu/source/electron/main.js#L253) | 253 | `w`, `force` |  |
| 19 | [`hideLock`](../../Menu/source/electron/main.js#L266) | 266 | - |  |
| 20 | [`agentTick`](../../Menu/source/electron/main.js#L273) | 273 | - | every second: follow the agent's state (rental started/ended) and keep the lock screen in sync |
| 21 | [`apiCall`](../../Menu/source/electron/main.js#L286) | 286 | `method`, `p`, `body` |  |
| 22 | [`launchGame`](../../Menu/source/electron/main.js#L309) | 309 | `game` |  |
| 23 | [`splitCmd`](../../Menu/source/electron/main.js#L333) | 333 | `cmd` | The location is worked out here from data\games.json by game id only — a page can never ask to open any other path. exe games = the exe (Explorer opens its f... |
| 24 | [`steamAppDir`](../../Menu/source/electron/main.js#L341) | 341 | `steamExe`, `appId` |  |
| 25 | [`riotProductDir`](../../Menu/source/electron/main.js#L361) | 361 | `product` |  |
| 26 | [`gameLocation`](../../Menu/source/electron/main.js#L374) | 374 | `game` |  |
| 27 | [`gameById`](../../Menu/source/electron/main.js#L406) | 406 | `id` |  |
| 28 | [`getAppIcon`](../../Menu/source/electron/main.js#L411) | 411 | - | ── Window / Tray Icon: &lt;GCafe&gt;\data\brand\app.ico (tools\_system\Make-Brand.ps1), else the built-in one ── |
| 29 | [`startServer`](../../Menu/source/electron/main.js#L439) | 439 | `outDir`, `callback` |  |
| 30 | [`hudScale`](../../Menu/source/electron/main.js#L495) | 495 | - |  |
| 31 | [`createMainWindow`](../../Menu/source/electron/main.js#L497) | 497 | `port` |  |
| 32 | [`showMainWindow`](../../Menu/source/electron/main.js#L535) | 535 | - | ── Show / Restore the program's window (tray, a second start, the end of the lock screen) ── the game menu, when open, is the program's one window: bring it ... |
| 33 | [`backToHud`](../../Menu/source/electron/main.js#L553) | 553 | `focus` | the game menu has closed: the HUD comes back where it was (without taking focus when a game was just started) |
| 34 | [`closeDialog`](../../Menu/source/electron/main.js#L568) | 568 | `focusHud` |  |
| 35 | [`createTray`](../../Menu/source/electron/main.js#L576) | 576 | - | ── System Tray ── |
| 36 | [`openCenterDialog`](../../Menu/source/electron/main.js#L598) | 598 | `tab` | ── Center Dialog Window ── |
| 37 | [`fitW`](../../Menu/source/electron/main.js#L613) | 613 | `v` |  |
| 38 | [`fitH`](../../Menu/source/electron/main.js#L614) | 614 | `v` |  |
| 39 | [`reveal`](../../Menu/source/electron/main.js#L632) | 632 | - |  |
| 40 | [`gtaLog`](../../Menu/source/electron/main.js#L671) | 671 | `line` |  |
| 41 | [`gtaGpuName`](../../Menu/source/electron/main.js#L675) | 675 | - |  |
| 42 | [`rank`](../../Menu/source/electron/main.js#L694) | 694 | `s` |  |
| 43 | [`gtaInfo`](../../Menu/source/electron/main.js#L702) | 702 | - |  |
| 44 | [`xmlText`](../../Menu/source/electron/main.js#L707) | 707 | `s` |  |
| 45 | [`gtaWrite`](../../Menu/source/electron/main.js#L708) | 708 | `level` |  |
| 46 | [`setVal`](../../Menu/source/electron/main.js#L712) | 712 | `tag`, `v` |  |
| 47 | [`osyncRoot`](../../Menu/source/electron/main.js#L735) | 735 | - | ── 17 Nov (owner): FiveM extras in the same picker - ReShade (&lt;OSYNC&gt;\Tools\FiveM-ReShade) and mods (&lt;OSYNC&gt;\Tools\FiveM-Mods\&lt;name&gt;) ── Tu... |
| 48 | [`fivemApp`](../../Menu/source/electron/main.js#L736) | 736 | `game` |  |
| 49 | [`listFiles`](../../Menu/source/electron/main.js#L743) | 743 | `dir` | relative paths of every file under dir |
| 50 | [`walk`](../../Menu/source/electron/main.js#L745) | 745 | `d`, `rel` |  |
| 51 | [`reshadeDir`](../../Menu/source/electron/main.js#L754) | 754 | - |  |
| 52 | [`modsDir`](../../Menu/source/electron/main.js#L755) | 755 | - |  |
| 53 | [`reshadeFiles`](../../Menu/source/electron/main.js#L756) | 756 | - | [source, path inside plugins] |
| 54 | [`modNames`](../../Menu/source/electron/main.js#L761) | 761 | - |  |
| 55 | [`manifestOf`](../../Menu/source/electron/main.js#L767) | 767 | `dir` |  |
| 56 | [`manifestSave`](../../Menu/source/electron/main.js#L768) | 768 | `dir`, `m` |  |
| 57 | [`fivemState`](../../Menu/source/electron/main.js#L769) | 769 | `game` |  |
| 58 | [`copyIn`](../../Menu/source/electron/main.js#L780) | 780 | `destDir`, `pairs` |  |
| 59 | [`removeOnly`](../../Menu/source/electron/main.js#L790) | 790 | `destDir`, `rels` |  |
| 60 | [`fivemReshadeAck`](../../Menu/source/electron/main.js#L796) | 796 | - | ReShade5=ID:%08x acknowledged that ReShade 5.x has a bug that will lead to game crashes with %08x = HashString(getenv("COMPUTERNAME")) - Jenkins one-at-a-tim... |
| 61 | [`iniSet`](../../Menu/source/electron/main.js#L809) | 809 | `file`, `section`, `key`, `value` | set (value) or take out (null) one key of one [section] in an ini file; returns true when the file changed |
| 62 | [`fivemApply`](../../Menu/source/electron/main.js#L828) | 828 | `game`, `extras` |  |
| 63 | [`steamReqBase`](../../Menu/source/electron/main.js#L876) | 876 | - | customer's own Steam app (QR) - System\Scripts\Master-SteamQueue.ps1. The master's LAN listener (Master-ClientReports.ps1, port ClientReportPort 4670) keeps ... |
| 64 | [`get`](../../Menu/source/electron/main.js#L884) | 884 | `k` | ]*)', 'mi')); return m ? m[1].trim() : ''; }; |
| 65 | [`steamReqCall`](../../Menu/source/electron/main.js#L890) | 890 | `method`, `p`, `body` |  |
| 66 | [`runSelfTest`](../../Menu/source/electron/main.js#L997) | 997 | `outDir` | Build check (tools\Build-App): HUD screenshot, open the game menu, save screenshots + card count, check that only one window shows at a time and that closing... |
| 67 | [`save`](../../Menu/source/electron/main.js#L998) | 998 | `name`, `img` |  |
| 68 | [`visible`](../../Menu/source/electron/main.js#L999) | 999 | - |  |
| 69 | [`js`](../../Menu/source/electron/main.js#L1022) | 1022 | `s` |  |
| 70 | [`js`](../../Menu/source/electron/main.js#L1050) | 1050 | `x` |  |
| 71 | [`wait`](../../Menu/source/electron/main.js#L1051) | 1051 | `ms` |  |

<a id="menu-source-electron-preload-js"></a>
### Menu/source/electron/preload.js

52 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/electron/preload.js)

<a id="menu-source-next-config-js"></a>
### Menu/source/next.config.js

10 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/next.config.js)

<a id="menu-source-src-app-dialog-page-jsx"></a>
### Menu/source/src/app/dialog/page.jsx

846 บรรทัด · 41 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/app/dialog/page.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`catOf`](../../Menu/source/src/app/dialog/page.jsx#L27) | 27 | `g` |  |
| 2 | [`hms`](../../Menu/source/src/app/dialog/page.jsx#L29) | 29 | `s` |  |
| 3 | [`PcIcon`](../../Menu/source/src/app/dialog/page.jsx#L34) | 34 | - |  |
| 4 | [`Poster`](../../Menu/source/src/app/dialog/page.jsx#L39) | 39 | `{ src`, `title }` |  |
| 5 | [`SmallIcon`](../../Menu/source/src/app/dialog/page.jsx#L50) | 50 | `{ src }` |  |
| 6 | [`DialogContent`](../../Menu/source/src/app/dialog/page.jsx#L55) | 55 | - |  |
| 7 | [`load`](../../Menu/source/src/app/dialog/page.jsx#L73) | 73 | - |  |
| 8 | [`showToast`](../../Menu/source/src/app/dialog/page.jsx#L99) | 99 | `msg` |  |
| 9 | [`handleKeyDown`](../../Menu/source/src/app/dialog/page.jsx#L136) | 136 | `e` |  |
| 10 | [`loadLauncherGames`](../../Menu/source/src/app/dialog/page.jsx#L149) | 149 | - |  |
| 11 | [`handleCloseDialog`](../../Menu/source/src/app/dialog/page.jsx#L172) | 172 | - |  |
| 12 | [`handleMinimizeDialog`](../../Menu/source/src/app/dialog/page.jsx#L175) | 175 | - |  |
| 13 | [`handleMaximizeDialog`](../../Menu/source/src/app/dialog/page.jsx#L178) | 178 | - |  |
| 14 | [`handleLaunchGame`](../../Menu/source/src/app/dialog/page.jsx#L182) | 182 | `title`, `cmd`, `game` |  |
| 15 | [`openGfx`](../../Menu/source/src/app/dialog/page.jsx#L196) | 196 | `g` |  |
| 16 | [`playGfx`](../../Menu/source/src/app/dialog/page.jsx#L208) | 208 | `level` |  |
| 17 | [`launch`](../../Menu/source/src/app/dialog/page.jsx#L222) | 222 | `g` |  |
| 18 | [`openCtx`](../../Menu/source/src/app/dialog/page.jsx#L229) | 229 | `e`, `g` |  |
| 19 | [`close`](../../Menu/source/src/app/dialog/page.jsx#L240) | 240 | - |  |
| 20 | [`onKey`](../../Menu/source/src/app/dialog/page.jsx#L241) | 241 | `e` |  |
| 21 | [`revealCtx`](../../Menu/source/src/app/dialog/page.jsx#L255) | 255 | - |  |
| 22 | [`copyCtx`](../../Menu/source/src/app/dialog/page.jsx#L262) | 262 | - |  |
| 23 | [`handleLaunchRandom`](../../Menu/source/src/app/dialog/page.jsx#L269) | 269 | - |  |
| 24 | [`catName`](../../Menu/source/src/app/dialog/page.jsx#L285) | 285 | `c` |  |
| 25 | [`badgeIcon`](../../Menu/source/src/app/dialog/page.jsx#L308) | 308 | `g` |  |
| 26 | [`catIcon`](../../Menu/source/src/app/dialog/page.jsx#L309) | 309 | `c` |  |
| 27 | [`GameCtxMenu`](../../Menu/source/src/app/dialog/page.jsx#L499) | 499 | `{ ctx`, `onPlay`, `onReveal`, `onCopy }` |  |
| 28 | [`item`](../../Menu/source/src/app/dialog/page.jsx#L508) | 508 | `key`, `on`, `label`, `icon`, `click` |  |
| 29 | [`GfxRow`](../../Menu/source/src/app/dialog/page.jsx#L562) | 562 | `{ icon`, `title`, `hint`, `on`, `right`, `onClick`, `onDoubleClick`, `className }` |  |
| 30 | [`GfxCheck`](../../Menu/source/src/app/dialog/page.jsx#L574) | 574 | `{ on }` |  |
| 31 | [`GfxSwitch`](../../Menu/source/src/app/dialog/page.jsx#L582) | 582 | `{ on }` |  |
| 32 | [`GfxPicker`](../../Menu/source/src/app/dialog/page.jsx#L589) | 589 | `{ gfx`, `onSel`, `onExtras`, `onPlay`, `onCancel }` |  |
| 33 | [`key`](../../Menu/source/src/app/dialog/page.jsx#L593) | 593 | `e` |  |
| 34 | [`setEx`](../../Menu/source/src/app/dialog/page.jsx#L606) | 606 | `patch` |  |
| 35 | [`SrQr`](../../Menu/source/src/app/dialog/page.jsx#L679) | 679 | `{ rows`, `size = 236 }` |  |
| 36 | [`SteamReqModal`](../../Menu/source/src/app/dialog/page.jsx#L690) | 690 | `{ onClose }` |  |
| 37 | [`tick`](../../Menu/source/src/app/dialog/page.jsx#L703) | 703 | - |  |
| 38 | [`key`](../../Menu/source/src/app/dialog/page.jsx#L716) | 716 | `e` |  |
| 39 | [`send`](../../Menu/source/src/app/dialog/page.jsx#L723) | 723 | - |  |
| 40 | [`cancel`](../../Menu/source/src/app/dialog/page.jsx#L734) | 734 | - |  |
| 41 | [`DialogPage`](../../Menu/source/src/app/dialog/page.jsx#L840) | 840 | - |  |

<a id="menu-source-src-app-layout-jsx"></a>
### Menu/source/src/app/layout.jsx

15 บรรทัด · 1 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/app/layout.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`RootLayout`](../../Menu/source/src/app/layout.jsx#L9) | 9 | `{ children }` |  |

<a id="menu-source-src-app-lock-page-jsx"></a>
### Menu/source/src/app/lock/page.jsx

512 บรรทัด · 15 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/app/lock/page.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`keepWords`](../../Menu/source/src/app/lock/page.jsx#L17) | 17 | `text` | headline: a run of Latin words ("AT9 COM-ONLINE") stays on one line (no break at the hyphen or between them); Thai text still wraps normally · very long Lati... |
| 2 | [`OptionScroll`](../../Menu/source/src/app/lock/page.jsx#L26) | 26 | `{ children }` | package / coupon option list: thin scrollbar + "more below" hint (13 Nov: at 1366x768 the 5th package was hidden with no sign of it) |
| 3 | [`check`](../../Menu/source/src/app/lock/page.jsx#L29) | 29 | - |  |
| 4 | [`hm`](../../Menu/source/src/app/lock/page.jsx#L50) | 50 | `sec` |  |
| 5 | [`mmss`](../../Menu/source/src/app/lock/page.jsx#L55) | 55 | `sec` |  |
| 6 | [`LockScreen`](../../Menu/source/src/app/lock/page.jsx#L80) | 80 | - |  |
| 7 | [`loadState`](../../Menu/source/src/app/lock/page.jsx#L118) | 118 | - |  |
| 8 | [`gotLogin`](../../Menu/source/src/app/lock/page.jsx#L150) | 150 | `data` |  |
| 9 | [`doLogin`](../../Menu/source/src/app/lock/page.jsx#L157) | 157 | `e` |  |
| 10 | [`doStart`](../../Menu/source/src/app/lock/page.jsx#L170) | 170 | - |  |
| 11 | [`newQr`](../../Menu/source/src/app/lock/page.jsx#L181) | 181 | - | ---- QR login: the phone (logged in to the shop web) scans, confirms → this screen gets the login pass ---- |
| 12 | [`submitTicket`](../../Menu/source/src/app/lock/page.jsx#L208) | 208 | `e` | ---- coupon (8 characters, cash bought at the counter) or old time ticket (10 characters) — no account ---- |
| 13 | [`mergeCoupon`](../../Menu/source/src/app/lock/page.jsx#L236) | 236 | `e` | 15 Nov: the customer merges another coupon into the checked one (whole balance moves · the other coupon can't be used again) the web refuses expired / in-use... |
| 14 | [`startCoupon`](../../Menu/source/src/app/lock/page.jsx#L251) | 251 | - |  |
| 15 | [`fmtTicket`](../../Menu/source/src/app/lock/page.jsx#L270) | 270 | `v` | 8 characters → XXXX-XXXX (coupon) · 10 → XXXXX-XXXXX (old ticket) |

<a id="menu-source-src-app-page-jsx"></a>
### Menu/source/src/app/page.jsx

330 บรรทัด · 10 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/app/page.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Home`](../../Menu/source/src/app/page.jsx#L7) | 7 | - |  |
| 2 | [`send`](../../Menu/source/src/app/page.jsx#L25) | 25 | - |  |
| 3 | [`formatTime`](../../Menu/source/src/app/page.jsx#L126) | 126 | `s` | ── Helpers ── |
| 4 | [`showToast`](../../Menu/source/src/app/page.jsx#L133) | 133 | `msg` |  |
| 5 | [`handleOpenDialog`](../../Menu/source/src/app/page.jsx#L139) | 139 | `tab` |  |
| 6 | [`handleMinimize`](../../Menu/source/src/app/page.jsx#L147) | 147 | - |  |
| 7 | [`handleClose`](../../Menu/source/src/app/page.jsx#L153) | 153 | - |  |
| 8 | [`handleConfirmLogout`](../../Menu/source/src/app/page.jsx#L160) | 160 | - |  |
| 9 | [`call`](../../Menu/source/src/app/page.jsx#L164) | 164 | - | end the rental through the shop system; the lock screen comes back by itself when the agent sees it |
| 10 | [`fmt`](../../Menu/source/src/app/page.jsx#L170) | 170 | `s` |  |

<a id="menu-source-src-components-icons-jsx"></a>
### Menu/source/src/components/Icons.jsx

49 บรรทัด · 1 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/components/Icons.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Icon`](../../Menu/source/src/components/Icons.jsx#L35) | 35 | `{ name`, `size = 20`, `fill = false`, `className = ''`, `style }` |  |

<a id="menu-source-src-components-shoptabs-jsx"></a>
### Menu/source/src/components/ShopTabs.jsx

745 บรรทัด · 39 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/components/ShopTabs.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`hm`](../../Menu/source/src/components/ShopTabs.jsx#L36) | 36 | `sec` |  |
| 2 | [`call`](../../Menu/source/src/components/ShopTabs.jsx#L43) | 43 | `method`, `p`, `body` |  |
| 3 | [`errOf`](../../Menu/source/src/components/ShopTabs.jsx#L52) | 52 | `r`, `fallback` |  |
| 4 | [`notifyHud`](../../Menu/source/src/components/ShopTabs.jsx#L54) | 54 | `text` |  |
| 5 | [`Notice`](../../Menu/source/src/components/ShopTabs.jsx#L58) | 58 | `{ title`, `text`, `onBack }` |  |
| 6 | [`copyText`](../../Menu/source/src/components/ShopTabs.jsx#L70) | 70 | `v` |  |
| 7 | [`lineEmoji`](../../Menu/source/src/components/ShopTabs.jsx#L75) | 75 | `line` |  |
| 8 | [`TotpBox`](../../Menu/source/src/components/ShopTabs.jsx#L90) | 90 | `{ secret }` |  |
| 9 | [`copy`](../../Menu/source/src/components/ShopTabs.jsx#L103) | 103 | - |  |
| 10 | [`SecretView`](../../Menu/source/src/components/ShopTabs.jsx#L121) | 121 | `{ text }` |  |
| 11 | [`copy`](../../Menu/source/src/components/ShopTabs.jsx#L124) | 124 | `v`, `k` |  |
| 12 | [`SteamGuard`](../../Menu/source/src/components/ShopTabs.jsx#L155) | 155 | `{ orderId }` |  |
| 13 | [`get`](../../Menu/source/src/components/ShopTabs.jsx#L158) | 158 | - |  |
| 14 | [`SteamResult`](../../Menu/source/src/components/ShopTabs.jsx#L172) | 172 | `{ res }` |  |
| 15 | [`copy`](../../Menu/source/src/components/ShopTabs.jsx#L175) | 175 | - |  |
| 16 | [`CustomHoursRow`](../../Menu/source/src/components/ShopTabs.jsx#L191) | 191 | `{ prices`, `max`, `hours`, `setHours`, `active`, `onPick`, `balance`, `shortText }` |  |
| 17 | [`go`](../../Menu/source/src/components/ShopTabs.jsx#L198) | 198 | `h` |  |
| 18 | [`stop`](../../Menu/source/src/components/ShopTabs.jsx#L199) | 199 | `e` |  |
| 19 | [`OptionList`](../../Menu/source/src/components/ShopTabs.jsx#L225) | 225 | `{ options`, `balance`, `pick`, `setPick`, `shortText`, `hourPrices`, `maxHours`, `hours`, `setHours }` |  |
| 20 | [`TopupTab`](../../Menu/source/src/components/ShopTabs.jsx#L256) | 256 | `{ onToast }` | member → GET panel (credit, packages, QR top-up) coupon → POST coupon {action:'panel'} (coupon balance, extend from the coupon; top up the coupon at the coun... |
| 21 | [`load`](../../Menu/source/src/components/ShopTabs.jsx#L266) | 266 | - |  |
| 22 | [`mergeCoupon`](../../Menu/source/src/components/ShopTabs.jsx#L299) | 299 | `e` |  |
| 23 | [`extend`](../../Menu/source/src/components/ShopTabs.jsx#L315) | 315 | - |  |
| 24 | [`ShopTab`](../../Menu/source/src/components/ShopTabs.jsx#L413) | 413 | `{ onToast`, `onTab }` |  |
| 25 | [`load`](../../Menu/source/src/components/ShopTabs.jsx#L420) | 420 | - |  |
| 26 | [`buy`](../../Menu/source/src/components/ShopTabs.jsx#L426) | 426 | - |  |
| 27 | [`OrderRow`](../../Menu/source/src/components/ShopTabs.jsx#L506) | 506 | `{ o`, `getSecret`, `onView }` | 16 Nov: every ID row is the same size with two same-size buttons — "ดูข้อมูลไอดี" (popup with all lines) and "รับรหัส 2-Step" right on the row: Rockstar-styl... |
| 28 | [`twoStep`](../../Menu/source/src/components/ShopTabs.jsx#L509) | 509 | - |  |
| 29 | [`InventoryTab`](../../Menu/source/src/components/ShopTabs.jsx#L545) | 545 | - |  |
| 30 | [`getSecret`](../../Menu/source/src/components/ShopTabs.jsx#L557) | 557 | `id` |  |
| 31 | [`openView`](../../Menu/source/src/components/ShopTabs.jsx#L565) | 565 | `o` |  |
| 32 | [`DT`](../../Menu/source/src/components/ShopTabs.jsx#L595) | 595 | `ms` | ── phase 3 (12 Nov): chat with the shop (web support tickets — staff answer at admin → แจ้งปัญหา) ── |
| 33 | [`ChatTab`](../../Menu/source/src/components/ShopTabs.jsx#L598) | 598 | - |  |
| 34 | [`load`](../../Menu/source/src/components/ShopTabs.jsx#L605) | 605 | `ticketId` |  |
| 35 | [`send`](../../Menu/source/src/components/ShopTabs.jsx#L619) | 619 | `e` |  |
| 36 | [`AccountTab`](../../Menu/source/src/components/ShopTabs.jsx#L668) | 668 | - | ── phase 3 (12 Nov): account summary of the member renting this PC ── |
| 37 | [`tile`](../../Menu/source/src/components/ShopTabs.jsx#L677) | 677 | `label`, `value` |  |
| 38 | [`ShopTabs`](../../Menu/source/src/components/ShopTabs.jsx#L715) | 715 | `{ offsetMs`, `...props }` |  |
| 39 | [`ShopTabsInner`](../../Menu/source/src/components/ShopTabs.jsx#L723) | 723 | `{ tab`, `linked`, `site`, `onToast`, `onTab }` |  |

<a id="menu-source-src-components-topuppanel-jsx"></a>
### Menu/source/src/components/TopupPanel.jsx

172 บรรทัด · 7 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/components/TopupPanel.jsx)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`gcApi`](../../Menu/source/src/components/TopupPanel.jsx#L10) | 10 | `method`, `p`, `body` |  |
| 2 | [`baht`](../../Menu/source/src/components/TopupPanel.jsx#L15) | 15 | `satang` |  |
| 3 | [`mmss`](../../Menu/source/src/components/TopupPanel.jsx#L33) | 33 | `sec` |  |
| 4 | [`TopupPanel`](../../Menu/source/src/components/TopupPanel.jsx#L38) | 38 | `{ cfg`, `pass`, `onBalance`, `title = 'เติมเงิน' }` |  |
| 5 | [`body`](../../Menu/source/src/components/TopupPanel.jsx#L49) | 49 | `x` |  |
| 6 | [`create`](../../Menu/source/src/components/TopupPanel.jsx#L70) | 70 | `a` |  |
| 7 | [`cancel`](../../Menu/source/src/components/TopupPanel.jsx#L81) | 81 | - |  |

<a id="menu-source-src-lib-api-js"></a>
### Menu/source/src/lib/api.js

260 บรรทัด · 18 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/lib/api.js)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`apiRequest`](../../Menu/source/src/lib/api.js#L5) | 5 | `endpoint`, `options = {}` |  |
| 2 | [`getSession`](../../Menu/source/src/lib/api.js#L44) | 44 | - |  |
| 3 | [`heartbeat`](../../Menu/source/src/lib/api.js#L64) | 64 | `usedSec` |  |
| 4 | [`lock`](../../Menu/source/src/lib/api.js#L71) | 71 | `pin` |  |
| 5 | [`logout`](../../Menu/source/src/lib/api.js#L78) | 78 | - |  |
| 6 | [`getItems`](../../Menu/source/src/lib/api.js#L90) | 90 | `category = 'all'` |  |
| 7 | [`submitOrder`](../../Menu/source/src/lib/api.js#L98) | 98 | `orderPayload` |  |
| 8 | [`getPurchasedAccounts`](../../Menu/source/src/lib/api.js#L117) | 117 | - |  |
| 9 | [`getGames`](../../Menu/source/src/lib/api.js#L133) | 133 | `category = 'all'`, `query = ''` | Offline first: the catalog comes from &lt;GCafe&gt;\data\games.json through Electron. When an API url is set and the server answers with a list, the server l... |
| 10 | [`launchGame`](../../Menu/source/src/lib/api.js#L145) | 145 | `title`, `cmd`, `game` |  |
| 11 | [`syncCloudSave`](../../Menu/source/src/lib/api.js#L161) | 161 | `email`, `password` |  |
| 12 | [`setMouseSensitivity`](../../Menu/source/src/lib/api.js#L168) | 168 | `val` |  |
| 13 | [`getMessages`](../../Menu/source/src/lib/api.js#L183) | 183 | - |  |
| 14 | [`sendMessage`](../../Menu/source/src/lib/api.js#L192) | 192 | `text` |  |
| 15 | [`getPackages`](../../Menu/source/src/lib/api.js#L216) | 216 | - |  |
| 16 | [`requestTopup`](../../Menu/source/src/lib/api.js#L224) | 224 | `packageItem` |  |
| 17 | [`getProfile`](../../Menu/source/src/lib/api.js#L246) | 246 | - |  |
| 18 | [`redeem`](../../Menu/source/src/lib/api.js#L252) | 252 | `privilegeId` |  |

<a id="menu-source-src-lib-config-js"></a>
### Menu/source/src/lib/config.js

153 บรรทัด · 15 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/lib/config.js)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`appConfig`](../../Menu/source/src/lib/config.js#L7) | 7 | - | Values from &lt;GCafe&gt;\config.json arrive through the Electron preload as window.appConfig. An empty API url means offline mode: the game menu runs from d... |
| 2 | [`getApiBaseUrl`](../../Menu/source/src/lib/config.js#L22) | 22 | - |  |
| 3 | [`isOnline`](../../Menu/source/src/lib/config.js#L29) | 29 | - |  |
| 4 | [`setApiBaseUrl`](../../Menu/source/src/lib/config.js#L33) | 33 | `url` |  |
| 5 | [`getMachineId`](../../Menu/source/src/lib/config.js#L41) | 41 | - |  |
| 6 | [`setMachineId`](../../Menu/source/src/lib/config.js#L48) | 48 | `id` |  |
| 7 | [`getBrandConfig`](../../Menu/source/src/lib/config.js#L57) | 57 | - | Order: values saved in the hidden settings form &gt; config.json &gt; defaults (each field on its own). |
| 8 | [`setBrandConfig`](../../Menu/source/src/lib/config.js#L72) | 72 | `brand` |  |
| 9 | [`getUiConfig`](../../Menu/source/src/lib/config.js#L90) | 90 | - |  |
| 10 | [`pct`](../../Menu/source/src/lib/config.js#L92) | 92 | `v` |  |
| 11 | [`getBuildStamp`](../../Menu/source/src/lib/config.js#L114) | 114 | - |  |
| 12 | [`getIcons`](../../Menu/source/src/lib/config.js#L119) | 119 | - |  |
| 13 | [`applyUi`](../../Menu/source/src/lib/config.js#L125) | 125 | `kind` |  |
| 14 | [`getAuthToken`](../../Menu/source/src/lib/config.js#L138) | 138 | - |  |
| 15 | [`setAuthToken`](../../Menu/source/src/lib/config.js#L145) | 145 | `token` |  |

<a id="menu-source-src-lib-totp-js"></a>
### Menu/source/src/lib/totp.js

132 บรรทัด · 9 ฟังก์ชัน · [เปิดไฟล์](../../Menu/source/src/lib/totp.js)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`cleanTotpSecret`](../../Menu/source/src/lib/totp.js#L8) | 8 | `raw` |  |
| 2 | [`base32Bytes`](../../Menu/source/src/lib/totp.js#L13) | 13 | `secret` |  |
| 3 | [`sha1`](../../Menu/source/src/lib/totp.js#L28) | 28 | `msg` |  |
| 4 | [`hmacSha1`](../../Menu/source/src/lib/totp.js#L68) | 68 | `key`, `msg` |  |
| 5 | [`totpCode`](../../Menu/source/src/lib/totp.js#L83) | 83 | `secret`, `t = Date.now(` |  |
| 6 | [`totpRemaining`](../../Menu/source/src/lib/totp.js#L98) | 98 | `t = Date.now(` |  |
| 7 | [`totpSecretFromLine`](../../Menu/source/src/lib/totp.js#L105) | 105 | `line` |  |
| 8 | [`visibleLines`](../../Menu/source/src/lib/totp.js#L121) | 121 | `text` |  |
| 9 | [`totpSecretFromText`](../../Menu/source/src/lib/totp.js#L126) | 126 | `text` |  |

<a id="menu-tools-_system-imagetool-main-js"></a>
### Menu/tools/_system/imagetool/main.js

2 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../../Menu/tools/_system/imagetool/main.js)

<a id="menu-tools-_system-imagetool-render-js"></a>
### Menu/tools/_system/imagetool/render.js

34 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../../Menu/tools/_system/imagetool/render.js)

<a id="menu-tools-_system-set-exeinfo-mjs"></a>
### Menu/tools/_system/Set-ExeInfo.mjs

36 บรรทัด · 2 ฟังก์ชัน · [เปิดไฟล์](../../Menu/tools/_system/Set-ExeInfo.mjs)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`sleep`](../../Menu/tools/_system/Set-ExeInfo.mjs#L13) | 13 | `ms` | a freshly copied .exe is often still held by antivirus for a few seconds: retry |
| 2 | [`retry`](../../Menu/tools/_system/Set-ExeInfo.mjs#L14) | 14 | `what`, `fn` |  |

## คอนโซลแอดมินและคลังออนไลน์

คำอธิบายเต็ม: [07-CONSOLE-ONLINE-FUNCTIONS.md](07-CONSOLE-ONLINE-FUNCTIONS.md)

<a id="system-console-index-html"></a>
### System/Console/index.html

502 บรรทัด · 40 ฟังก์ชัน · [เปิดไฟล์](../Console/index.html)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`toast`](../Console/index.html#L198) | 198 | `msg`, `bad` | toast'); t.textContent = msg; t.style.borderColor = bad ? 'var(--bad)' : 'var(--line)'; t.style.display = 'block'; clearTimeout(t._h); t._h = setTimeout(() =... |
| 2 | [`api`](../Console/index.html#L199) | 199 | `path`, `body` |  |
| 3 | [`showList`](../Console/index.html#L206) | 206 | `l` | ulog')) $('#ulog').textContent = l.log.join('\n'); } |
| 4 | [`modal`](../Console/index.html#L207) | 207 | `title`, `text` | rep-t').textContent = title; $('#rep-x').textContent = text; $('#rep').classList.add('on'); } |
| 5 | [`openPage`](../Console/index.html#L211) | 211 | `p` |  |
| 6 | [`openSub`](../Console/index.html#L218) | 218 | `id` |  |
| 7 | [`stepOf`](../Console/index.html#L230) | 230 | `fail` |  |
| 8 | [`isFixed`](../Console/index.html#L231) | 231 | `id`, `reportAt` |  |
| 9 | [`realClients`](../Console/index.html#L233) | 233 | `list` |  |
| 10 | [`ago`](../Console/index.html#L234) | 234 | `m` |  |
| 11 | [`loadHome`](../Console/index.html#L244) | 244 | - |  |
| 12 | [`k`](../Console/index.html#L263) | 263 | `n`, `l`, `cls` |  |
| 13 | [`loadClients`](../Console/index.html#L272) | 272 | - |  |
| 14 | [`drawClients`](../Console/index.html#L280) | 280 | - |  |
| 15 | [`showReport`](../Console/index.html#L298) | 298 | `ip`, `pc` |  |
| 16 | [`loadSettings`](../Console/index.html#L326) | 326 | - |  |
| 17 | [`ctl`](../Console/index.html#L331) | 331 | `s`, `type` |  |
| 18 | [`multiChange`](../Console/index.html#L341) | 341 | `key`, `sel` |  |
| 19 | [`drawSettings`](../Console/index.html#L346) | 346 | - |  |
| 20 | [`saveSetting`](../Console/index.html#L356) | 356 | `key`, `value` |  |
| 21 | [`loadRaw`](../Console/index.html#L360) | 360 | - |  |
| 22 | [`drawRaw`](../Console/index.html#L361) | 361 | - |  |
| 23 | [`loadShop`](../Console/index.html#L371) | 371 | - |  |
| 24 | [`shopBody`](../Console/index.html#L375) | 375 | - | sh-api').value.trim(), machineId: $('#sh-mid').value.trim(), brandName: $('#sh-brand').value.trim(), menuOnly: !$('#sh-timer').checked, sidePanel: $('#sh-sid... |
| 25 | [`saveShop`](../Console/index.html#L376) | 376 | - |  |
| 26 | [`testShop`](../Console/index.html#L381) | 381 | - |  |
| 27 | [`showDoc`](../Console/index.html#L385) | 385 | - |  |
| 28 | [`loadGames`](../Console/index.html#L388) | 388 | - | ---------- games ---------- |
| 29 | [`drawGames`](../Console/index.html#L395) | 395 | - |  |
| 30 | [`saveGame`](../Console/index.html#L421) | 421 | `btn` |  |
| 31 | [`pickIcon`](../Console/index.html#L427) | 427 | `id` |  |
| 32 | [`resetIcon`](../Console/index.html#L433) | 433 | `id` |  |
| 33 | [`runUpdate`](../Console/index.html#L434) | 434 | - |  |
| 34 | [`loadDrives`](../Console/index.html#L437) | 437 | - | ---------- drives ---------- |
| 35 | [`addDrive`](../Console/index.html#L458) | 458 | `letter` |  |
| 36 | [`removeDrive`](../Console/index.html#L464) | 464 | `path` |  |
| 37 | [`loadOnline`](../Console/index.html#L471) | 471 | - |  |
| 38 | [`publish`](../Console/index.html#L487) | 487 | - |  |
| 39 | [`pull`](../Console/index.html#L488) | 488 | `key` |  |
| 40 | [`loadStatus`](../Console/index.html#L491) | 491 | - | ---------- status ---------- |

<a id="system-scripts-console-server-ps1"></a>
### System/Scripts/Console-Server.ps1

484 บรรทัด · 29 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Port`, `Register`, `Unregister`, `AllowStop`, `TestRoot` · [เปิดไฟล์](../Scripts/Console-Server.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Read-JsonFile`](../Scripts/Console-Server.ps1#L48) | 48-48 | `f` | ---------- files ---------- |
| 2 | [`Write-TextFile`](../Scripts/Console-Server.ps1#L49) | 49-55 | `f`, `text` |  |
| 3 | [`Set-SettingLine`](../Scripts/Console-Server.ps1#L57) | 57-64 | `Name`, `Value` | settings.txt: change one Key=Value line (comments and the rest stay), add it at the end when missing |
| 4 | [`Invoke-GameList`](../Scripts/Console-Server.ps1#L65) | 65-68 | - |  |
| 5 | [`Get-Cats`](../Scripts/Console-Server.ps1#L72) | 72-79 | - | ---------- games ---------- categories: the standard ones + every category the shop already uses (menu + extra-games.json, e.g. "Anime RPG") |
| 6 | [`Get-ExtraIndex`](../Scripts/Console-Server.ps1#L82) | 82-95 | - | extra-games.json per id: a game added by hand has an entry with "exe" (its own title / cat); a scanner game's changes - and hiding a hand-added game - are an... |
| 7 | [`Get-ConsoleGames`](../Scripts/Console-Server.ps1#L96) | 96-114 | - |  |
| 8 | [`Set-Prop`](../Scripts/Console-Server.ps1#L116) | 116-116 | `o`, `k`, `v` | set a property in place (keeps the order of a hand-written entry), add it when missing |
| 9 | [`Set-GameOverride`](../Scripts/Console-Server.ps1#L117) | 117-149 | `id`, `body` |  |
| 10 | [`Set-GameIcon`](../Scripts/Console-Server.ps1#L150) | 150-162 | `id`, `b64` |  |
| 11 | [`Remove-GameIcon`](../Scripts/Console-Server.ps1#L163) | 163-165 | `id` |  |
| 12 | [`Test-MenuImage`](../Scripts/Console-Server.ps1#L168) | 168-177 | `f` |  |
| 13 | [`Test-DisklessDisk`](../Scripts/Console-Server.ps1#L182) | 182-187 | `letter` | ---------- drives ---------- a disk of the diskless program (LW: kimage\ = images, kwrite\ = client write-back; other brands: images / cache) - never a game ... |
| 14 | [`Get-ConsoleDrives`](../Scripts/Console-Server.ps1#L188) | 188-223 | - |  |
| 15 | [`Add-GameDrive`](../Scripts/Console-Server.ps1#L224) | 224-258 | `body` |  |
| 16 | [`Remove-GameDrive`](../Scripts/Console-Server.ps1#L259) | 259-264 | `path` |  |
| 17 | [`Get-ConsoleStatus`](../Scripts/Console-Server.ps1#L269) | 269-281 | - | ---------- status ---------- fast (no process list - that took 2-5 s): the watcher holds the mutex Local\OSYNC-Master-Watch while it runs; which OSYNC folder... |
| 18 | [`Get-ReportDirs`](../Scripts/Console-Server.ps1#L285) | 285-285 | - | ---------- overview / client PCs / settings / shop systems (18 Nov 2026: "easier to manage, in Thai") ---------- client PCs' status reports (Client-OslinkRep... |
| 19 | [`Get-ReportFiles`](../Scripts/Console-Server.ps1#L286) | 286-286 | - |  |
| 20 | [`Read-ReportHead`](../Scripts/Console-Server.ps1#L287) | 287-292 | `f` |  |
| 21 | [`Get-ConsoleClients`](../Scripts/Console-Server.ps1#L293) | 293-317 | - |  |
| 22 | [`Get-ConsoleClientReport`](../Scripts/Console-Server.ps1#L318) | 318-323 | `ip` |  |
| 23 | [`Get-ConsoleOverview`](../Scripts/Console-Server.ps1#L324) | 324-350 | - |  |
| 24 | [`Get-SettingsView`](../Scripts/Console-Server.ps1#L352) | 352-364 | - | settings.txt for the console: every Key=Value with the comment lines just above it as its help |
| 25 | [`Set-ConsoleSetting`](../Scripts/Console-Server.ps1#L365) | 365-370 | `key`, `value` |  |
| 26 | [`Get-ShopView`](../Scripts/Console-Server.ps1#L374) | 374-379 | - |  |
| 27 | [`Set-JsonScalar`](../Scripts/Console-Server.ps1#L380) | 380-384 | `text`, `key`, `json` |  |
| 28 | [`Set-ShopConfig`](../Scripts/Console-Server.ps1#L385) | 385-398 | `b` |  |
| 29 | [`Test-ShopApi`](../Scripts/Console-Server.ps1#L399) | 399-407 | `b` |  |

<a id="system-scripts-hub-server-ps1"></a>
### System/Scripts/Hub-Server.ps1

145 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Port`, `Bind`, `Key`, `HubDir`, `AllowStop`, `Register`, `Unregister`, `UpnpRenewSec` · [เปิดไฟล์](../Scripts/Hub-Server.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-SafeName`](../Scripts/Hub-Server.ps1#L41) | 41-41 | `s` |  |
| 2 | [`Read-Json`](../Scripts/Hub-Server.ps1#L42) | 42-42 | `f` |  |
| 3 | [`Write-Json`](../Scripts/Hub-Server.ps1#L43) | 43-43 | `f`, `o` |  |
| 4 | [`Get-Requests`](../Scripts/Hub-Server.ps1#L46) | 46-46 | - |  |
| 5 | [`Get-TorIndex`](../Scripts/Hub-Server.ps1#L47) | 47-47 | - |  |
| 6 | [`Get-Announce`](../Scripts/Hub-Server.ps1#L51) | 51-73 | `req`, `pathKey` |  |
| 7 | [`Write-HubLog`](../Scripts/Hub-Server.ps1#L137) | 137-137 | `m` |  |

<a id="system-scripts-online-library-ps1"></a>
### System/Scripts/Online-Library.ps1

486 บรรทัด · 38 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Sync`, `Publish`, `Pull`, `MockWorker`, `List`, `Stop` · [เปิดไฟล์](../Scripts/Online-Library.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Get-OnlineConfig`](../Scripts/Online-Library.ps1#L41) | 41-54 | - |  |
| 2 | [`Initialize-OnlineData`](../Scripts/Online-Library.ps1#L55) | 55-55 | `cfg` |  |
| 3 | [`Write-OnlineLog`](../Scripts/Online-Library.ps1#L56) | 56-56 | `cfg`, `m` |  |
| 4 | [`Invoke-Hub`](../Scripts/Online-Library.ps1#L58) | 58-67 | `cfg`, `Method`, `Path`, `Body`, `TimeoutSec` |  |
| 5 | [`Get-MenuGames`](../Scripts/Online-Library.ps1#L70) | 70-70 | - | ---------- this branch's games ---------- |
| 6 | [`Get-SteamManifest`](../Scripts/Online-Library.ps1#L71) | 71-80 | `appid` |  |
| 7 | [`Get-DriveGameRoots`](../Scripts/Online-Library.ps1#L83) | 83-89 | - | roots that hold &lt;kind&gt;\&lt;game&gt; folders on the shared drives: X:\Games (X:\Games\Online ...) and X:\ (X:\Online ...), only when at least one kind f... |
| 8 | [`Get-RootedParts`](../Scripts/Online-Library.ps1#L90) | 90-94 | `root`, `path` | parts of $path below $root, or $null when it is not below |
| 9 | [`Get-ExtraGameIndex`](../Scripts/Online-Library.ps1#L95) | 95-95 | - |  |
| 10 | [`Expand-OnlinePath`](../Scripts/Online-Library.ps1#L96) | 96-96 | `p` |  |
| 11 | [`Resolve-ShareableGame`](../Scripts/Online-Library.ps1#L98) | 98-142 | `g`, `ExtraIndex`, `DriveRoots` | a menu game -&gt; @{ key; title; cat; kind (folder\|hoyoplay\|steam); rel; folder; [manifest; size] } or $null (not shareable) |
| 12 | [`Get-FolderSize`](../Scripts/Online-Library.ps1#L143) | 143-143 | `f` |  |
| 13 | [`Get-ShareableGames`](../Scripts/Online-Library.ps1#L144) | 144-163 | `cfg`, `NoSize` |  |
| 14 | [`Publish-Branch`](../Scripts/Online-Library.ps1#L165) | 165-173 | - |  |
| 15 | [`Get-OnlineView`](../Scripts/Online-Library.ps1#L176) | 176-203 | - | ---------- what other branches have ---------- |
| 16 | [`Get-JobFile`](../Scripts/Online-Library.ps1#L206) | 206-206 | `cfg` | ---------- pull jobs ---------- |
| 17 | [`Get-PullJobs`](../Scripts/Online-Library.ps1#L207) | 207-207 | - |  |
| 18 | [`Save-PullJobs`](../Scripts/Online-Library.ps1#L208) | 208-208 | `cfg`, `jobs` |  |
| 19 | [`Get-FreeBytes`](../Scripts/Online-Library.ps1#L209) | 209-209 | `path` |  |
| 20 | [`Get-PullDestination`](../Scripts/Online-Library.ps1#L210) | 210-235 | `cfg`, `g` |  |
| 21 | [`Start-Pull`](../Scripts/Online-Library.ps1#L236) | 236-258 | `Key` |  |
| 22 | [`Update-PullJobs`](../Scripts/Online-Library.ps1#L259) | 259-289 | `cfg` |  |
| 23 | [`Complete-SteamPull`](../Scripts/Online-Library.ps1#L290) | 290-296 | `cfg`, `j` |  |
| 24 | [`Invoke-ServeRequests`](../Scripts/Online-Library.ps1#L299) | 299-317 | `cfg` | ---------- serving other branches ---------- |
| 25 | [`Invoke-OnlineSync`](../Scripts/Online-Library.ps1#L318) | 318-329 | - |  |
| 26 | [`Start-EngineDownload`](../Scripts/Online-Library.ps1#L332) | 332-347 | `cfg`, `job`, `torrent`, `source` | ---------- engines ---------- |
| 27 | [`Get-EngineProgress`](../Scripts/Online-Library.ps1#L348) | 348-358 | `cfg`, `job` |  |
| 28 | [`Start-EngineSeed`](../Scripts/Online-Library.ps1#L359) | 359-365 | `cfg`, `folder`, `torrent` |  |
| 29 | [`Get-Aria2Secret`](../Scripts/Online-Library.ps1#L368) | 368-372 | `cfg` | aria2: one per branch, JSON-RPC on 127.0.0.1:&lt;OnlineRpcPort&gt; with a secret, BitTorrent on &lt;OnlineBtPort&gt;, no DHT / LPD / peer exchange (private t... |
| 30 | [`Invoke-Aria2`](../Scripts/Online-Library.ps1#L373) | 373-378 | `cfg`, `method`, `params`, `TimeoutSec` |  |
| 31 | [`Test-Aria2`](../Scripts/Online-Library.ps1#L379) | 379-379 | `cfg` |  |
| 32 | [`Get-Aria2BindIP`](../Scripts/Online-Library.ps1#L381) | 381-381 | `cfg` | the local IP aria2 uses: Settings OnlineBind, or (UPnP on) the IP the router maps to = the NIC with the internet route |
| 33 | [`Get-OnlineExternalIP`](../Scripts/Online-Library.ps1#L384) | 384-390 | `cfg` | the public IP the tracker should give other branches for this PC: OnlineExternalIP (an IP or a DDNS name), else the router's public IP over UPnP (only a real... |
| 34 | [`Get-Aria2ExternalIP`](../Scripts/Online-Library.ps1#L391) | 391-391 | `cfg` |  |
| 35 | [`Initialize-Aria2`](../Scripts/Online-Library.ps1#L392) | 392-413 | `cfg` |  |
| 36 | [`Update-Aria2Network`](../Scripts/Online-Library.ps1#L416) | 416-436 | `cfg` | every sync: aria2 runs while it has work (restarted after a reboot when its session has downloads / seeds), the UPnP mapping is renewed while it runs and rem... |
| 37 | [`Stop-OnlineEngine`](../Scripts/Online-Library.ps1#L437) | 437-444 | - |  |
| 38 | [`Invoke-MockWorker`](../Scripts/Online-Library.ps1#L447) | 447-470 | `id` | mock engine worker: copy from the seeder's folder (same PC) and check every piece against the .torrent |

<a id="system-scripts-online-torrent-ps1"></a>
### System/Scripts/Online-Torrent.ps1

133 บรรทัด · 10 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Online-Torrent.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`ConvertTo-Bencode`](../Scripts/Online-Torrent.ps1#L7) | 7-11 | `obj` |  |
| 2 | [`Write-BBytes`](../Scripts/Online-Torrent.ps1#L12) | 12-12 | `ms`, `b` |  |
| 3 | [`Write-Bencode`](../Scripts/Online-Torrent.ps1#L13) | 13-29 | `ms`, `obj` |  |
| 4 | [`ConvertFrom-Bencode`](../Scripts/Online-Torrent.ps1#L31) | 31-31 | `b` |  |
| 5 | [`Read-Bencode`](../Scripts/Online-Torrent.ps1#L32) | 32-48 | `b`, `pos` |  |
| 6 | [`Get-BStr`](../Scripts/Online-Torrent.ps1#L49) | 49-49 | `v` |  |
| 7 | [`Get-TorrentInfoHash`](../Scripts/Online-Torrent.ps1#L52) | 52-56 | `torrent` | info hash of a .torrent (SHA1 of the bencoded info dictionary, re-encoded = same bytes for canonical files) |
| 8 | [`Set-TorrentAnnounce`](../Scripts/Online-Torrent.ps1#L60) | 60-71 | `Torrent`, `Announce`, `InfoHash` | the same torrent with another tracker (each branch announces to the hub address IT can reach). The info dictionary - and so the info hash - stays the same; i... |
| 9 | [`New-GameTorrent`](../Scripts/Online-Torrent.ps1#L73) | 73-108 | `Folder`, `Announce`, `PieceLength`, `Progress` |  |
| 10 | [`Test-TorrentData`](../Scripts/Online-Torrent.ps1#L111) | 111-133 | `Torrent`, `Folder` | check a downloaded folder against a .torrent (every piece SHA1) -&gt; @{ ok; bad (pieces); missing (files) } |

<a id="system-scripts-online-upnp-ps1"></a>
### System/Scripts/Online-Upnp.ps1

187 บรรทัด · 14 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Status`, `Map`, `Unmap`, `Description`, `LeaseSec` · [เปิดไฟล์](../Scripts/Online-Upnp.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-PrivateIPv4`](../Scripts/Online-Upnp.ps1#L16) | 16-18 | `ip` |  |
| 2 | [`Get-UpnpLocalIP`](../Scripts/Online-Upnp.ps1#L20) | 20-25 | - | the local IPv4 to use: Settings OnlineBind (not 127.x), else the source address of the route to the internet |
| 3 | [`Invoke-UpnpHttp`](../Scripts/Online-Upnp.ps1#L28) | 28-55 | `Url`, `LocalIP`, `Method`, `Body`, `Headers`, `TimeoutMs` | minimal HTTP/1.1 over a TCP socket bound to $LocalIP (so the router sees that address) -&gt; @{ Status; Body } |
| 4 | [`Find-UpnpIgd`](../Scripts/Online-Upnp.ps1#L59) | 59-102 | `LocalIP`, `WaitMs`, `Fresh` | SSDP search (multicast + unicast to the default gateways) from $LocalIP -&gt; the first IGD with a WANIP/WANPPP connection service (kept 10 min). $env:OSYNC_... |
| 5 | [`Invoke-UpnpAction`](../Scripts/Online-Upnp.ps1#L105) | 105-119 | `Igd`, `Action`, `Arguments` | one SOAP action -&gt; hashtable of the answer's fields; a UPnP error throws "UPnP &lt;action&gt;: &lt;code&gt; &lt;description&gt;" |
| 6 | [`Get-UpnpExternalIP`](../Scripts/Online-Upnp.ps1#L120) | 120-120 | `Igd` |  |
| 7 | [`Get-UpnpMappings`](../Scripts/Online-Upnp.ps1#L121) | 121-127 | `Igd`, `Max` |  |
| 8 | [`Get-UpnpMapping`](../Scripts/Online-Upnp.ps1#L128) | 128-131 | `Igd`, `Port`, `Protocol` |  |
| 9 | [`Add-UpnpMapping`](../Scripts/Online-Upnp.ps1#L134) | 134-145 | `Port`, `Description`, `LeaseSec`, `Protocol`, `Igd` | map &lt;external Port&gt; -&gt; &lt;this PC&gt;:&lt;Port&gt; (TCP). Adding it again = renewing the lease. Refuses a port mapped to another host. |
| 10 | [`Remove-UpnpMapping`](../Scripts/Online-Upnp.ps1#L147) | 147-155 | `Port`, `Protocol`, `Igd` | remove the mapping only when it is OSYNC's and points at this PC (never someone else's) |
| 11 | [`Get-OnlineDataDir`](../Scripts/Online-Upnp.ps1#L158) | 158-158 | - | what OSYNC mapped (System\Data\Online\upnp.json, or $env:OSYNC_ONLINEDATA) - the console shows it without asking the router the online library's working fold... |
| 12 | [`Get-UpnpStateFile`](../Scripts/Online-Upnp.ps1#L159) | 159-159 | - |  |
| 13 | [`Get-UpnpState`](../Scripts/Online-Upnp.ps1#L160) | 160-160 | - |  |
| 14 | [`Save-UpnpState`](../Scripts/Online-Upnp.ps1#L161) | 161-169 | `Port`, `Protocol`, `Value` |  |

<a id="system-tests-fake-igd-ps1"></a>
### System/Tests/Fake-Igd.ps1

66 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Port`, `ExternalIP` · [เปิดไฟล์](../Tests/Fake-Igd.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Soap`](../Tests/Fake-Igd.ps1#L19) | 19-22 | `action`, `out` |  |
| 2 | [`Fault`](../Tests/Fake-Igd.ps1#L23) | 23-25 | `code`, `text` |  |

<a id="system-tests-sim-onlinelibrary-ps1"></a>
### System/Tests/Sim-OnlineLibrary.ps1

193 บรรทัด · 7 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Engine`, `HubPort`, `ClosedSide`, `Upnp`, `Keep` · [เปิดไฟล์](../Tests/Sim-OnlineLibrary.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Check`](../Tests/Sim-OnlineLibrary.ps1#L23) | 23-23 | `name`, `ok`, `detail` |  |
| 2 | [`New-FakeGame`](../Tests/Sim-OnlineLibrary.ps1#L37) | 37-37 | `dir`, `sizes` |  |
| 3 | [`Invoke-As`](../Tests/Sim-OnlineLibrary.ps1#L59) | 59-65 | `k`, `argv` |  |
| 4 | [`Get-View`](../Tests/Sim-OnlineLibrary.ps1#L66) | 66-66 | `k` |  |
| 5 | [`Get-Games`](../Tests/Sim-OnlineLibrary.ps1#L67) | 67-67 | `k` |  |
| 6 | [`Hub-Api`](../Tests/Sim-OnlineLibrary.ps1#L68) | 68-72 | `m`, `p`, `body`, `key` |  |
| 7 | [`Get-Igd`](../Tests/Sim-OnlineLibrary.ps1#L73) | 73-73 | - | 127.0.0.1:$igdPort/_state" -UseBasicParsing -TimeoutSec 10 } |

<a id="system-tests-test-console-ps1"></a>
### System/Tests/Test-Console.ps1

143 บรรทัด · 4 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Port`, `Keep` · [เปิดไฟล์](../Tests/Test-Console.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Check`](../Tests/Test-Console.ps1#L15) | 15-15 | `name`, `ok`, `detail` |  |
| 2 | [`Get-Api`](../Tests/Test-Console.ps1#L28) | 28-28 | `path` |  |
| 3 | [`Post-Api`](../Tests/Test-Console.ps1#L29) | 29-29 | `path`, `body` |  |
| 4 | [`Get-Code`](../Tests/Test-Console.ps1#L30) | 30-30 | `sb` |  |

## แกนกลางและเครื่องมือ

คำอธิบายเต็ม: [08-CORE-TOOLS.md](08-CORE-TOOLS.md)

<a id="system-scripts-branch-runner-ps1"></a>
### System/Scripts/Branch-Runner.ps1

217 บรรทัด · 10 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Install`, `Command`, `Status`, `Uninstall`, `OsyncRoot`, `Yes` · [เปิดไฟล์](../Scripts/Branch-Runner.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-Admin`](../Scripts/Branch-Runner.ps1#L34) | 34-34 | - |  |
| 2 | [`Say`](../Scripts/Branch-Runner.ps1#L35) | 35-35 | `t`, `c` |  |
| 3 | [`Get-NowMs`](../Scripts/Branch-Runner.ps1#L36) | 36-36 | - |  |
| 4 | [`Read-Json`](../Scripts/Branch-Runner.ps1#L37) | 37-37 | `p` |  |
| 5 | [`Inner`](../Scripts/Branch-Runner.ps1#L38) | 38-38 | `e` |  |
| 6 | [`Get-OsyncRoot`](../Scripts/Branch-Runner.ps1#L41) | 41-48 | - | OSYNC folder: -OsyncRoot, else the OSYNC this script lives in (System\Scripts), else what the install wrote down |
| 7 | [`Stop-Helpers`](../Scripts/Branch-Runner.ps1#L51) | 51-62 | - | stop every copy of the web link: the task, the pids it wrote down (here and in the old ProgramData folder), strays |
| 8 | [`Move-ToTrash`](../Scripts/Branch-Runner.ps1#L65) | 65-70 | `path`, `name` | move a folder to C:\_&lt;delete-ok&gt;\&lt;name&gt;-&lt;stamp&gt; (nothing is deleted - the owner empties that folder) |
| 9 | [`Write-Ascii`](../Scripts/Branch-Runner.ps1#L72) | 72-72 | `path`, `lines` |  |
| 10 | [`Show-Status`](../Scripts/Branch-Runner.ps1#L75) | 75-107 | - | ================================================================ -Status |

<a id="system-scripts-common-ps1"></a>
### System/Scripts/Common.ps1

417 บรรทัด · 35 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Common.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-PreMigration`](../Scripts/Common.ps1#L31) | 31-31 | - | $true while the old layout still runs this folder (step B not done): scripts that write what clients use must not run |
| 2 | [`Stop-IfPreMigration`](../Scripts/Common.ps1#L32) | 32-38 | `What` |  |
| 3 | [`Get-Setting`](../Scripts/Common.ps1#L44) | 44-50 | `Name`, `Default` | ---------- settings ---------- Settings\settings.txt: "Key=Value" lines, # = comment |
| 4 | [`Get-SharedDrives`](../Scripts/Common.ps1#L52) | 52-59 | - | drive letters the CLIENT PCs see (same letters as on the master); empty = every fixed drive except the system drive |
| 5 | [`Get-GameFolders`](../Scripts/Common.ps1#L66) | 66-78 | - | every game folder: GamesFolder (the main one = {GAMES}) + Settings GameFolders (more drives, e.g. D:\GAME;F:\GAME - each laid out like GAME\: Online\ Mobile\... |
| 6 | [`Get-OnlineSecret`](../Scripts/Common.ps1#L80) | 80-84 | - | the online library's shared key (hub + every branch): System\Data\Online\online.key - not in Settings (that goes to git) |
| 7 | [`Read-ExtraGames`](../Scripts/Common.ps1#L85) | 85-88 | - |  |
| 8 | [`Run-Ps`](../Scripts/Common.ps1#L91) | 91-95 | `File`, `ArgList` | run another script of System\Scripts in this console (its output and colors go straight to the screen, it can ask questions); returns only its exit code |
| 9 | [`Get-LanIP`](../Scripts/Common.ps1#L97) | 97-102 | - | this PC's shop-LAN IPv4: the adapter that has the default gateway, else the first private address |
| 10 | [`Get-SunshinePlan`](../Scripts/Common.ps1#L106) | 106-113 | - | Sunshine 0JAYSHOP port plan (Tools\Sunshine0J; Client-Sunshine0J.ps1 and Tool-SunshineProfiles.ps1): client PC n has the IP &lt;net&gt;.(offset + n) and the ... |
| 11 | [`Test-Admin`](../Scripts/Common.ps1#L113) | 113-113 | - |  |
| 12 | [`Test-IsMaster`](../Scripts/Common.ps1#L118) | 118-129 | - |  |
| 13 | [`Find-UninstallPath`](../Scripts/Common.ps1#L150) | 150-160 | `NamePattern` | install folder of a program from its uninstall entry (DisplayName matched as a regex): InstallLocation, else the folder of its icon / uninstaller |
| 14 | [`Get-Launcher`](../Scripts/Common.ps1#L161) | 161-161 | `Key` |  |
| 15 | [`Get-LauncherDir`](../Scripts/Common.ps1#L162) | 162-167 | `Key` |  |
| 16 | [`Get-LauncherExe`](../Scripts/Common.ps1#L168) | 168-168 | `Key` |  |
| 17 | [`Get-RobloxExe`](../Scripts/Common.ps1#L171) | 171-176 | - | Roblox (per-user app, not in the table: nothing keeps it open): Launchers\Roblox\Versions\version-&lt;hash&gt;\RobloxPlayerBeta.exe, newest one; the master's... |
| 18 | [`Get-LauncherInstallPath`](../Scripts/Common.ps1#L178) | 178-197 | `Key` | where the launcher is installed according to its own registry/config (wherever that is), '' = not installed |
| 19 | [`RegVal`](../Scripts/Common.ps1#L179) | 179-179 | `k`, `n` |  |
| 20 | [`Get-SteamDir`](../Scripts/Common.ps1#L201) | 201-207 | - | ---------- Steam ---------- the Steam folder in Launchers (shared, so clients use it too); on a master not set up yet: where Steam says it is |
| 21 | [`Get-SteamLibraries`](../Scripts/Common.ps1#L209) | 209-228 | - | every Steam library folder on the shared drives (read from Steam's libraryfolders.vdf, plus X:\Games\Steam / X:\SteamLibrary / X:\Steam) |
| 22 | [`Test-CfxGameDir`](../Scripts/Common.ps1#L240) | 240-244 | `g`, `dir` | a game folder FiveM / RedM can use: on a drive the clients see, with the game exe (and for FiveM not the Enhanced one) |
| 23 | [`Find-CfxGameDir`](../Scripts/Common.ps1#L246) | 246-259 | `g` | where the game is: Steam libraries (appmanifest), then Rockstar's registry keys, then GAME\Rockstar / GAME\Epic |
| 24 | [`Get-RealCasePath`](../Scripts/Common.ps1#L261) | 261-270 | `p` | the same path with the folders' real upper / lower case (Steam's libraryfolders.vdf keeps library paths in lower case) |
| 25 | [`Get-CfxApps`](../Scripts/Common.ps1#L272) | 272-289 | - | FiveM / RedM on the game disk: where the menu starts them (Menu\data\games.json), and the game folders (not Steam) |
| 26 | [`Read-CfxIni`](../Scripts/Common.ps1#L291) | 291-296 | `Ini` | CitizenFX.ini lines (Windows INI: ANSI, or UTF-16 with a BOM) |
| 27 | [`Get-CfxIVPath`](../Scripts/Common.ps1#L297) | 297-301 | `Ini` |  |
| 28 | [`Set-CfxIVPath`](../Scripts/Common.ps1#L303) | 303-315 | `Ini`, `Path` | sets [Game] IVPath= and keeps every other line of the file |
| 29 | [`Get-CfxStatus`](../Scripts/Common.ps1#L317) | 317-323 | - | per FiveM / RedM: the game folder found, what CitizenFX.ini says, and whether that is usable |
| 30 | [`Get-GameFolderStamp`](../Scripts/Common.ps1#L327) | 327-345 | - | what the watcher compares to notice a new / removed game without a launcher telling it: the game folders (GAME\&lt;kind&gt;\&lt;game&gt;, X:\Games\&lt;kind&g... |
| 31 | [`Get-MenuInfo`](../Scripts/Common.ps1#L349) | 349-358 | - | ---------- game menu ---------- the menu program is Menu\app\&lt;brandName&gt;.exe (Menu\config.json brandName), or the older Menu\app\0JAYSHOP.exe |
| 32 | [`Show-Live`](../Scripts/Common.ps1#L363) | 363-373 | `text` | ---------- console helpers ---------- Live status line, redrawn in place (and in the window title) so a long install visibly moves; '' clears it. Never logge... |
| 33 | [`Format-Sec`](../Scripts/Common.ps1#L374) | 374-374 | `s` |  |
| 34 | [`Invoke-Installer`](../Scripts/Common.ps1#L378) | 378-401 | `Exe`, `ArgList`, `Label`, `TimeoutSec` | Run an installer hidden and wait at most $TimeoutSec, with a live line while it runs; on timeout kill the whole process tree (a leftover child keeps Windows ... |
| 35 | [`Get-RiotBusy`](../Scripts/Common.ps1#L406) | 406-417 | - | Riot products still downloading/patching on this PC: &lt;name&gt;.manifest is written when a patch starts, &lt;name&gt;.ok when it is done. A manifest older ... |

<a id="system-scripts-http-lib-ps1"></a>
### System/Scripts/Http-Lib.ps1

125 บรรทัด · 10 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Http-Lib.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`ConvertFrom-UrlBytes`](../Scripts/Http-Lib.ps1#L9) | 9-19 | `s` |  |
| 2 | [`ConvertFrom-UrlString`](../Scripts/Http-Lib.ps1#L20) | 20-20 | `s` |  |
| 3 | [`Read-HttpRequest`](../Scripts/Http-Lib.ps1#L22) | 22-56 | `s`, `remote` |  |
| 4 | [`Write-HttpResponse`](../Scripts/Http-Lib.ps1#L59) | 59-73 | `s`, `res` |  |
| 5 | [`New-JsonResponse`](../Scripts/Http-Lib.ps1#L75) | 75-77 | `obj`, `Status` |  |
| 6 | [`New-ErrorResponse`](../Scripts/Http-Lib.ps1#L78) | 78-78 | `Status`, `Message` |  |
| 7 | [`Get-JsonBody`](../Scripts/Http-Lib.ps1#L79) | 79-79 | `req` |  |
| 8 | [`New-FileResponse`](../Scripts/Http-Lib.ps1#L83) | 83-87 | `file` |  |
| 9 | [`Write-HttpLog`](../Scripts/Http-Lib.ps1#L89) | 89-89 | `m` |  |
| 10 | [`Start-HttpServer`](../Scripts/Http-Lib.ps1#L92) | 92-125 | `Port`, `Bind`, `Handler`, `Name`, `OnIdle`, `IdleSeconds` | serve until the handler returns @{ Stop = $true } (tests) or the process ends -OnIdle { ... } -IdleSeconds 300: also run that block about every IdleSeconds b... |

<a id="system-scripts-osync-ps1"></a>
### System/Scripts/OSYNC.ps1

184 บรรทัด · 5 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Action`, `Arg` · [เปิดไฟล์](../Scripts/OSYNC.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Pause-End`](../Scripts/OSYNC.ps1#L24) | 24-24 | - |  |
| 2 | [`Ask`](../Scripts/OSYNC.ps1#L25) | 25-25 | `q` |  |
| 3 | [`Choose-Launcher`](../Scripts/OSYNC.ps1#L26) | 26-32 | - |  |
| 4 | [`Invoke-Action`](../Scripts/OSYNC.ps1#L34) | 34-111 | `a`, `x` |  |
| 5 | [`Show-Tools`](../Scripts/OSYNC.ps1#L113) | 113-147 | - |  |

<a id="system-scripts-setup-install-ps1"></a>
### System/Scripts/Setup-Install.ps1

273 บรรทัด · 13 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Target`, `ShopName`, `Upgrade`, `Payload`, `Source`, `Yes`, `NoWizard`, `BranchCommand`, `PlanOnly` · [เปิดไฟล์](../Scripts/Setup-Install.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Test-Installed`](../Scripts/Setup-Install.ps1#L19) | 19-19 | `dir` | an INSTALLED OSYNC has Launchers\ or System\Data\ (made by this setup); a download of the project has neither |
| 2 | [`Ask`](../Scripts/Setup-Install.ps1#L31) | 31-31 | `q`, `def` |  |
| 3 | [`YesNo`](../Scripts/Setup-Install.ps1#L32) | 32-32 | `q` |  |
| 4 | [`Head`](../Scripts/Setup-Install.ps1#L33) | 33-33 | `t` |  |
| 5 | [`Set-Line`](../Scripts/Setup-Install.ps1#L34) | 34-39 | `file`, `key`, `value`, `OnlyIfEmpty` |  |
| 6 | [`Set-BrandName`](../Scripts/Setup-Install.ps1#L41) | 41-45 | `file`, `name` | set "brandName" in config.json without reformatting the file |
| 7 | [`Get-Watchers`](../Scripts/Setup-Install.ps1#L47) | 47-47 | `root` | the OSYNC watcher of a folder (it keeps launchers open); stopped while its scripts are replaced |
| 8 | [`Expand-Files`](../Scripts/Setup-Install.ps1#L51) | 51-55 | `to` | the files to put in place: payload.zip unpacked, or a copy of the -Source folder (no .git, nothing a master made) |
| 9 | [`Clear-ShopValues`](../Scripts/Setup-Install.ps1#L59) | 59-64 | `file` |  |
| 10 | [`Clear-MenuShop`](../Scripts/Setup-Install.ps1#L66) | 66-73 | `file` | the game menu's config without the other shop's badge, logo, banner, server address and featured games |
| 11 | [`Sync-Tools`](../Scripts/Setup-Install.ps1#L78) | 78-96 | `from`, `root`, `bk` |  |
| 12 | [`Test-ToolsSame`](../Scripts/Setup-Install.ps1#L98) | 98-110 | `root` | proof that Tools\ is the same as the pack: every file in TOOLS-MANIFEST.txt there, same size and SHA256 |
| 13 | [`Quit`](../Scripts/Setup-Install.ps1#L139) | 139-139 | `rc` | leave nothing in TEMP when the person stops at a question |

<a id="system-scripts-setup-plan-ps1"></a>
### System/Scripts/Setup-Plan.ps1

164 บรรทัด · 3 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `SharedDrives`, `OutFile`, `PassThru`, `Quiet` · [เปิดไฟล์](../Scripts/Setup-Plan.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Out`](../Scripts/Setup-Plan.ps1#L15) | 15-15 | `t`, `c` |  |
| 2 | [`GB`](../Scripts/Setup-Plan.ps1#L16) | 16-16 | `b` |  |
| 3 | [`Test-OsyncInstalled`](../Scripts/Setup-Plan.ps1#L57) | 57-57 | `dir` | ---------- OSYNC already here? (installed = has Launchers\ or System\Data\; a download of the project has neither) ---------- |

<a id="system-scripts-tool-check-ps1"></a>
### System/Scripts/Tool-Check.ps1

212 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Mode` · [เปิดไฟล์](../Scripts/Tool-Check.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Add`](../Scripts/Tool-Check.ps1#L10) | 10-10 | `level`, `item`, `detail`, `fix` |  |
| 2 | [`Age`](../Scripts/Tool-Check.ps1#L11) | 11-11 | `t` |  |

<a id="system-scripts-tool-folder-icons-ps1"></a>
### System/Scripts/Tool-Folder-Icons.ps1

58 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Force` · [เปิดไฟล์](../Scripts/Tool-Folder-Icons.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Pick-Exe`](../Scripts/Tool-Folder-Icons.ps1#L9) | 9-12 | `dir` |  |
| 2 | [`Set-Icon`](../Scripts/Tool-Folder-Icons.ps1#L13) | 13-23 | `dir`, `iconRef` |  |

<a id="system-scripts-tool-linkscan-ps1"></a>
### System/Scripts/Tool-LinkScan.ps1

25 บรรทัด · 0 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Tool-LinkScan.ps1)

<a id="system-scripts-tool-migrate-ps1"></a>
### System/Scripts/Tool-Migrate.ps1

193 บรรทัด · 2 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `OldRoot`, `SkipSteamGames`, `Yes`, `NoMenuStart` · [เปิดไฟล์](../Scripts/Tool-Migrate.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Head`](../Scripts/Tool-Migrate.ps1#L26) | 26-26 | `t` |  |
| 2 | [`Ask`](../Scripts/Tool-Migrate.ps1#L27) | 27-27 | `q` |  |

<a id="system-scripts-tool-organize-drive-ps1"></a>
### System/Scripts/Tool-Organize-Drive.ps1

100 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `MoveTools` · [เปิดไฟล์](../Scripts/Tool-Organize-Drive.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Move-Thing`](../Scripts/Tool-Organize-Drive.ps1#L30) | 30-69 | `from`, `to`, `why` | move one folder (or file) on the same drive and repoint what points into it |

<a id="system-scripts-tool-pack-ps1"></a>
### System/Scripts/Tool-Pack.ps1

166 บรรทัด · 1 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `Out`, `NoExe`, `NoTools` · [เปิดไฟล์](../Scripts/Tool-Pack.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`Copy-Dir`](../Scripts/Tool-Pack.ps1#L27) | 27-31 | `from`, `to`, `xf` |  |

<a id="system-scripts-tool-riotdiag-ps1"></a>
### System/Scripts/Tool-RiotDiag.ps1

49 บรรทัด · 1 ฟังก์ชัน · [เปิดไฟล์](../Scripts/Tool-RiotDiag.ps1)

| # | ฟังก์ชัน | บรรทัด | พารามิเตอร์ | หมายเหตุในโค้ด |
|---|---|---|---|---|
| 1 | [`A`](../Scripts/Tool-RiotDiag.ps1#L7) | 7-7 | `s` |  |

<a id="system-scripts-tool-sunshineprofiles-ps1"></a>
### System/Scripts/Tool-SunshineProfiles.ps1

44 บรรทัด · 0 ฟังก์ชัน · พารามิเตอร์ของสคริปต์: `DryRun`, `Gateway` · [เปิดไฟล์](../Scripts/Tool-SunshineProfiles.ps1)

---
[← กลับสารบัญเอกสาร](README.md)
