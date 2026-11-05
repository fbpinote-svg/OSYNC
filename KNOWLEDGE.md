# KNOWLEDGE.md — ความรู้ที่ได้จากการตั้งระบบร้านเกม diskless (สาขาหลัก)

สรุปสิ่งที่เจอจริงตอนตั้งระบบ OSYNC: อาการ → สาเหตุ → วิธีแก้ และข้อควรระวัง
AI / คนที่ตั้งระบบสาขาใหม่ควรอ่านไฟล์นี้ก่อน `SETUP-AI.md` (ตัวอย่าง path เป็นของสาขาหลัก — ของสาขาอื่นอาจต่างไป)

---

## 1. ระบบ diskless (LW / Kritidet — white-label ของ 云更新)
- เครื่องลูกบูตจาก Image มี **C: ของตัวเองที่รีเซ็ตทุกรีบูต** — อะไรที่ลงใน C: ของเครื่องลูกต้องทำในโหมด super workstation (แก้ Image) แล้ว **บันทึก Image**
- ไดรฟ์เกมของเครื่องแม่ถูกแชร์ให้เครื่องลูกด้วย **ตัวอักษรเดียวกัน** เช็กว่าแชร์ไดรฟ์ไหนบ้างจาก `C:\lwserver\config\lwservice.db` ตาราง `tServerDiskMng`
  (`drive`, `vdiskletter` เป็นรหัส ASCII เช่น 72 = H; `vdiskletter` 0 = ไม่แชร์; type 1 = ดิสก์เกม, 2 = write-back ของเครื่องลูก, 3 = Image)
  ```
  python -I -c "import sqlite3;c=sqlite3.connect(r'file:C:\lwserver\config\lwservice.db?mode=ro',uri=True);[print(chr(int(d))+':','type',t,'client',(chr(int(v)) if int(v) else '-')) for d,t,v in c.execute('select drive,type,vdiskletter from tServerDiskMng')]"
  ```
  เพิ่มไดรฟ์ใน LW แล้ว ต้องแก้ `GAMELUNCHER\ClientSetup\settings.txt` → `SharedDrives=` ให้ตรง
- เครื่องลูกเขียนลงไดรฟ์เกมได้ แต่ไปลง write-back cache ของเครื่องนั้น — **หายตอนรีบูต** (อัปเดตเกม/launcher ที่เครื่องแม่เท่านั้น)
- แก้ไฟล์บนไดรฟ์เกมระหว่างร้านเปิด: เครื่องลูกที่เปิดค้างต้องรีบูตก่อนถึงจะเห็นของใหม่
- บริการของ LW: `lwserver64`, `lwgamemgr64`, `lwdiskless64`, `lwadditionalagent64` (`StartService.bat` ที่มากับโปรแกรมใช้ชื่อผิด)
  **ห้ามรีสตาร์ท `lwdiskless64` ตอนมีเครื่องลูกออนไลน์** — ถามเจ้าของร้านก่อนเสมอ
- **ไดรเวอร์การ์ดจอของเครื่องลูก**: ก๊อปโฟลเดอร์ไดรเวอร์ไป `C:\lwserver\spnp\videocard\<A_|N_|I_>64.10.0_<เวอร์ชัน>\`
  แล้วเพิ่มแถวใน `C:\lwserver\config\lwgamemgr.db` ตาราง `tGameList` (downpath ลงท้าย `\`, gname = grungame = ชื่อโฟลเดอร์, downver > 0)
  ใช้ GID เลขน้อย (เริ่ม 1) ไม่ให้ชนกับ GID ของ vendor (49371+); เลือกไดรเวอร์ต่ออุปกรณ์จาก dropdown ในคอนโซล
  - AMD 32.0.31041.x ตัด RX 5000/6000 (RDNA1/2) — การ์ดรุ่นนี้ต้องอยู่ที่ไดรเวอร์ 21025.x
  - NVIDIA 596.x ขึ้นไปตัดการ์ด Pascal (GTX 10xx) — การ์ดรุ่นนี้ต้องอยู่ที่ไดรเวอร์ 32.0.15.8180 (581.80)

## 2. รวม launcher ไว้ที่ `<ไดรฟ์>:\OSYNC\GAMELUNCHER`
- เจ้าของร้านต้องการ **ย้ายจริง** ไม่ทิ้ง junction/link ไว้ที่ C: → `Master-Move\Move-<ชื่อ>.bat` (dry-run ก่อนทุกครั้ง)
- สิ่งที่ต้องย้ายตามด้วยนอกจากไฟล์: Registry (คงชนิดค่าเดิม), บริการ (เปลี่ยน path ผ่าน SCM / WMI `Win32_Service.Change` ไม่ใช่แก้ registry ตรงๆ),
  Scheduled task, shortcut, ไฟล์ config ที่เก็บ path, protocol (`riotclient://`, `origin2://`, `uplay://`, `com.epicgames.launcher://` ...)
