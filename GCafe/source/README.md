# 0JAYSHOP Client & Cyber Timer Application

โปรแกรมลูกข่ายจับเวลาและบริการหน้าร้านเกม/อินเทอร์เน็ตคาเฟ่ (0JAYSHOP Client) พัฒนาด้วย **Next.js 16.3 + React 19 + Electron 44**

---

## 🖥️ โครงสร้างสถาปัตยกรรม (Architecture)

1. **Dual-Window System (หน้าต่างคู่)**:
   - `mainWindow`: Floating HUD Widget ขนาดกะทัดรัด (310x460px) ชิดขวาบนของหน้าจอเสมอ (`alwaysOnTop`) แสดงเวลาที่เหลือ, สถานะเครื่อง, ความเร็ว LAN, ปุ่มเปิดเกมเมนู (Hero Game Launcher), เมนูบริการ และซ่อนปุ่มตั้งค่าให้สะอาดตา
   - `dialogWindow`: โมดอลกลางจอ (1080x680px) แบบไร้กรอบรองรับ Mac-controls (ย่อ/ขยาย/ปิด) พร้อมสลับแท็บเมนู:
     - 🕹️ **เกมเมนู (Game Launcher)**: แคตตาล็อกเกมแยกหมวดหมู่ (Hot, Steam, Riot, Epic, EA, Rockstar ฯลฯ), ค้นหาเกมเรียลไทม์, ปรับความไวเมาส์/เสียง, สุ่มเกม และ Cloud Save Sync (Zero Mock Data)
     - 🎮 **ซื้อไอดีเกม**: แคตตาล็อกรหัสเกมยอดฮิต (Valorant, RoV, Free Fire, Steam ฯลฯ), ตะกร้าสินค้า, ระบุช่องทางรับรหัส
     - 🔑 **คลังรหัสที่ซื้อ**: แสดงรายการรหัสเกมที่สั่งซื้อแล้ว พร้อมชื่อผู้ใช้, รหัสผ่าน (ซ่อน/แสดง) และปุ่มคัดลอกทันที
     - 💬 **แชทแอดมิน**: ส่งข้อความสื่อสารกับพนักงานเคาน์เตอร์หรือแอดมินร้าน 0JAYSHOP แบบเรียลไทม์
     - 💳 **เติมเงิน**: เลือกแพ็กเกจเวลา, ชำระผ่าน QR PromptPay

2. **System Tray ("Show hidden icons")**:
   - ปรากฏไอคอนในถาดระบบ Windows (System Tray / Show hidden icons) ทันทีเมื่อเปิดโปรแกรม
   - เมื่อกดปิด (`✕`) ที่หน้าต่าง HUD ตัวโปรแกรมจะซ่อนลง Tray แทนการปิดโปรเซส
   - คลิกหรือดับเบิ้ลคลิกไอคอนถาดระบบเพื่อกู้คืนหน้าต่างกลับขึ้นมาบนสุด (`AlwaysOnTop`) ทันที

3. **Internal HTTP Server (`electron/main.js`)**:
   - รัน HTTP Server ภายในบน `127.0.0.1:<random-port>` เพื่อให้บริการไฟล์จาก Next.js Static Export (`out/`) ทำให้ Asset bundles (`/_next/...`) โหลดได้สมบูรณ์บนทุกเครื่อง

---

## 🚀 วิธีการใช้งานและการติดตั้ง (Getting Started)

### ความต้องการของระบบ:
- Node.js 18+ (แนะนำ 20+)
- Windows 10 / 11 (x64)

### ติดตั้ง Dependencies:
```bash
npm install
```

### คำสั่งพัฒนาและทดสอบ:
```bash
# พัฒนาหน้าเว็บด้วย Next.js Dev Server
npm run dev

# บิลด์หน้าเว็บแบบ Static HTML
npm run build

# รันแอปพลิเคชันผ่าน Electron
npm start
```

