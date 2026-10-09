GCafe - โปรแกรมเมนูเกมเครื่องลูก (0JAYSHOP)  อัปเดต 8 ต.ค. 2026
=================================================================
ตอนนี้ใช้งานแบบ "ออฟไลน์": เมนูเกมใช้ได้เต็มที่ ไม่ต้องมีเซิร์ฟเวอร์
ระบบอื่น (จับเวลา, ซื้อไอดี, แชท, เติมเงิน, สมาชิก) มีหน้าจอพร้อมแล้ว รอต่อ API ทีหลัง

โครงสร้างโฟลเดอร์
-----------------
H:\OSYNC\GCafe\
  app\                 ตัวโปรแกรมที่เครื่องลูกเปิด  ->  app\0JAYSHOP.exe   (ห้ามแก้ไฟล์ในนี้เอง)
  config.json          ชื่อร้าน / ป้าย VIP / โลโก้ / ที่อยู่ API (แก้ด้วย Notepad ได้)
  data\games.json      รายการเกมในเมนู  (สร้างอัตโนมัติด้วย tools\Build-GameList.bat ห้ามแก้เอง)
  data\games.custom.json  เกมที่หาเองไม่ได้ (เกมออนไลน์ไทย, มือถือ, โปรแกรม) + แก้ชื่อ/หมวด/ซ่อนเกม
  data\posters\        รูปปกที่ใส่เอง  ->  ชื่อไฟล์ = id ของเกม เช่น riot-valorant.jpg, genshin.png
  data\posters\_auto\  รูปปกอัตโนมัติ (ไม่ต้องยุ่ง): ปก Steam จากแคชในเครื่อง + ปกที่ทำจากไอคอนโปรแกรม
  data\brand\          โลโก้ร้าน (logo.png) + ไอคอนแอป (app.ico) + รูปต้นฉบับ (source.jpg)
  tools\               ปุ่มกด (อธิบายด้านล่าง)
  tools\_system\       สคริปต์ที่ปุ่มเรียกใช้
  source\              ซอร์สโค้ดโปรแกรม (Next.js + Electron) สำหรับแก้หน้าตา/ต่อ API
  _build\              ไฟล์สำหรับประกอบโปรแกรม + ผลทดสอบ (_build\selftest\*.png)

ปุ่มใน tools\
-------------
[ เครื่องแม่ ]
  Build-GameList.bat   สแกนเกมใหม่ทั้งหมด -> เขียน data\games.json  (ไม่ต้อง build โปรแกรมใหม่)
                       กดทุกครั้งที่ ติดตั้ง/ลบเกม, แก้ games.custom.json, หรือใส่รูปปกใหม่
                       หาเกมจาก: Steam ทุก Library, Riot (ผ่านชุด GAMELUNCHER), EA app,
                                 games.custom.json, และ launcher ใน H:\OSYNC\GAMELUNCHER (หมวด Launchers)
  Build-App.bat        ประกอบโปรแกรมใหม่จาก source\ -> app\  (กดเฉพาะหลังแก้ source\ เท่านั้น)
                       ปิด 0JAYSHOP ที่เครื่องแม่ก่อน; ตอนท้ายจะเปิดเมนูเกมทดสอบเองแล้วปิด
[ เครื่องลูก - โหมด super workstation (แก้ Image) แล้วบันทึก Image ]
  Install-Client.bat   ให้โปรแกรมเปิดเองตอนเข้า Windows + ไอคอนบนเดสก์ท็อป
  Uninstall-Client.bat เอาออก

เพิ่มเกมที่ไม่ใช่ Steam/Riot/EA
-----------------------------
เปิด data\games.custom.json ด้วย Notepad เพิ่ม 1 บรรทัด (ระวังลูกน้ำ , ท้ายบรรทัด):
  { "id": "ชื่อสั้นภาษาอังกฤษ", "title": "ชื่อที่โชว์", "cat": "Online", "exe": "J:\\Online\\เกม\\เกม.exe" },
  - path ใช้ \\ (ทับสองตัว)
  - "args": "..." = พารามิเตอร์ตอนเปิด, "root": "..." = โฟลเดอร์เกม (หา zPoster.jpg ที่นี่)
  - "platform": "Garena" = ป้ายมุมซ้ายบนของการ์ด (Steam, EA app, Riot, Epic, Ubisoft, Rockstar, Garena)
    ไม่ใส่ = ป้ายแสดงชื่อหมวดแทน (เกมที่เปิด exe ตรง)
  - หมวด (cat) ที่ใช้อยู่: Steam Riot EA Rockstar Ubisoft Garena Online Mobile Apps Launchers
    ตั้งชื่อหมวดใหม่ได้ จะโผล่ในเมนูเอง