- **ก่อนลบโฟลเดอร์เก่าของโปรเจกต์ใดๆ เช็ก registry/uninstall/service ก่อน** — Rockstar Launcher และ HoYoPlay เคยถูกลงทะเบียนไว้ในโฟลเดอร์โปรเจกต์เก่า ลบแล้วเปิดไม่ได้
- EA app: โฟลเดอร์มี symlink แบบ relative `EA Desktop` → `<เวอร์ชัน>\EA Desktop` — ต้องสร้างใหม่ด้วย `cmd /c mklink /D` (PowerShell 5.1 สร้าง relative symlink ไม่ได้)
- HoYoPlay: จำตำแหน่งเกมในไฟล์ `gamedata.dat` (binary + .crc) แก้ไม่ได้ — ย้ายเกมแล้วต้องกด "Locate game" ใน HoYoPlay 1 ครั้ง
- Ubisoft: ย้ายทั้งโฟลเดอร์ `Program Files (x86)\Ubisoft` (มี `Ubisoft Game Launcher Core` ที่บริการ `UpcElevationService` ใช้)

## 3. Riot (VALORANT / LoL / TFT) บนเครื่องลูก
- อาการ: เครื่องลูกขึ้น **REPAIR NEEDED** / Install ทั้งที่เกมมีอยู่
- สาเหตุ: เครื่องลูกไม่มีข้อมูล `C:\ProgramData\Riot Games` (Metadata, RiotClientInstalls.json) และ/หรือมี **link เก่าที่เสีย** ใน ProgramData จากระบบเดิม
- วิธีแก้: เครื่องแม่ snapshot Metadata (`MASTER-Update-All.bat`) → เปิดเกมผ่าน `RiotSilent.vbs` เสมอ (ก๊อป Metadata + ซ่อม link + ตั้ง protocol ก่อนเปิด)
- snapshot ได้ทั้งที่ Riot Client เปิดอยู่ แต่ต้องไม่มีเกมกำลังอัปเดต: Riot เขียน `<เกม>.manifest` ตอนเริ่ม patch และ `<เกม>.ok` ตอนเสร็จ — manifest ใหม่กว่า ok = ยังไม่เสร็จ (`Get-RiotBusy` ใน `Settings.ps1`; snapshot จะรอ)
- ขึ้น REPAIR **หลังเกมอัปเดต** (เคยใช้ได้แล้ว) = เครื่องแม่อัปเดตเกมแล้วแต่ snapshot ยังเป็นของเก่า → `MASTER-Update-All.bat` หลังทุก patch (VALORANT ประมาณทุก 2 สัปดาห์)
  ถาวร: `GAMELUNCHER\ClientSetup\MASTER-Start-All.bat` ที่เครื่องแม่ (เปิด launcher ทุกค่ายค้างไว้ + ทำ MASTER-Update-All เองเมื่ออัปเดตเสร็จ); เครื่องลูกก๊อป Metadata ใหม่ทุกครั้งที่กดเล่น
