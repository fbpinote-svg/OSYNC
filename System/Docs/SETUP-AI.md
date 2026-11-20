# SETUP-AI.md — คู่มือติดตั้ง OSYNC บนเครื่องแม่สาขาใหม่ (สำหรับ AI / Claude Code)

คุณคือ AI ที่ช่วยเจ้าของร้านตั้งค่า **เครื่องแม่ (master) ของร้านเกม diskless** ให้เหมือนสาขาหลัก
คุยกับเจ้าของร้านเป็นภาษาไทย อธิบายสั้นๆ ว่ากำลังทำอะไร และถามก่อนทุกครั้งที่ระบุไว้ด้านล่าง
**อ่าน [KNOWLEDGE.md](KNOWLEDGE.md) ก่อนเริ่ม** และ [HOW-IT-WORKS.md](HOW-IT-WORKS.md) เพื่อเข้าใจโครงโฟลเดอร์
เจอปัญหาใหม่แล้วแก้ได้ ให้เพิ่มลง KNOWLEDGE.md

```
<ไดรฟ์เกม>:\OSYNC\   OSYNC.bat  README.md  Settings\  Launchers\  Menu\  System\      (ชื่อโฟลเดอร์จะตั้งอะไรก็ได้ · ร้านนี้ H:\OSYNC · ร้าน AT9 E:\Autosync)
```

---