แก้เกมที่หาเจออัตโนมัติ (ไม่ต้องใส่ exe):
  { "id": "steam-730", "title": "CS2" }            เปลี่ยนชื่อ
  { "id": "steam-431960", "hide": true }           ซ่อน
  { "id": "launcher-epic", "cat": "Online" }       ย้ายหมวด
  id ของแต่ละเกมดูได้ใน data\games.json
แล้วกด tools\Build-GameList.bat

รูปปกเกม
--------
ลำดับที่ใช้: data\posters\<id>.jpg|png|webp  >  zPoster.jpg ในโฟลเดอร์เกม  >  รูปจาก Steam
             >  ถ้าไม่มีเลย ทำปกจากไอคอนของโปรแกรมให้อัตโนมัติ (data\posters\_auto\<id>.jpg)
ขนาดแนะนำ: แนวนอน 920x586 (การ์ดตัดขอบให้เอง)
อยากเปลี่ยนเป็นรูปจริง: ใส่รูปชื่อ <id>.jpg ใน data\posters\ แล้วกด Build-GameList
  (genshin.jpg / minecraft.jpg ในนั้นทำจากภาพในแคช HoYoPlay และไฟล์ Minecraft ในเครื่อง)
ทำปกจากไอคอนใหม่: ลบไฟล์ data\posters\_auto\<id>.jpg ทิ้ง แล้วกด Build-GameList

โลโก้ร้าน / ไอคอนแอป
-------------------
powershell -ExecutionPolicy Bypass -File tools\_system\Make-Brand.ps1 -Image <รูป.jpg> [-CenterX 0.5 -CenterY 0.5 -Radius 0.48]
  ตัดรูปเป็นวงกลม -> data\brand\logo.png + app.ico  (CenterX/Y/Radius = ตำแหน่งตัดเป็นสัดส่วนของรูป)
แล้วกด tools\Build-App.bat (ใส่ไอคอนลง 0JAYSHOP.exe)  ถ้าเครื่องแม่ยังเห็นไอคอนเก่า = แคชไอคอนของ Windows

การเปิดเกม
----------
- Steam: "steam.exe -applaunch <appid>"  (Steam ที่ F:\steam)
- Riot:  ผ่าน GAMELUNCHER\ClientSetup\RiotSilent.vbs (ซ่อมลิงก์ + เตรียมเครื่องลูกให้อัตโนมัติ)
- EA app: origin2:// (เครื่องลูกต้องกด GAMELUNCHER\ClientSetup\Install-Client\EA-Install.bat ไว้แล้ว)
- อื่นๆ: เปิด exe ตรง
ถ้าเปิดไม่ได้ เมนูจะขึ้นแจ้งเตือนสีแดงพร้อมสาเหตุ

ต่อ API ทีหลัง
--------------
1. แก้ config.json -> "apiUrl": "http://<IP เซิร์ฟเวอร์>:<port>/api"   (ว่าง = ออฟไลน์)
   "machineId": ว่าง = ใช้ชื่อเครื่อง (เช่น KORI01)
   ไม่ต้อง build ใหม่ แค่เปิดโปรแกรมใหม่
2. ทุก request ส่ง header  X-Machine-ID: <ชื่อเครื่อง>  และ  Authorization: Bearer <token> (ถ้ามี)
   ตอบกลับเป็น JSON, HTTP 200 = สำเร็จ
3. endpoint ที่โปรแกรมเรียก (โค้ดอยู่ใน source\src\lib\api.js):
   จับเวลา   GET  /station/session?machineId=   POST /station/heartbeat  /station/lock  /station/logout
   เกม       GET  /games?category=&q=  (ถ้าตอบรายการเกม จะใช้แทน games.json)
             POST /games/launch  (แจ้งว่าเครื่องไหนเปิดเกมอะไร - ใช้ทำสถิติ)   POST /games/sync-save
   ร้านไอดี   GET  /shop/games   POST /shop/buy   GET /shop/inventory
   แชท      GET/POST /counter/chat
   เติมเงิน   GET  /billing/packages   POST /billing/promptpay
   สมาชิก    GET  /member/me   POST /member/redeem
   ระบบ     POST /system/mouse
   ถ้า API ล่ม/ไม่ได้ตั้ง: เมนูเกมยังใช้ games.json ต่อได้ตามปกติ
4. แก้หน้าตา/โค้ดใน source\ แล้วกด tools\Build-App.bat

หมายเหตุ
--------
- Launcher ทั้งหมดอยู่ที่ H:\OSYNC\GAMELUNCHER (ดู README-TH.txt ในนั้น)
- อัปเดตเกม/launcher ที่เครื่องแม่เท่านั้น แล้วกด Build-GameList ถ้ามีเกมเพิ่ม/ลด
- เครื่องลูกเห็นรายการเกมใหม่หลังรีบูต