### คำสั่งสร้างไฟล์ติดตั้ง (.exe):
```bash
npm run dist
```
ไฟล์โปรแกรมจะถูกสร้างไว้ที่ `dist\0JAYSHOP-win32-x64\0JAYSHOP.exe`

### การเปิดใช้งานแบบรวดเร็ว:
ดับเบิ้ลคลิกที่ไฟล์ `start.bat` ในโฟลเดอร์หลักของโปรเจกต์ ระบบจะปิดโปรเซสเดิมและเปิดโปรแกรมเวอร์ชันล่าสุดให้ทันที

---

## 🌐 การเชื่อมต่อ API Backend จริง (Real API Specification)

ตัวแอปพลิเคชันถูกแยกเลเยอร์ Service (`src/lib/api.js`) และ Configuration (`src/lib/config.js`) ออกจาก UI อย่างชัดเจน พร้อมเชื่อมต่อกับ REST API เซิร์ฟเวอร์หลัก

### การตั้งค่า Base URL:
- ค่าเริ่มต้น: `http://127.0.0.1:8000/api`
- สามารถกำหนดผ่าน Environment Variable: `NEXT_PUBLIC_API_URL`
- หรือกำหนดผ่าน Runtime Storage: `localStorage.setItem('0jayshop_api_url', 'http://your-server-ip:8000/api')`

### มาตรฐาน Headers ที่ระบบส่งไปกับทุก Request:
```http
Content-Type: application/json
X-Machine-ID: PC-12
Authorization: Bearer <token>
```

---

### รายการ Endpoints ที่รองรับ:

#### 1. Session & Station (`sessionService`)
- **`GET /station/session?machineId={id}`**
  - คืนค่า: ข้อมูลเครื่องและเวลา
  ```json
  {
    "machineId": "PC-12",
    "username": "PLAYER_ONE",
    "tier": "VIP Gold",
    "totalSec": 12600,
    "usedSec": 2723,
    "lanSpeed": "1Gbps LAN"
  }
  ```
- **`POST /station/heartbeat`**
  - ส่งทุก 30 วินาที เพื่ออัปเดตเวลาที่ใช้งาน (`usedSec`)
- **`POST /station/logout`**
  - บันทึกเวลาที่เหลือลงบัญชีและจบเซสชัน

#### 2. Game ID Shop & Inventory (`gameShopService`)
- **`GET /shop/games?category={all|valorant|rov|freefire|pointblank|steam}`**
  - คืนค่า: รายการไอดีเกมตามหมวดหมู่
  ```json
  [
    {
      "id": 1,
      "name": "[VALORANT] มีด Kuronami + Vandal Prime",
      "category": "valorant",
      "price": 350,
      "tag": "💎 Diamond 3",
      "img": "https://...",
      "desc": "เซิร์ฟไทย / สกินแรร์ 15 ชิ้น / สะอาดไม่เคยแบน / พร้อมเปลี่ยนเมล"
    }
  ]
  ```
- **`POST /shop/buy`**
  - สั่งซื้อไอดีเกม
  ```json
  {
    "machineId": "PC-12",
    "items": [{ "id": 1, "name": "...", "price": 350, "qty": 1 }],
    "total": 350,
    "contact": "Discord: player#1234 หรือ 0812345678",
    "note": "ส่งข้อมูลเข้าคลังทันที"
  }
  ```
- **`GET /shop/inventory?machineId={id}`**
  - ดึงรายการรหัสเกมที่สั่งซื้อแล้วของเครื่องหรือสมาชิกนี้

#### 3. Counter Chat (`chatService`)
- **`GET /counter/chat?machineId={id}`**
  - ดึงประวัติการแชทระหว่างเครื่องกับเคาน์เตอร์
- **`POST /counter/chat`**
  - ส่งข้อความแจ้งเคาน์เตอร์ `{ "machineId": "PC-12", "text": "..." }`

#### 4. Billing & Topup (`topupService`)
- **`GET /billing/packages`**
  - ดึงรายการแพ็กเกจเวลา
- **`POST /billing/promptpay`**
  - สร้างคำสั่งชำระเงิน PromptPay QR