## 0. กฎที่ต้องทำตามเสมอ
1. **ห้ามลบไฟล์ถาวรเอง** — ย้ายไป `X:\_ลบได้\` (ไดรฟ์เดียวกัน = ย้ายเร็ว) แล้วให้คำสั่งลบกับเจ้าของร้านไปรันเอง
2. **ย้ายจริง ไม่ทิ้ง junction/link ไว้ที่ C:** — ย้าย launcher ด้วย OSYNC.bat > 7 > 1 (มันรัน dry-run ให้ดูก่อนเสมอ) ให้เจ้าของร้านกด Y และกด Yes ที่ UAC เอง
3. **ถามก่อน**: ดาวน์โหลด/ติดตั้งโปรแกรม (บอกชื่อ แหล่ง ขนาด), รีสตาร์ท Steam/launcher, ย้ายเกมข้ามไดรฟ์, แก้ไฟร์วอลล์/ความปลอดภัย, รีสตาร์ทบริการ diskless (`lwdiskless*`) — ห้ามทำเองเด็ดขาด
4. **AutoSync (ระบบโหลดเกมแบบ BitTorrent ของร้านเก่า)**: ถ้ามี (BitTorrent.exe, โฟลเดอร์ `X:\AutoSync`) ห้าม kill/suspend และห้ามย้ายโฟลเดอร์ที่มันดูแลโดยไม่ถาม
5. อย่าแตะไฟล์ระบบ diskless (`C:\lwserver`) นอกจาก **อ่าน**
6. Windows PowerShell 5.1: ดู KNOWLEDGE ข้อ 12 — สคริปต์ใน `System\Scripts` เป็น ASCII ล้วน อย่าใส่ภาษาไทยในไฟล์ .ps1
7. รายงานผลตามจริง ถ้าขั้นไหนข้ามหรือไม่ผ่านให้บอก

---

## 1. สำรวจเครื่องก่อน (อ่านอย่างเดียว)
1. วางโฟลเดอร์ OSYNC บนไดรฟ์เกมที่เครื่องลูกเห็น (ถามเจ้าของร้านว่าไดรฟ์ไหน) — `git clone <repo> X:\OSYNC` หรือก๊อปโฟลเดอร์มา
2. กด `X:\OSYNC\OSYNC.bat check` (หรือ `System\Scripts\Tool-Check.ps1`) — ได้ตาราง OK / WARN / FAIL ของทั้งเครื่อง ไม่แก้อะไร
3. ดูเพิ่มเอง: ไดรฟ์ทั้งหมด พื้นที่ว่าง โฟลเดอร์ชั้นบนของแต่ละไดรฟ์ (`X:\Online`, `X:\Mobile`, `X:\SteamLibrary` ฯลฯ), เกม Steam ที่ไม่มี appmanifest
4. สรุปให้เจ้าของร้านเป็นตาราง แล้ว **เสนอแผน** รอเขาตกลงก่อนลงมือ

## 2. ตัวช่วยตั้งค่า: OSYNC.bat > 4 (`Master-Setup.ps1`)
ให้เจ้าของร้านกดเอง (ขอ UAC) — มันถามทีละขั้น ขั้นที่ทำแล้วจะบอกว่า OK (ดูก่อนได้ด้วย `Master-Setup.ps1 -DryRun`):

1. **ไดรฟ์ที่เครื่องลูกเห็น** → `Settings\settings.txt` (`SharedDrives=`) — อ่านจากฐานข้อมูลของโปรแกรม diskless ให้เองถ้ามี Node.js
   (`C:\lwserver\config\lwservice.db` ตาราง `tServerDiskMng`: `vdiskletter` = ตัวอักษรที่เครื่องลูกเห็น, type 1 = ดิสก์เกม) ไม่งั้นถามเจ้าของร้าน
2. **ย้าย launcher เข้า `Launchers\`** — ทีละค่าย: dry-run ให้ดู → ถาม → ย้าย (อ่านตำแหน่งเดิมจาก Registry, ไดรฟ์เดียวกัน = เปลี่ยนชื่อ, ข้ามไดรฟ์ = ก๊อป+ตรวจ+ลบต้นทาง, แก้ Registry/บริการ/งานตั้งเวลา/shortcut ให้ชี้ที่ใหม่, สำรองไว้ใน `System\Backup`)
   ค่ายที่มี: Steam, Riot, EA, Epic, Garena, Ubisoft, Rockstar, HoYoPlay (เกมใน `HoYoPlay\games` ย้ายไป `GAME\HoYoPlay\<เกม>` แล้วให้เจ้าของร้านกด "Locate game" ใน HoYoPlay), Modrinth
   หลังย้ายแต่ละตัว เปิดโปรแกรมจากที่ใหม่ให้ดูว่าใช้ได้ — ค่ายใหม่ที่ยังไม่มี: เพิ่มใน `Common.ps1` (`$LauncherTable`) และ preset ใน `Master-Move-Launcher.ps1`
3. **Steam library** — แนะนำ `X:\SteamLibrary` ทุกไดรฟ์ ตั้งเป็นค่าเริ่มต้นใน Steam; เกมที่อยู่ใน `Launchers\Steam\steamapps` ย้ายด้วย OSYNC.bat > 7 > 2
   (ต้องเพิ่ม library ใน Steam → Settings → Storage ก่อน) — โฟลเดอร์ใน `common\` ที่ไม่มี manifest = Steam ไม่เห็น ให้ถามเจ้าของร้าน
4. **เมนูเกม (`Menu\`)** — ชื่อร้าน/ป้าย/โลโก้ใน `Menu\config.json` และ `Menu\data\brand\` (ทำโลโก้: `Menu\tools\_system\Make-Brand.ps1 -Image <รูป>`)
   build ครั้งแรกต้องมี `Menu\source\node_modules`: ติดตั้ง Node.js LTS (ถามก่อน: `winget install OpenJS.NodeJS.LTS`) → `cd Menu\source` → `npm ci` → OSYNC.bat > 7 > 3
   (Electron 44 ขึ้น "node_modules is missing" ทั้งที่ npm ci ผ่าน: ดู KNOWLEDGE ข้อ 11) — จบด้วย self-test ดูรูป `Menu\_build\selftest\selftest-gamemenu.png`
5. **อัปเดตเครื่องลูก** (= OSYNC.bat > 1) — อ่าน WARNING ทุกบรรทัด: exe ไม่เจอ / exe 0 ไบต์ = ยังติดตั้งไม่เสร็จ / `AUTO added` = เดา exe ให้ ตรวจว่าถูก
6. **ตัวเฝ้า ON** (= OSYNC.bat > 2) — เปิด launcher ทุกค่ายค้างไว้ให้เกมอัปเดตเอง; เปิด auto-update ของเกม Riot ที่เครื่องแม่ (สำเนาของเครื่องลูกถูกบังคับปิดเสมอ)
7. **ตรวจระบบ** — ต้องไม่มี FAIL

## 3. เกมของแต่ละค่าย
- **Riot**: อัปเดต VALORANT/LoL/TFT ใน Riot Client จนขึ้น Play แล้ว OSYNC.bat > 1 (ไม่ต้องปิด Riot Client)
- **EA app / Epic**: ติดตั้งเกมลงไดรฟ์เกม (เช่น `X:\EA\<เกม>`, `X:\EPIC\Fortnite`) แล้ว OSYNC.bat > 1; เกม EA ที่รู้ offer id ใส่ใน `Settings\extra-games.json` → `eaOffers` จะเปิดตรงได้
- **Garena และเกมที่เปิดจาก exe ตรง** (เกมออนไลน์ไทย, มือถือ, โปรแกรม): วางใน `X:\Online|Mobile|PvP|Single Player|Web` ระบบหา exe เอง — ใส่ใน `Settings\extra-games.json` → `games` เฉพาะเกมที่เดาผิดหรืออยู่นอกโฟลเดอร์เหล่านี้
  รูปแบบ: `{ "id": "ชื่อสั้น", "title": "ชื่อโชว์", "cat": "Online|Mobile|Garena|Apps", "platform": "Garena", "exe": "X:\\...\\game.exe", "root": "X:\\...", "args": "" }`
  - FC Online: เปิด `launcher\fco-th.exe` ในโฟลเดอร์เกม (ไฟล์ 0 ไบต์ข้างนอกเป็น symlink ไม่ใช่ไฟล์เสีย)

## 4. เครื่องลูก (ให้เจ้าของร้านทำในโหมด super workstation / แก้ Image แล้วบันทึก Image)
- เครื่องแม่: OSYNC.bat > 1 ก่อน ทุกผลต้อง OK
- เครื่องลูก 1 เครื่อง **ต่อ 1 Image**: OSYNC.bat > 5 (หรือ `OSYNC.bat client`) → ดูตาราง RESULT (log `C:\Users\Public\OSYNC-Install-All.log`) → บันทึก Image
  ได้: Riot เงียบตอนล็อกอิน, Steam first-run ของทุกเกม (กันโกง, Social Club, Rockstar Launcher, DirectX, VC++), EA app + EA AntiCheat, EasyAntiCheat, เมนูเกม, NEWTHINGS, งาน `OSYNC-Client-Boot` ที่เซ็ตเกมใหม่เองทุกครั้งที่บูต
- ปุ่มทีละอย่าง (แก้ปัญหาเฉพาะจุด): OSYNC.bat > 7 > 4-14
- Riot Vanguard ต้องอยู่ใน Image; เกมที่ใช้ ACE (Delta Force, Arena Breakout) / BattlEye ติดตั้งกันโกงตอนเปิดเกมครั้งแรก — ให้เปิดครั้งแรกในโหมดแก้ Image
- ทดสอบที่เครื่องลูกจริง: เปิด VALORANT, เกม Steam, เกม EA, Fortnite และเกมออนไลน์ 1 เกม จากเมนู; OSYNC.bat > 6 ต้องไม่มี FAIL
- Riot ขึ้น Repair: OSYNC.bat > 7 > 15 ที่เครื่องลูก แล้วอ่านรายงาน

## 5. ส่งงาน
สรุปให้เจ้าของร้าน: launcher ที่ย้าย, เกมในเมนู (จำนวนตามหมวด), เกมที่ข้าม/ยังไม่สมบูรณ์, ของที่ย้ายไป `_ลบได้` พร้อมคำสั่งลบ, และสิ่งที่เขาต้องทำต่อที่เครื่องลูก
ถ้าแก้สคริปต์ ให้ commit แยก branch ของสาขา (เช่น `branch-<ชื่อสาขา>`) อย่า push ทับ `main` โดยไม่ถาม — repo นี้เป็น public ห้ามใส่รหัสผ่าน ข้อมูลสมาชิก token
