Menu\ - โปรแกรมเมนูเกมเครื่องลูก "0JAYSHOP Client"        อัปเดต 20 พ.ย. 2026
=====================================================================
เมนูเกมที่ลูกค้าเห็นบนเครื่องลูก (Electron + Next.js) อ่านรายชื่อเกมจาก data\games.json
ร้านนี้ใช้แบบ "เมนูเกมอย่างเดียว ออฟไลน์": config.json  apiUrl = ""  และ  ui.menuOnly = true
(ไม่มีหน้าต่างนับเวลา ไม่มีแท็บร้าน ไม่มีหน้าล็อก)

เอกสารเต็ม (ทีละฟังก์ชัน)   System\Docs\06-MENU.md
ระบบร้าน / ระบบเวลา        System\Docs\SHOP-API.md
ปุ่ม "ขอเกม" Steam          System\Docs\STEAM-REQUESTS.md
ระดับภาพ GTA V / FiveM      System\Docs\GTA-GRAPHICS.md

โฟลเดอร์
--------
app\                ตัวโปรแกรม app\<ชื่อร้าน>.exe (ตอนนี้ 0JAYSHOP.exe) - Build-App สร้าง ห้ามแก้เอง
config.json         ค่าของร้าน: ชื่อร้าน โลโก้ หน้าตาเมนู เกมที่ถามระดับภาพ ปุ่มขอเกม (UTF-8)
data\games.json     รายชื่อเกม - เครื่องแม่เขียนเอง (System\Scripts\Master-GameList.ps1) ห้ามแก้เอง
data\posters\       รูปปกที่ใส่เอง ชื่อไฟล์ = id ของเกม เช่น riot-valorant.jpg
                    (_auto\ = ปกที่ทำให้อัตโนมัติ ไม่ต้องยุ่ง)
data\brand\         logo.png + app.ico (ทำด้วย Make-Brand.ps1) + source.jpg
source\             ซอร์สโค้ด (ดู source\README.md)
tools\Build-App.bat build โปรแกรมใหม่จาก source\ ลง app\
tools\_system\      Build-App.ps1 AppName.ps1 Set-ExeInfo.mjs Set-ExeIcon.ps1 Make-Brand.ps1 imagetool\
_build\             electron-runtime\ (ใช้ตอน build) + selftest\ (ผลทดสอบหลัง build)

ทำอะไร ที่ไหน
-------------
เพิ่ม / ลบเกม             ลงเกมที่เครื่องแม่ แล้ว OSYNC.bat > 1 (เขียน data\games.json ใหม่)
เกมที่หาเองไม่เจอ         Settings\extra-games.json แล้ว OSYNC.bat > 1
แก้ชื่อ / หมวด / ซ่อนเกม   Settings\extra-games.json ตาม id (ดู id ใน data\games.json) แล้ว OSYNC.bat > 1
เปลี่ยนรูปปก              ใส่ data\posters\<id>.jpg (หรือ .png .webp) แล้ว OSYNC.bat > 1
แก้ config.json           Notepad หรือคอนโซล OSYNC แท็บ "ระบบร้าน" - ไม่ต้อง build ใหม่
                          (ยกเว้น brandName = ชื่อไฟล์ exe) · JSON พัง = ทุกค่ากลับเป็นค่าเริ่ม
เปลี่ยนโลโก้ / ไอคอน      powershell -ExecutionPolicy Bypass -File tools\_system\Make-Brand.ps1 -Image <รูป>
                          [-CenterX 0.5 -CenterY 0.5 -Radius 0.48]  แล้ว build ใหม่
build โปรแกรมใหม่         (หลังแก้ source\ / โลโก้ / brandName) OSYNC.bat > 7 > 3  หรือ  tools\Build-App.bat
                          ทำที่เครื่องแม่ ปิดเมนูบนเครื่องแม่ก่อน ตอนท้ายเปิดเมนูทดสอบเองแล้วปิด
ติดตั้งบนเครื่องลูก        OSYNC.bat > 5 (โหมด super แล้วบันทึก Image): ทางลัดใน StartUp + เดสก์ท็อป
                          ชี้ไป System\Client\Menu.vbs (ซ่อมเองทุกบูต)

ข้อควรรู้
--------
- เครื่องลูก (diskless) เห็นไฟล์ที่เครื่องแม่แก้ (config.json, games.json, app\) หลังรีบูตเท่านั้น
- ปุ่มปิดของเมนูแค่ย่อลงแถบงาน · ไม่มีปุ่มออกจากโปรแกรม (ตั้งใจ)
- ตั้ง apiUrl อย่างเดียวไม่ได้เปิดร้านไอดี / เติมเงิน / แชท - อ่าน System\Docs\SHOP-API.md ก่อน