- auto-update ของเกม Riot: เปิดที่เครื่องแม่ (`auto_patching_enabled_by_player: true`) แต่ snapshot บังคับสำเนาของเครื่องลูกเป็น `false` — เครื่องลูกต้องไม่ patch เกมบนไดรฟ์ที่แชร์เอง
- `C:\ProgramData\Riot Games\Metadata\RiotClient\Update\` ที่เครื่องแม่ = Riot Client โหลดอัปเดตตัวเองค้างไว้ (ติดตั้งตอนเปิด Riot Client ใหม่) → ห้ามส่งให้เครื่องลูก (snapshot ข้าม `Update`; ไม่งั้นเครื่องลูกติดตั้งเองทุกครั้งที่บูต) — MASTER-Start-All รีสตาร์ท Riot Client ให้เองเมื่อไม่มีเกมเปิด/อัปเดตอยู่
- Riot Vanguard (vgk/vgc) ต้องอยู่ใน Image ของเครื่องลูก — ตรวจปัญหาด้วย `Diagnose\RiotDiag.bat`

## 4. EA (EA app + เกม EA บน Steam)
- เครื่องลูกต้องมี: registry ของ EA app ที่ชี้ไป GAMELUNCHER, บริการ `EABackgroundService`, registry ของเกม (`Install Dir`), `C:\ProgramData\EA Desktop\InstallData`
- อาการ: กดเล่น **Apex แล้วขึ้นรูป Apex "Checking for updates..." แล้วปิดไปเอง** บนเครื่องลูก
  สาเหตุ: ไม่มี **EA AntiCheat (Javelin)** บนเครื่องนั้น (EA app ติดตั้งให้แค่เครื่องที่ลงเกม = เครื่องแม่)
  วิธีแก้: `EAAntiCheat.Installer.exe --noui --install --title <title>` — title อ่านจาก `EAAntiCheat.cfg` ในโฟลเดอร์เกม (`apex`, `bfv`, `bf6`)
- เปิดเกม EA app ตรงจากเมนูได้ถ้ารู้ offer id (`origin2://game/launch?offerIds=Origin.OFR.50.0002694` = Apex);
  `installerdata.xml` มีแค่ contentID ตัวเลข ใช้แทนไม่ได้ — เกมที่ไม่รู้ id ให้เมนูเปิด EA app แทน

## 5. Epic (Fortnite)
- เครื่องลูกต้องมีรายการเกมของ Epic: `C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item` + `C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat`
  → `EpicSilent.vbs` ก๊อปจาก snapshot (robocopy `/XO` = ไม่ทับไฟล์ที่ใหม่กว่า เครื่องแม่จึงไม่โดนทับ) แล้วเปิด
  `EpicGamesLauncher.exe "com.epicgames.launcher://apps/<namespace>%3A<itemId>%3A<appName>?action=launch&silent=true"`
- Fortnite ใช้ EasyAntiCheat แต่ไม่มี `Settings.json` บอก productid → เอา productid จาก `HKLM\SOFTWARE\WOW6432Node\EasyAntiCheat_EOS\ProductsInstalled` ของเครื่องแม่

