GAMELUNCHER - คู่มือใช้งาน (อัปเดต 8 ต.ค. 2026)
================================================

โครงสร้างโฟลเดอร์
-----------------
H:\OSYNC\GAMELUNCHER\
  RiotClient\        ตัวโปรแกรม Riot Client    ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  EA Desktop\        ตัวโปรแกรม EA app         ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  Epic Games\        ตัวโปรแกรม Epic         ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  Garena\            ตัวโปรแกรม Garena       ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  Rockstar Games Launcher\   ตัวโปรแกรม Rockstar      ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  Ubisoft\           ตัวโปรแกรม Ubisoft Connect  ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  HoYoPlay\          ตัวโปรแกรม HoYoPlay (Genshin/Star Rail/ZZZ)  ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  Modrinth App\      ตัวโปรแกรม Modrinth (Minecraft)  ** ห้ามย้าย / ห้ามเปลี่ยนชื่อ **
  ClientSetup\       ปุ่มต่างๆ (อธิบายด้านล่าง)
  ClientSetup\settings.txt   ตัวอักษรไดรฟ์เกมที่เครื่องลูกเห็น (SharedDrives=DEFGHIJ ตามที่ตั้งใน LW)
  _archive\          ของเก่า/สำรอง (สคริปต์ย้าย EA, ไฟล์สำรองเดิม) ไม่ต้องใช้

H:\OSYNC\Riot Games\VALORANT     ตัวเกม VALORANT
H:\RIOT\Riot Games\              ตัวเกม League of Legends / Teamfight Tactics
H:\Mobile\Genshin Impact\        ตัวเกม Genshin (ย้ายออกจาก HoYoPlay\games เมื่อ 8 ต.ค. 2026)


ClientSetup\  (ปุ่มที่กดได้)
---------------------------
[ เปิดเกม - ให้เมนูเกมของเครื่องลูกเรียกไฟล์เหล่านี้ ]
  VALORANT.bat
  League of Legends.bat
  Teamfight Tactics.bat
  Riot Client.bat
  RiotSilent.vbs      ตัวเปิดแบบไม่มีหน้าต่าง ใช้ในเมนูได้เช่นกัน:
                      wscript.exe H:\OSYNC\GAMELUNCHER\ClientSetup\RiotSilent.vbs valorant
  EpicSilent.vbs      เปิดเกม Epic (เช่น Fortnite) บนเครื่องลูก: ใส่รายการเกม Epic ของเครื่องแม่ให้ก่อน แล้วเปิดผ่าน Epic
                      wscript.exe H:\OSYNC\GAMELUNCHER\ClientSetup\EpicSilent.vbs Fortnite
                      (ลูกค้าล็อกอินบัญชี Epic ของตัวเองครั้งแรก)

[ Install-Client\ - กด "ครั้งเดียว" ที่เครื่องลูกในโหมด super workstation (แก้ Image) แล้วบันทึก Image ]
  Riot-Startup-Install.bat     เปิด Riot Client แบบเงียบที่ถาดไอคอนตอนล็อกอิน
                               (คลิกขวา Run as administrator = ทุกผู้ใช้)
  Riot-Startup-Uninstall.bat   เอาออก
  EA-Install.bat               ติดตั้ง EA app + ลงทะเบียนเกม EA ที่ติดตั้งไว้ให้เครื่องลูก + ติดตั้ง EA AntiCheat (ขอสิทธิ์ admin เอง)
  EA-AntiCheat-Install.bat     ติดตั้งเฉพาะ EA AntiCheat (Apex / Battlefield V / Battlefield 6)
                               อาการถ้าไม่มี: กดเล่น Apex แล้วขึ้นรูป Apex "Checking for updates..." แล้วปิดไปเอง
  EA-Install-Autostart.bat     เหมือนข้างบน + เปิด EA แบบเงียบตอนล็อกอิน
  EA-Uninstall.bat             เอาออก

[ Update-Master\ - กดที่ "เครื่องแม่" หลังอัปเดตเกม ]
  Riot-Update-ClientData.bat   หลังอัปเดต VALORANT / League / TFT ใน Riot Client จนขึ้น Play
                               (ปิด Riot Client ก่อนกด)
  Export-Kit.bat               แพ็กชุดนี้เป็น zip (GAMELUNCHER-Kit_วันที่.zip) ไว้ส่งไปสาขาอื่น
  Epic-Update-ClientData.bat   หลังติดตั้ง/อัปเดตเกมผ่าน Epic (เช่น Fortnite ที่ J:\EPIC) ให้เครื่องลูกรู้ว่ามีเกม
  EA-Update-ClientData.bat     หลังติดตั้ง/อัปเดตเกมผ่าน EA app (เช่น Apex ที่ I:\EA) หรือ EA app อัปเดตเวอร์ชัน
                               แล้วกด Install-Client\EA-Install.bat ซ้ำที่เครื่องลูก (โหมดแก้ Image)

