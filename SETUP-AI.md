# SETUP-AI.md — คู่มือติดตั้งระบบ OSYNC บนเครื่องแม่สาขาใหม่ (สำหรับ AI / Claude Code)

คุณคือ AI ที่ช่วยเจ้าของร้านตั้งค่า **เครื่องแม่ (master) ของร้านเกม diskless** ให้เหมือนสาขาหลัก:
launcher ทุกค่ายรวมอยู่ที่ `<ไดรฟ์>:\OSYNC\GAMELUNCHER`, Steam จัดเป็น `X:\SteamLibrary` ต่อไดรฟ์,
และเครื่องลูกใช้โปรแกรมเมนูเกม `GCafe` (0JAYSHOP) ที่เปิดได้ทุกเกม
คุยกับเจ้าของร้านเป็นภาษาไทย อธิบายสั้นๆ ว่ากำลังทำอะไร และถามก่อนทุกครั้งที่ระบุไว้ด้านล่าง

---

## 0. กฎที่ต้องทำตามเสมอ (เรียนรู้มาจากสาขาหลัก)
1. **ห้ามลบไฟล์ถาวรเอง** — ของที่จะลบให้ย้ายไป `X:\_ลบได้\` (ไดรฟ์เดียวกัน = ย้ายเร็ว) แล้วให้คำสั่งลบกับเจ้าของร้านไปรันเอง
2. **ย้ายจริง ไม่ทิ้ง junction/link ไว้ที่ C:** — ใช้ `GAMELUNCHER\ClientSetup\Master-Move\Move-*.bat` (รัน dry-run ก่อนเสมอ แล้วให้เจ้าของร้านกด Y และกด Yes ที่ UAC เอง)
3. **ถามก่อน**: ดาวน์โหลด/ติดตั้งโปรแกรม (บอกชื่อ แหล่ง ขนาด), รีสตาร์ท Steam/launcher, ย้ายเกมข้ามไดรฟ์, แก้ไฟร์วอลล์/ความปลอดภัย (ให้คำสั่งเขาไปรันเอง), รีสตาร์ทบริการ diskless (`lwdiskless*`) — ห้ามทำเองเด็ดขาด
4. **AutoSync / ระบบอัปเดตเกมอื่น**: ถ้าเครื่องนี้มี AutoSync (BitTorrent.exe, โฟลเดอร์ `X:\AutoSync`) ห้าม kill/suspend BitTorrent และห้ามย้ายโฟลเดอร์ที่มันดูแลโดยไม่ถาม — เคยทำให้มันโหลดเกมใหม่ทั้งเกม
5. อย่าแตะไฟล์ระบบ diskless (`C:\lwserver`) นอกจาก **อ่าน** ค่า
6. Windows PowerShell 5.1: `reg.exe import` เขียน stderr → ใช้ `Start-Process -Wait`; symlink แบบ relative ใช้ `cmd /c mklink /D`; `Remove-Item -Recurse` อาจตาม junction; `Get-Content` ไฟล์ UTF-8 ต้องใส่ `-Encoding UTF8`; ใน string ใช้ `${var}:` แทน `$var:`
7. รายงานผลตามจริง ถ้าขั้นไหนข้ามหรือไม่ผ่านให้บอก

---

## 1. สำรวจเครื่องก่อน (อ่านอย่างเดียว)
1. **ไดรฟ์ที่เครื่องลูกเห็น** — อ่านจาก `C:\lwserver\config\lwservice.db` ตาราง `tServerDiskMng`
   (`drive` และ `vdiskletter` เป็นรหัส ASCII เช่น 72 = H; `vdiskletter` = ตัวอักษรที่เครื่องลูกเห็น, 0 = ไม่แชร์; type 1 = ดิสก์เกม)
   ```
   python -I -c "import sqlite3;c=sqlite3.connect(r'file:C:\lwserver\config\lwservice.db?mode=ro',uri=True);[print(chr(int(d))+':','type',t,'client',(chr(int(v)) if int(v) else '-')) for d,t,v in c.execute('select drive,type,vdiskletter from tServerDiskMng')]"
   ```
   ถ้าไม่มี python ให้ถามเจ้าของร้านว่าเครื่องลูกเห็นไดรฟ์อะไรบ้าง (ต้องเป็นตัวอักษรเดียวกับเครื่องแม่)
2. ไดรฟ์ทั้งหมด พื้นที่ว่าง, โฟลเดอร์ชั้นบนของแต่ละไดรฟ์ (`X:\Online`, `X:\Mobile`, `X:\SteamLibrary` ฯลฯ)
3. Steam: `HKCU\Software\Valve\Steam` → `SteamPath`, `steamapps\libraryfolders.vdf`, `appmanifest_*.acf` ทุก library, โฟลเดอร์ใน `common\` ที่ไม่มี manifest
4. Launcher ที่ติดตั้งอยู่และตำแหน่ง: Riot (`C:\ProgramData\Riot Games\RiotClientInstalls.json`), EA (`HKLM\SOFTWARE\Electronic Arts\EA Desktop`),
   Epic (`HKLM\SOFTWARE\EpicGames\Unreal Engine` + `C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests`), Garena (`HKLM\SOFTWARE\WOW6432Node\Garena\gxx`),
   Rockstar, Ubisoft (`HKLM\SOFTWARE\WOW6432Node\Ubisoft\Launcher`), HoYoPlay (`HKCU\Software\Cognosphere\HYP\1_0`)
5. สรุปให้เจ้าของร้านเป็นตาราง แล้ว **เสนอแผน** รอเขาตกลงก่อนลงมือ

## 2. วางโฟลเดอร์ OSYNC
- เลือกไดรฟ์เกม 1 ลูกที่เครื่องลูกเห็น (ถามเจ้าของร้าน) แล้ว `git clone <repo> X:\OSYNC`
- แก้ `GAMELUNCHER\ClientSetup\settings.txt` → `SharedDrives=` ตัวอักษรไดรฟ์เกมที่เครื่องลูกเห็น (เช่น `DEFGHIJ`)
- ไฟล์ snapshot ของสาขาหลักไม่ได้อยู่ใน git — สาขานี้สร้างเองในขั้นถัดไป

## 3. รวม launcher ไว้ที่ `X:\OSYNC\GAMELUNCHER`
ลำดับต่อ launcher: ติดตั้งตามปกติ (ถ้ายังไม่มี — ถามก่อนดาวน์โหลด) → ปิดโปรแกรม → `Master-Move\Move-<ชื่อ>.bat`
(สคริปต์ `_system\Move-Launcher.ps1` อ่านตำแหน่งเดิมจาก Registry เอง, ไดรฟ์เดียวกัน = เปลี่ยนชื่อโฟลเดอร์, ข้ามไดรฟ์ = ก๊อป+ตรวจ+ลบต้นทาง,
แก้ Registry/บริการ/Scheduled task/shortcut ให้ชี้ที่ใหม่, สำรองไว้ที่ `GAMELUNCHER\_archive`)
- ได้: Riot, EA, Epic, Garena, Rockstar, Ubisoft, HoYoPlay (เกมใน `HoYoPlay\games` ถูกย้ายไป `<ไดรฟ์>:\Mobile\<เกม>` — แล้วให้เจ้าของร้านกด "Locate game" ใน HoYoPlay), Modrinth
- หลังย้ายแต่ละตัว เปิดโปรแกรมจากที่ใหม่ให้ดูว่าใช้ได้
- launcher ค่ายอื่นที่ยังไม่มี preset: ดูวิธีใน `Move-Launcher.ps1` แล้วเพิ่ม preset ใหม่ (registry keys, services, exe names) — dry-run ก่อนเสมอ

## 4. เกมของแต่ละค่าย
- **Steam**: ทุกไดรฟ์มี `X:\SteamLibrary` และเพิ่มเป็น library ใน Steam; ย้ายเกมได้เฉพาะ **ภายในไดรฟ์เดียวกัน**
  (ย้ายโฟลเดอร์ `common\<เกม>` + `appmanifest_<id>.acf` ไปพร้อมกัน, ปิด Steam ก่อน); เกมซ้ำ → ย้ายไป `X:\_ลบได้`
  โฟลเดอร์ใน `common\` ที่ไม่มี manifest = Steam ไม่เห็น ให้ถามเจ้าของร้าน (ทำ manifest ให้ Steam ตรวจไฟล์ หรือย้ายไปลบ)
- **Riot**: อัปเดต VALORANT/LoL/TFT ใน Riot Client จนขึ้น Play → ปิด Riot Client → `Update-Master\Riot-Update-ClientData.bat`
- **EA app**: ติดตั้งเกมลงไดรฟ์เกม → `Update-Master\EA-Update-ClientData.bat`
- **Epic**: ติดตั้งเกมลงไดรฟ์เกม (เช่น `X:\EPIC\Fortnite`) → `Update-Master\Epic-Update-ClientData.bat`
- **Garena และเกมที่เปิดจาก exe ตรง** (เกมออนไลน์ไทย, มือถือ, โปรแกรม): ใส่ใน `GCafe\data\games.custom.json` (ขั้น 5)
  - FC Online: เปิด `launcher\fco-th.exe` ในโฟลเดอร์เกม (ไฟล์ 0 ไบต์ข้างนอกเป็น symlink ไม่ใช่ไฟล์เสีย)

## 5. โปรแกรมเมนูเกม GCafe (`X:\OSYNC\GCafe`)
1. ต้องใช้ Node.js LTS ครั้งแรก (ถามก่อน): `winget install OpenJS.NodeJS.LTS`
2. `cd X:\OSYNC\GCafe\source` → `npm ci`
3. `GCafe\tools\Build-App.bat` → ได้ `GCafe\app\0JAYSHOP.exe` (สร้าง runtime จาก Electron เอง, ใส่ไอคอนจาก `data\brand\app.ico`, จบด้วย self-test
   ดูรูป `GCafe\_build\selftest\selftest-gamemenu.png` ว่าเมนูขึ้นจริง)
4. `GCafe\config.json`: ชื่อร้าน/ป้าย/โลโก้ (`data\brand\logo.png`), `apiUrl` ว่าง = ออฟไลน์, `machineId` ว่าง = ใช้ชื่อเครื่อง
   เปลี่ยนโลโก้: `powershell -ExecutionPolicy Bypass -File GCafe\tools\_system\Make-Brand.ps1 -Image <รูป>` แล้ว Build-App ใหม่
5. `GCafe\data\games.custom.json` เป็นของสาขาหลัก — **เขียนใหม่ให้ตรงเครื่องนี้** (เก็บเฉพาะเกมที่มีจริง; Build-GameList หาโฟลเดอร์ใหม่ใน
   `X:\Online|Mobile|PvP|Single Player|Web` ให้เองพร้อมเดา exe — ใส่ใน custom เฉพาะเกมที่เดาผิด หรืออยู่นอกโฟลเดอร์เหล่านี้): สแกนโฟลเดอร์เกมที่ไม่ใช่ Steam/Riot/EA/Epic
   (`X:\Online`, `X:\Mobile`, `X:\PvP`, `X:\Web`, โฟลเดอร์เกม Garena ฯลฯ) หา exe ตัวเปิดเกมที่ถูก (launcher ของเกม ไม่ใช่ตัว updater/uninstall)
   รูปแบบ: `{ "id": "ชื่อสั้น", "title": "ชื่อโชว์", "cat": "Online|Mobile|Garena|Apps", "platform": "Garena (ถ้ามี)", "exe": "X:\\...\\game.exe", "root": "X:\\...", "args": "" }`
6. `GCafe\tools\Build-GameList.bat` (หรือ `X:\OSYNC\MASTER-Update-All.bat` ซึ่งทำให้ด้วย) → อ่าน WARNING ทุกบรรทัด (exe ไม่เจอ / exe 0 ไบต์ = ยังติดตั้งไม่เสร็จ) แล้วแก้
   รูปปก: Steam จากแคชในเครื่อง, ไม่มีรูปทำจากไอคอนโปรแกรมให้เอง, ใส่รูปจริงเองได้ที่ `data\posters\<id>.jpg`
7. เปิด `GCafe\app\0JAYSHOP.exe` บนเครื่องแม่ ลองกดเปิดเกม 2-3 เกมจากเมนู

## 6. เครื่องลูก (ให้เจ้าของร้านทำในโหมด super workstation / แก้ Image แล้วบันทึก Image)
- เครื่องแม่: กด `X:\OSYNC\MASTER-Update-All.bat` ก่อน (เก็บข้อมูล Riot/EA/Epic/EasyAntiCheat + สแกนรายการเกม) ทุกผลต้อง OK
- เครื่องลูก 1 เครื่อง: `X:\OSYNC\CLIENT-Install-All.bat` → Riot เงียบตอนล็อกอิน, **Steam first-run ของทุกเกม** (installscript.vdf:
  กันโกง BattlEye/ACE/Ricochet/EAC, Social Club, DirectX, VC++, registry), EA app + เกม EA + **EA AntiCheat**,
  **EasyAntiCheat** ของ Epic, เมนูเกม 0JAYSHOP — ดูตาราง RESULT ท้ายหน้าต่าง (log: `C:\Users\Public\OSYNC-Install-All.log`)
  ถ้าไม่ติดตั้งกันโกง เกมจะขึ้นหน้าโหลด/เช็กอัปเดตแล้วปิดเองบนเครื่องลูก (เช่น Apex "Checking for updates...")
- ปุ่มทีละอย่างอยู่ใน `GAMELUNCHER\ClientSetup\Install-Client\` สำหรับแก้ปัญหาเฉพาะจุด
- Riot Vanguard ต้องอยู่ใน Image; เกมที่ใช้ ACE (Delta Force, Arena Breakout) / BattlEye ติดตั้งกันโกงตอนเปิดเกมครั้งแรก — ให้เปิดครั้งแรกในโหมดแก้ Image
- ทดสอบที่เครื่องลูกจริง: เปิด VALORANT, เกม Steam, เกม EA, Fortnite และเกมออนไลน์ 1 เกม จากเมนู
- มีปัญหา Riot ขึ้น Repair: `GAMELUNCHER\ClientSetup\Diagnose\RiotDiag.bat` ที่เครื่องลูก แล้วอ่านรายงาน

## 7. ส่งงาน
สรุปให้เจ้าของร้าน: launcher ที่ย้าย, เกมที่อยู่ในเมนู (จำนวนตามหมวด), เกมที่ข้าม/ยังไม่สมบูรณ์, ของที่ย้ายไป `_ลบได้` พร้อมคำสั่งลบ,
และสิ่งที่เขาต้องทำต่อที่เครื่องลูก ถ้าแก้สคริปต์ในระบบ ให้ commit แยก branch ของสาขา (เช่น `branch-<ชื่อสาขา>`) อย่า push ทับ `main` โดยไม่ถาม
