# OSYNC — ระบบเกมสำหรับร้านเกม diskless (0JAYSHOP)

ใช้บน **เครื่องแม่ (master)** ของร้านที่ใช้ diskless (LW / Kritidet) วางโฟลเดอร์ไว้บนไดรฟ์เกมที่เครื่องลูกมองเห็น
เครื่องลูกจึงใช้ path เดียวกับเครื่องแม่ได้ เช่น `H:\OSYNC\...`

## ปุ่มหลัก (กดแค่ 2 ปุ่มนี้)
| ปุ่ม | กดที่ | เมื่อไร |
|---|---|---|
| `MASTER-Update-All.bat` | เครื่องแม่ | หลังติดตั้ง / อัปเดต / ลบเกม (ปิด Riot Client ก่อนถ้าเกม Riot ยังอัปเดตอยู่) — อัปเดตข้อมูล Riot, EA, Epic, EasyAntiCheat ให้เครื่องลูก และสแกนรายการเกมในเมนูใหม่ |
| `CLIENT-Install-All.bat` | เครื่องลูก 1 เครื่อง ในโหมด super workstation (แก้ Image) แล้ว **บันทึก Image** | ครั้งแรก และทุกครั้งที่ลงเกมใหม่ — Riot แบบเงียบ, สิ่งที่ Steam ติดตั้งตอนเปิดเกมครั้งแรก (กันโกง BattlEye/ACE/Ricochet/EasyAntiCheat, Social Club, DirectX, VC++), EA app + เกม EA + EA AntiCheat, EasyAntiCheat ของ Epic, เมนูเกม 0JAYSHOP |

ผลการติดตั้งที่เครื่องลูกเก็บไว้ที่ `C:\Users\Public\OSYNC-Install-All.log` (รันซ้ำได้ ของที่ทำแล้วจะข้าม)

## ลงเกมใหม่ในอนาคต
| เกมจาก | ติดตั้งที่เครื่องแม่ | แล้วกด |
|---|---|---|
| Steam | ลงใน `X:\SteamLibrary` ของไดรฟ์ที่เครื่องลูกเห็น | `MASTER-Update-All.bat` → `CLIENT-Install-All.bat` ที่เครื่องลูก (โหมดแก้ Image) |
| Riot (VALORANT/LoL/TFT) | อัปเดตใน Riot Client จนขึ้น Play แล้วปิด Riot Client | `MASTER-Update-All.bat` |
| Epic | ลงในไดรฟ์ที่เครื่องลูกเห็น เช่น `X:\EPIC\<เกม>` | `MASTER-Update-All.bat` → `CLIENT-Install-All.bat` |
| EA app | ลงในไดรฟ์ที่เครื่องลูกเห็น เช่น `X:\EA\<เกม>` | `MASTER-Update-All.bat` → `CLIENT-Install-All.bat` (เมนูจะเปิด EA app ให้กด Play; ถ้ารู้ offer id ใส่ใน `GCafe\tools\_system\Build-GameList.ps1` แล้วเปิดเกมตรงได้) |
| เกมออนไลน์ / มือถือ / Garena / โปรแกรม | วางโฟลเดอร์เกมใน `X:\Online\<เกม>`, `X:\Mobile\<เกม>`, `X:\PvP\<เกม>`, `X:\Single Player\<เกม>` หรือ `X:\Web\<โปรแกรม>` | `MASTER-Update-All.bat` — เมนูหา exe ให้เอง (ดูบรรทัด `AUTO added ...` ว่าเลือกถูกไหม ถ้าผิดเพิ่มใน `GCafe\data\games.custom.json`) |
| Ubisoft / Rockstar / Battle.net (ไม่ผ่าน Steam) | ยังไม่รองรับอัตโนมัติ — ใช้เวอร์ชัน Steam ถ้ามี | ให้ AI ช่วยเพิ่ม |

รูปปก: Steam ใช้รูปจาก Steam, เกมอื่นใช้ `zPoster.jpg` ในโฟลเดอร์เกม หรือทำจากไอคอนให้เอง, ใส่รูปเองได้ที่ `GCafe\data\posters\<id>.jpg`

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