[ Master-Move\ - ย้าย launcher ที่ติดตั้งใน C: ของเครื่องแม่มาไว้ใน GAMELUNCHER (ครั้งเดียว) ]
  Move-Riot.bat / Move-EA.bat / Move-Epic.bat / Move-Rockstar.bat / Move-Garena.bat
  Move-Ubisoft.bat / Move-HoYoPlay.bat / Move-Modrinth.bat
                               หาตำแหน่งติดตั้งเดิมเองจาก Registry -> แสดงรายการ -> กด Y เพื่อย้ายจริง
                               (ขอสิทธิ์ admin เอง; ถ้าย้ายแล้วจะขึ้นว่า already in GAMELUNCHER)
                               ถ้าอยู่ไดรฟ์เดียวกันจะเปลี่ยนชื่อโฟลเดอร์ (เสร็จทันที ไม่ก๊อปปี้)
                               HoYoPlay: เกมใน HoYoPlay\games จะถูกย้ายไป <ไดรฟ์>:\Mobile\<ชื่อเกม>
                               แล้วเปิด HoYoPlay -> ถ้าเกมขึ้นปุ่มดาวน์โหลด ให้เลือก "ค้นหาเกม/Locate game"
                               ชี้ไปที่โฟลเดอร์เกมใหม่ (HoYoPlay จำตำแหน่งเกมในไฟล์ของมันเอง)
[ Diagnose\ - กดที่เครื่องลูกเมื่อมีปัญหา แล้วถ่ายรูป Notepad ส่งมา ]
  RiotDiag.bat                 Riot ขึ้น Repair / หาเกมไม่เจอ
  LinkScan.bat                 หาลิงก์โฟลเดอร์ที่เสีย (ของเก่าจาก AutoSync)

[ _system\ - สคริปต์และข้อมูลที่ปุ่มข้างบนเรียกใช้ ไม่ต้องเปิดเอง ]


กฎสำคัญ
--------
1. อัปเดตเกม / launcher ที่เครื่องแม่เท่านั้น เครื่องลูกอัปเดตเองจะหายตอนรีบูต
2. หลังย้าย/อัปเดตไฟล์บนไดรฟ์เกมระหว่างร้านเปิด ให้เครื่องลูกที่เปิดค้างรีบูตก่อนเล่น
3. Riot Vanguard และ EasyAntiCheat ควรติดตั้งไว้ใน Image ของเครื่องลูก
4. เปิดเกม Riot ผ่านปุ่มในโฟลเดอร์นี้เสมอ (มันซ่อมลิงก์เก่าที่เสียให้อัตโนมัติก่อนเปิดเกม)

ติดตั้งที่สาขาใหม่ (ไดรฟ์ไม่เหมือนกันได้)
=====================================
1. ในโปรแกรมจัดการ diskless ของสาขานั้น ดูว่าเครื่องลูกเห็นไดรฟ์เกมเป็นตัวอักษรอะไร
   (ต้องตรงกับตัวอักษรบนเครื่องแม่) แล้วเลือกไดรฟ์ 1 ลูก เช่น F:
2. แตก GAMELUNCHER-Kit_xxxx.zip ไว้ที่ F:\OSYNC  ->  จะได้ F:\OSYNC\GAMELUNCHER\ClientSetup
   (วางไว้ไดรฟ์/โฟลเดอร์ไหนก็ได้ ขอแค่เป็นไดรฟ์ที่เครื่องลูกเห็น)
3. แก้ ClientSetup\settings.txt  ->  SharedDrives=ตัวอักษรไดรฟ์เกมของสาขานั้น (เช่น SharedDrives=DEFG)
4. ติดตั้ง Riot Client / EA app / Epic / Rockstar / Garena / Ubisoft / HoYoPlay บนเครื่องแม่ตามปกติ
   แล้วกด Master-Move\Move-*.bat ทีละตัว -> ย้ายเข้า GAMELUNCHER
5. ติดตั้งเกมลงไดรฟ์เกม (ต้องเป็นไดรฟ์ใน SharedDrives) เปิดจนขึ้น Play
6. กด Update-Master\Riot-Update-ClientData.bat, EA-Update-ClientData.bat และ Epic-Update-ClientData.bat
7. ที่เครื่องลูก (โหมด super workstation) กดปุ่มใน Install-Client\ แล้วบันทึก Image
8. ตั้งเมนูเกมให้เรียก ClientSetup\VALORANT.bat ฯลฯ
   (โปรแกรมเมนูเกม GCafe ทำให้อัตโนมัติ: ดู H:\OSYNC\GCafe\README-TH.txt)