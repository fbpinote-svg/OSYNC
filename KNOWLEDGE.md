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
- เครื่องแม่ต้องอัปเดตเกมใน Riot Client จนขึ้น Play แล้ว **ปิด Riot Client** ก่อน snapshot
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
- Electron app ที่มี single-instance lock: โหมดเครื่องมือ (`--imagetool`) ต้องเช็กก่อน lock
- หยุด Windows Update นานเกิน 5 สัปดาห์: `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` →
  `FlightSettingsMaxPauseDays`, `Pause*StartTime` / `PauseUpdatesExpiryTime` / `Pause*UpdatesEndTime` (เวลา UTC แบบ ISO) — ให้เจ้าของร้านรันเอง

## 13. กฎการทำงานที่ใช้กับร้านนี้
- **ไม่ลบไฟล์ถาวรเอง** — ย้ายไป `X:\_ลบได้` แล้วให้คำสั่งลบกับเจ้าของร้าน
- ถามก่อน: ดาวน์โหลด/ติดตั้ง, รีสตาร์ท Steam/launcher/บริการ, ย้ายข้ามไดรฟ์, ทุกอย่างที่เป็นค่าระบบ/ความปลอดภัย (ให้คำสั่งไปรันเอง)
- UAC: บอกเจ้าของร้านทุกครั้งที่ต้องกด Yes
- รายงานตามจริง: อะไรทดสอบแค่ dry-run หรือยังไม่ได้ลองที่เครื่องลูก ต้องบอก
- repo นี้เป็น public — ห้ามใส่รหัสผ่าน, ข้อมูลสมาชิก, อีเมลส่วนตัว, token ลง git
