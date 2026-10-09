# OSYNC — ระบบเกมสำหรับร้านเกม diskless (0JAYSHOP)

ระบบนี้ใช้บน **เครื่องแม่ (master)** ของร้านที่ใช้ diskless (LW / Kritidet) โดยวางโฟลเดอร์ไว้บนไดรฟ์เกมที่เครื่องลูกมองเห็น
เครื่องลูกจึงเรียกใช้ path เดียวกับเครื่องแม่ได้ เช่น `H:\OSYNC\...`

| โฟลเดอร์ | หน้าที่ |
|---|---|
| `GAMELUNCHER\ClientSetup\` | ชุดปุ่มรวม launcher (Riot, EA, Epic, Garena, Rockstar, Ubisoft, HoYoPlay, Modrinth): ย้าย launcher มารวมกัน, เตรียมเครื่องลูก, ตัวเปิดเกมแบบเงียบ — อ่าน `README-TH.txt` ในนั้น |
| `GCafe\` | โปรแกรมเมนูเกมของเครื่องลูก (0JAYSHOP, Electron + Next.js) ทำงานแบบออฟไลน์ อ่านรายการเกมจาก `data\games.json` — อ่าน `README-TH.txt` ในนั้น |
| `SETUP-AI.md` | คู่มือทีละขั้นสำหรับ AI (Claude Code) ที่จะติดตั้งระบบนี้บนเครื่องแม่อีกสาขา |

สิ่งที่ **ไม่อยู่ใน git** (แต่ละเครื่องแม่สร้างเอง): ตัวเกม, ตัวโปรแกรม launcher, `GCafe\app` (โปรแกรมที่ build แล้ว),
`GCafe\data\games.json` และรูปปกอัตโนมัติ, ข้อมูล snapshot ของ Riot/EA/Epic — ดู `.gitignore`

## เริ่มที่สาขาใหม่
1. ติดตั้ง Git แล้ว clone ลงไดรฟ์เกมที่เครื่องลูกเห็น เช่น `git clone <repo url> F:\OSYNC`
2. เปิด Claude Code ในโฟลเดอร์นั้น แล้วให้ทำตาม `SETUP-AI.md`

## อัปเดตจากเครื่องแม่หลัก
```
cd /d H:\OSYNC
git add -A
git commit -m "อธิบายสิ่งที่เปลี่ยน"
git push
```
สาขาอื่นดึงของใหม่: `git pull` แล้วกด `GCafe\tools\Build-App.bat` (ถ้ามีแก้ source) และ `GCafe\tools\Build-GameList.bat`
