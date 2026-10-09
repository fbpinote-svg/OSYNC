# OSYNC — ระบบเกมสำหรับร้านเกม diskless (0JAYSHOP)

ใช้บน **เครื่องแม่ (master)** ของร้านที่ใช้ diskless (LW / Kritidet) วางโฟลเดอร์ไว้บนไดรฟ์เกมที่เครื่องลูกมองเห็น
เครื่องลูกจึงใช้ path เดียวกับเครื่องแม่ได้ เช่น `H:\OSYNC\...`

## ปุ่มหลัก (กดแค่ 2 ปุ่มนี้)
| ปุ่ม | กดที่ | เมื่อไร |
|---|---|---|
| `MASTER-Update-All.bat` | เครื่องแม่ | หลังติดตั้ง / อัปเดต / ลบเกม (ปิด Riot Client ก่อนถ้าเกม Riot ยังอัปเดตอยู่) — อัปเดตข้อมูล Riot, EA, Epic, EasyAntiCheat ให้เครื่องลูก และสแกนรายการเกมในเมนูใหม่ |
| `CLIENT-Install-All.bat` | เครื่องลูก 1 เครื่อง ในโหมด super workstation (แก้ Image) แล้ว **บันทึก Image** | ครั้งแรก, และเมื่อมีเกม EA หรือเกมที่ใช้กันโกงเพิ่ม — ติดตั้ง Riot แบบเงียบ, EA app + เกม EA + EA AntiCheat, EasyAntiCheat, เมนูเกม 0JAYSHOP |

ผลการติดตั้งที่เครื่องลูกเก็บไว้ที่ `C:\Users\Public\OSYNC-Install-All.log`

## โครงสร้างโฟลเดอร์
```
OSYNC\
  MASTER-Update-All.bat     ปุ่มเครื่องแม่
  CLIENT-Install-All.bat    ปุ่มเครื่องลูก
  _system\                  สคริปต์ของ 2 ปุ่มบน
  GAMELUNCHER\              ตัวโปรแกรม launcher ทุกค่าย (ห้ามย้าย/เปลี่ยนชื่อ) + ClientSetup\
    ClientSetup\
      VALORANT.bat ... RiotSilent.vbs, EpicSilent.vbs   ตัวเปิดเกมที่เมนูเรียกใช้ (ห้ามย้าย)
      Install-Client\       ปุ่มติดตั้งเครื่องลูกทีละอย่าง (ใช้ตอนแก้ปัญหา)
      Update-Master\        ปุ่มอัปเดตเครื่องแม่ทีละอย่าง
      Master-Move\          ย้าย launcher ที่ติดตั้งใน C: มาไว้ใน GAMELUNCHER
      Diagnose\             ตรวจปัญหาที่เครื่องลูก (RiotDiag, LinkScan)
      _system\              สคริปต์และข้อมูล
      README-TH.txt         คู่มือ launcher
  GCafe\                    โปรแกรมเมนูเกม 0JAYSHOP — คู่มือ GCafe\README-TH.txt
  Riot Games\               ตัวเกม VALORANT (ไม่อยู่ใน git)
```

สิ่งที่ **ไม่อยู่ใน git** (แต่ละเครื่องแม่สร้างเอง): ตัวเกม, ตัวโปรแกรม launcher, `GCafe\app` (โปรแกรมที่ build แล้ว),
`GCafe\data\games.json` และรูปปกอัตโนมัติ, ข้อมูล snapshot ของ Riot/EA/Epic/EasyAntiCheat — ดู `.gitignore`

## เริ่มที่สาขาใหม่
1. ติดตั้ง Git แล้ว clone ลงไดรฟ์เกมที่เครื่องลูกเห็น เช่น `git clone https://github.com/fbpinote-svg/OSYNC.git F:\OSYNC`
2. เปิด Claude Code ในโฟลเดอร์นั้น แล้วให้ทำตาม `SETUP-AI.md`

## อัปเดตจากเครื่องแม่หลัก
```
cd /d H:\OSYNC
git add -A
git commit -m "อธิบายสิ่งที่เปลี่ยน"
git push
```
สาขาอื่นดึงของใหม่: `git pull` แล้วกด `GCafe\tools\Build-App.bat` (ถ้ามีแก้ source) และ `MASTER-Update-All.bat`