#### 5. Member Profile (`memberService`)
- **`GET /member/me`**
  - ข้อมูลสมาชิก, แต้มสะสม G-Point, สิทธิ์ VIP
- **`POST /member/redeem`**
  - แลกสิทธิพิเศษด้วยแต้ม

*หมายเหตุ: ระบบทำงานแบบเชื่อมต่อ API จริง 100% ปราศจากข้อมูล Mock หากยังไม่มี API เซิร์ฟเวอร์รันอยู่ หน้าจอจะแสดงสถานะกำลังโหลด (Loading Spinner) หรือสถานะว่าง (Empty State) โดยไม่แครช*

---

## 🎨 การตั้งค่าแบรนด์และระบบ (Admin Settings)

เพื่อความเรียบร้อยและป้องกันผู้ใช้ทั่วไปกดเล่น ปุ่มตั้งค่าถูกซ่อนออกจากหน้าจอหลัก:
- **วิธีเปิดหน้าต่างตั้งค่า**:
  - กดคีย์ลัด: `Ctrl + Shift + S`
  - หรือ **คลิกขวาที่โลโก้ร้าน (0JAYSHOP)** บริเวณมุมซ้ายบนของ HUD Widget
- **รายการที่ปรับแต่งได้**:
  - **ชื่อร้าน / แบรนด์ (Brand Name)**: ค่าเริ่มต้น `0JAYSHOP`
  - **ป้ายข้อความ (Badge Tag)**: ค่าเริ่มต้น `VIP`
  - **URL รูปโลโก้ (Logo Image URL)**: ใส่ลิงก์รูปภาพโลโก้
  - **รหัสเครื่อง (Station ID)**: เช่น `PC-01`, `PC-12`
  - **URL เซิร์ฟเวอร์ API (API Base URL)**: กำหนด IP/Domain ของ Backend จริงได้ทันที

---

## 📐 กฎดีไซน์ UI & Corner Radius Hierarchy

เพื่อให้หน้าต่างโปร่งใสและทรงไซเบอร์ แสดงผลคมกริบ ไม่เกิดขอบล้น (Border Bleeding) หรือเหลี่ยมตัด:
- **หน้าต่างนอกสุด (Windows)**: `16px`
- **แผงควบคุมหลัก & HUD (Panels)**: `12px`
- **การ์ดเมนู & กล่องเนื้อหา (Cards)**: `10px`
- **ปุ่มกดและกล่องป้อนข้อมูล (Buttons & Inputs)**: `8px`
- **ปุ่มขนาดเล็ก (Mini Action Buttons)**: `6px`
- **ป้ายสถานะ & แทร็กหลอดเวลา (Pills & Badges)**: `999px`

---

## 📁 โครงสร้างโฟลเดอร์ในโปรเจกต์ (Clean Structure)

```
หน้าตาโปรแกรมจับเวลา/
├── electron/
│   ├── main.js        # ตัวจัดการหน้าต่างและเซิร์ฟเวอร์ภายใน
│   └── preload.js     # Context Bridge สำหรับความปลอดภัย
├── src/
│   ├── app/
│   │   ├── dialog/
│   │   │   └── page.jsx   # หน้าต่างโมดอลกลางจอ (5 แท็บหลัก)
│   │   ├── globals.css    # สไตล์ Cyber Dark ธีมทั้งหมด
│   │   ├── layout.jsx     # Root Layout
│   │   └── page.jsx       # หน้าต่าง HUD Widget ฝั่งขวา
│   └── lib/
│       ├── api.js         # REST API Client (Zero Mock Data) เชื่อมต่อเซิร์ฟเวอร์จริง
│       └── config.js      # การตั้งค่า Base URL และ Station ID
├── next.config.js     # คอนฟิก Static Export ของ Next.js
├── package.json       # Dependencies และ Scripts
├── README.md          # เอกสารวิธีการใช้งานและสเปก API
└── start.bat          # สคริปต์เปิดใช้งานโปรแกรมทันที
```