## 6. Steam
- 1 library ต่อไดรฟ์ที่ `X:\SteamLibrary`; **ย้ายเกมได้เฉพาะในไดรฟ์เดียวกัน** (ย้าย `common\<เกม>` + `appmanifest_<id>.acf` พร้อมกัน, ปิด Steam ก่อน)
- โฟลเดอร์ใน `common\` ที่ไม่มี `appmanifest` = Steam มองไม่เห็น (เจอ ARK 169 GB ที่ไม่มี exe — ไฟล์ไม่ครบ)
- รายการใน "แอป" ของ Windows (uninstall entry) อาจค้างทั้งที่ไฟล์เกมไม่อยู่แล้ว — เชื่อไฟล์จริง ไม่ใช่รายการ
- **Steam first-run**: แต่ละเกมมี `installscript.vdf` สั่งติดตั้งของตอนเปิดครั้งแรกต่อเครื่อง (BattlEye, ACE, Ricochet, EasyAntiCheat, Social Club, DirectX, VC++)
  และเขียน registry; Steam จำว่าทำแล้วที่ `HKLM\SOFTWARE\WOW6432Node\Valve\Steam\Apps\...` (ค่า `HasRunKey`, ชื่อค่า = ชื่อ entry, 32-bit view)
  เครื่องลูก diskless ลืมทุกรีบูต → ช้า/เด้งปิด → `Steam-FirstRun.ps1` ทำให้ครั้งเดียวในโหมดแก้ Image
  (ข้าม `EAappInstaller` เพราะใช้ EA app ตัวกลาง, ข้าม `EAAntiCheat` เพราะมีขั้นตอนเฉพาะ)
  entry ที่ไม่มี `HasRunKey` (VC++, .NET, PhysX, EAC ของ Dead by Daylight/Rust/Chivalry 2 ... ~26 รายการ) จะรันซ้ำทุกครั้ง → เราจำเองที่
  `HKLM\SOFTWARE\OSYNC\SteamFirstRun` (ชื่อเกม|entry|คำสั่ง) — คำสั่งเปลี่ยน (เกมอัปเดตตัวกันโกง) = รันใหม่เอง
  ข้าม `_CommonRedist\DotNet` บน Windows 10/11: .NET 4.8 มีในตัว, `DotNetFx35Client.exe /q` รอ Windows Update → ค้างจนหมดเวลา
  ตัวติดตั้งทุกตัว (Steam/EAC/EA AntiCheat) ผ่าน `Invoke-Installer` ใน Settings.ps1: จำกัด 5 นาที, บรรทัดสถานะสด (หมุน + เวลา, ไม่ลง log; ลูกส่งเป็นบรรทัด "~" ให้ Install-All วาดทับ), เกิน 15 วิขึ้น "still running" ลง log, หมดเวลาฆ่าทั้ง process tree
  (ลูกที่ค้างไว้จะล็อก Windows Installer ให้ตัวถัดไปพัง 1618)
  (เกมไหนต้องการ .NET 3.5 จริง → เปิด Windows feature `NetFx3` ในโหมดแก้ Image)
- **เครื่องลูกเซ็ตตัวเองตอนเปิดเครื่อง**: งาน `OSYNC-Client-Boot` (SYSTEM, ตอน startup) รัน `Install-All.ps1 -Boot` ขั้น 1-4 เฉพาะของที่ยังไม่มี
  (EA AntiCheat จำที่ `HKLM\SOFTWARE\OSYNC\EAAntiCheat` ชื่อเกม|เวอร์ชัน, EAC ใช้ `ProductsInstalled` ของ EAC เอง) → ลงเกมใหม่ไม่ต้องแก้ Image
  เมนู/NEWTHINGS ไม่รันตอนบูต (เป็นของต่อผู้ใช้ และไม่เปลี่ยนเมื่อมีเกมใหม่); เครื่องแม่ยังต้องอัปเดตเกมและก๊อปข้อมูลติดตั้ง (C: ของเครื่องแม่ไม่ได้แชร์ให้เครื่องลูก)
- รูปปกเกม Steam รุ่นใหม่ไม่อยู่ที่ `cdn.akamai.steamstatic.com/steam/apps/<id>/header.jpg` แล้ว — ใช้แคชในเครื่อง `steam\appcache\librarycache\<id>\**\header.jpg`
  หรือ `store.steampowered.com/api/appdetails?appids=<id>` → `header_image`

## 7. กันโกง (anti-cheat) — สรุปอาการเครื่องลูก
| อาการ | สาเหตุ | แก้ |
|---|---|---|
| Apex / Battlefield ขึ้นหน้า "Checking for updates..." แล้วปิด | ไม่มี EA AntiCheat | `EAAntiCheat-Install.ps1` |
| DbD / Rust / VRChat / Fortnite ไม่เข้าเกม หรือถามสิทธิ์ admin | ไม่มี EasyAntiCheat EOS | `EasyAntiCheat_EOS_Setup.exe install <productid>` (`EAC-Install.ps1`) |
| GTA V / PUBG / R6 / CoD / Delta Force ช้าหรือเด้งตอนเปิดครั้งแรกทุกรีบูต | Steam first-run ทำซ้ำทุกรีบูต | `Steam-FirstRun.ps1` |
| VALORANT ไม่เข้า | Vanguard ไม่อยู่ใน Image | ลง Vanguard ในโหมดแก้ Image |
ทั้งหมดรวมอยู่ใน `CLIENT-Install-All.bat` — รันในโหมดแก้ Image แล้วบันทึก Image

## 8. ภาษาไทย / code page (สำคัญมาก)
- อาการ **"ภาษาเอเลี่ยน"** ใน GTA SA / SA-MP และเกมออนไลน์ไทยรุ่นเก่า: Windows เปิด "Beta: Use Unicode UTF-8 for worldwide language support"
  (ANSI code page = 65001) หรือภาษาระบบไม่ใช่ไทย → แก้: ภาษาระบบ Thai + ปิด UTF-8 beta (code page 874) แล้วรีสตาร์ท
  เช็กเร็วๆ: cmd → `chcp` → `65001` = เปิด beta อยู่, `874` = ไทยปกติ
- **ห้ามใช้ชื่อโฟลเดอร์ภาษาไทยกับเกม/launcher** (เช่น `H:\รวม NT`): บนเครื่องที่ code page ไม่ใช่ไทย เกม ANSI อ่าน path ไม่ได้ (เปิดไม่ติด)
  และตัวสร้าง shortcut ของ Windows (WScript) error "Value does not fall within the expected range" → ใช้ชื่อภาษาอังกฤษ เช่น `H:\Online\NEWTHINGS-GAMES`
- สคริปต์ PowerShell 5.1 ที่มีตัวอักษรไทยต้องบันทึกเป็น UTF-8 **มี BOM** ไม่งั้นอ่านเพี้ยน — ทางที่ดีอย่าใส่ภาษาไทยในสคริปต์ ให้หา path ตอนรันแทน

## 9. เกมเฉพาะที่เจอ
- **FC Online (Garena)**: ไฟล์ 0 ไบต์ที่ราก `D:\FIFA\32836` เป็น symlink ไป `mojitodata` ไม่ใช่ไฟล์เสีย — ตัวเปิดคือ `launcher\fco-th.exe`
- **NEWTHINGS-GAMES (GTA SA / SA-MP)**: launcher แบบ Tauri ติดตั้งลง `AppData\Local` ของผู้ใช้ (เครื่องลูกมองไม่เห็น) → ย้ายไปไดรฟ์เกม;
  ตัวเกมอยู่ที่ `<launcher>\bin\newthings` (อิงที่อยู่ของ exe); SA-MP หา GTA จาก `HKCU\Software\SAMP\gta_sa_exe` → `NEWTHINGS-Install.bat`
- **Genshin / HoYoPlay**: เกมเปิดตรงจาก `GenshinImpact.exe` ได้โดยไม่ต้องมี HoYoPlay บนเครื่องลูก
- **Rockstar (Steam)**: เกมต้องการ Social Club + Rockstar Games Launcher บนเครื่อง — Steam first-run ติดตั้งให้

## 10. AutoSync / ระบบโหลดเกมของร้านเก่า (ถ้าสาขายังใช้)
- AutoSync ดูแลเกมใน `X:\Online|Mobile|Single Player` ด้วย BitTorrent ของตัวเอง; รายการเกมอยู่ที่ `AppData\Local\AutoSync\db\gameClient.db`
- **ย้ายโฟลเดอร์เกมที่ torrent ยังทำงาน = มันโหลดใหม่ทั้งเกม**; kill/suspend BitTorrent ยิ่งแย่ (AutoSync รีสตาร์ทตัวเองแล้วดึงเกมที่ลบไปแล้วกลับมา)
  ที่ได้ผล: kill ครั้งเดียว → ย้ายโฟลเดอร์ออก → วางไฟล์ 0 ไบต์ read-only ชื่อเดียวกับโฟลเดอร์ไว้กันไม่ให้สร้างใหม่
- ก่อนแตะโฟลเดอร์ที่ AutoSync ดูแล ต้องถามเจ้าของร้าน
- ที่มา: บริการของ iPlay Cafe (iplaycafe.app) — `C:\Program Files\AutoSync Service Manager` (เปิดตอนล็อกอินจาก HKCU Run), `D:\AutoSync\AutoSync.exe` (Electron),
  BitTorrent แบบซ่อนหน้าต่างใน `AppData\Local\AutoSync\BitTorrent` (ปิดไป AutoSync เปิดกลับเอง), LockHunter ใช้ปลดล็อก/ปิดโปรแกรมที่จับไฟล์เกมก่อนอัปเดต
- ฐานข้อมูล `AppData\Local\AutoSync\db\*.db` **ไม่ใช่ SQLite** แต่เป็น NeDB: JSON 1 บรรทัดต่อ 1 รายการ บรรทัดหลังที่ `_id` เดียวกันทับบรรทัดก่อน `{"$$deleted":true}` = ลบ
  `gameClient.db` = เกมที่ลงในเครื่อง (`game_name`, `dir`, `first_exe`, `game_size`, `game_update`, `magnet`), `gameServer.db` = แคตตาล็อกเกมของ iPlay, `listDir.db` = ไดรฟ์/หมวด
- แต่ละเกมมี `zRunGame.exe` (สคริปต์ AutoIt ที่คอมไพล์แล้ว) เป็นตัวเปิด + `zPoster.jpg`; เกม Steam ถูกแพ็กเป็นโฟลเดอร์เดี่ยวพร้อม `appmanifest_<id>.acf`;
  launcher ที่ `zRunGame` ใช้อยู่ใน `E:\Common\GameLauncher`
- เมนูเก่า `E:\GameMenu` (iPlay GameMenu, Electron) ดึงรายการเกมจาก AutoSync บนเครื่องแม่ (พอร์ต 5555) แล้วรัน `first_exe` ในโฟลเดอร์เกม
  เมนู 0JAYSHOP ทำแบบเดียวกัน: `Build-GameList` อ่าน `first_exe` จาก `gameClient.db` (อ่านอย่างเดียว) จึงไม่ต้องเดา exe ของเกม AutoSync
- **ความปลอดภัย (จากการอ่านโค้ด ไม่ได้ลองเรียกจริง):** API พอร์ต 5555 ของ AutoSync บนเครื่องแม่ไม่มีการยืนยันตัวตน
  เครื่องลูกเครื่องไหนก็อ่านข้อมูลสมาชิกระบบเซฟเกม (รวมรหัสผ่าน ซึ่งเก็บเป็นข้อความธรรมดาใน `GameSave.db`) และไฟล์บนเครื่องแม่ได้
  AutoSync และ GameMenu ยังโหลดไฟล์ .reg จากเซิร์ฟเวอร์ของ iPlay แล้วรัน `regedit /s` ทุกครั้งที่เปิด และส่งข้อมูลเครื่อง (CPU/GPU/RAM/IP) ไปทุกครั้งที่เปิดเกม
  แก้: ย้ายเครื่องลูกมาใช้เมนู 0JAYSHOP แล้วบล็อกพอร์ต 5555 จากเครื่องลูกหรือเลิกใช้ AutoSync, ให้สมาชิกที่ใช้ระบบเซฟเกมเปลี่ยนรหัสผ่าน,
  แจ้งผู้ผลิต (iPlay Cafe) — ห้ามเอาข้อมูลสมาชิกหรือรายละเอียดวิธีเจาะลง git (repo นี้ public)
- ย้ายมาใช้ GameSync: ไฟล์เกมที่ AutoSync โหลดไว้ใช้ต่อได้เลย (เทียบ sha256 ไม่โหลดใหม่), `pull.skipAutoSyncFolders` กันไม่ให้ GameSync ทับโฟลเดอร์ที่ AutoSync ของเครื่องนั้นยังดูแลอยู่

## 11. เมนูเกม GCafe (0JAYSHOP)
- Build ได้โดยไม่ต้องลง Node.js: `ELECTRON_RUN_AS_NODE=1 electron.exe node_modules\next\dist\bin\next build` (Build-App.ps1 ทำให้)
- ตัวโปรแกรมที่ build แล้วรัน `0JAYSHOP.exe --imagetool <jobs.json>` เพื่อทำรูปปก (Chromium อ่าน webp/bmp/ico ได้ — WIC ของ Windows อ่าน webp บางไฟล์ไม่ได้)
- ปิด 0JAYSHOP แล้ว antivirus อาจล็อก exe อยู่หลายวินาที → robocopy ต้อง retry (`/R:10 /W:3`)
- เดา exe ของเกมใหม่ (Build-GameList): launcher/portable +5, start/play +3, ชื่อคล้ายโฟลเดอร์ +3, ลบ 1 ต่อชั้นโฟลเดอร์ย่อย,
  ตัด unins/setup/update/crash/anti-cheat/xldr/… — ทดสอบกับ 28 เกมของสาขาหลักถูกทั้งหมด

## 12. Windows / PowerShell 5.1 ที่ต้องระวัง
- `reg.exe import` เขียนข้อความสำเร็จลง stderr → กับ `-ErrorAction Stop` จะหยุดสคริปต์ — รันด้วย `Start-Process -Wait -PassThru` แล้วเช็ก exit code
- `New-Item -ItemType SymbolicLink` กับ target แบบ relative ใช้ไม่ได้ → `cmd /c mklink /D`
- `Remove-Item -Recurse` อาจเดินเข้า junction — ลบ link ก่อนด้วย `[IO.Directory]::Delete(link)`
- `Get-Content` ไฟล์ UTF-8 ต้องใส่ `-Encoding UTF8`; ใน string ใช้ `${var}:` แทน `$var:`
- `Get-ItemProperty -Path` กับชื่อ key ที่มี `[` `]` ถูกตีเป็น wildcard → ใช้ `$key.GetValue('name')`
- กด `.bat` จาก terminal PowerShell 7 → `PSModulePath` ของ 7 ติดไปถึง `powershell.exe` 5.1 จนหา `Get-FileHash` ไม่เจอ (ขั้น Riot ขึ้น FAIL ทั้งที่ Riot ปกติ) — ล้างค่าในไฟล์ `.bat` ด้วย `set "PSModulePath="`
- Electron app ที่มี single-instance lock: โหมดเครื่องมือ (`--imagetool`) ต้องเช็กก่อน lock
- หยุด Windows Update นานเกิน 5 สัปดาห์: `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` →
  `FlightSettingsMaxPauseDays`, `Pause*StartTime` / `PauseUpdatesExpiryTime` / `Pause*UpdatesEndTime` (เวลา UTC แบบ ISO) — ให้เจ้าของร้านรันเอง

## 13. กฎการทำงานที่ใช้กับร้านนี้
- **ไม่ลบไฟล์ถาวรเอง** — ย้ายไป `X:\_ลบได้` แล้วให้คำสั่งลบกับเจ้าของร้าน
- ถามก่อน: ดาวน์โหลด/ติดตั้ง, รีสตาร์ท Steam/launcher/บริการ, ย้ายข้ามไดรฟ์, ทุกอย่างที่เป็นค่าระบบ/ความปลอดภัย (ให้คำสั่งไปรันเอง)
- UAC: บอกเจ้าของร้านทุกครั้งที่ต้องกด Yes
- รายงานตามจริง: อะไรทดสอบแค่ dry-run หรือยังไม่ได้ลองที่เครื่องลูก ต้องบอก
- repo นี้เป็น public — ห้ามใส่รหัสผ่าน, ข้อมูลสมาชิก, อีเมลส่วนตัว, token ลง git
