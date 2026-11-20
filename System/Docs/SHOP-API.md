# SHOP-API — ต่อเซิร์ฟเวอร์ของร้านเข้ากับเมนูเกม 0JAYSHOP Client

เอกสารสำหรับนักพัฒนา backend ที่จะต่อ **"ระบบซื้อขายรหัส"** (ร้านไอดีเกม + คลังรหัส) และ **"ระบบเวลาต่างๆ ของร้าน"** (เวลาเล่น, หน้าล็อก, เติมเงิน/ต่อเวลา) เข้ากับโปรแกรมเมนูเกมบนเครื่องลูก

- โปรแกรม: Electron 44 + Next.js 16 (static export) ชื่อ "0JAYSHOP Client" — ตัวโปรแกรม `Menu\app\`, ซอร์ส `Menu\source\`, ค่าของร้าน `Menu\config.json`
- เขียนจากโค้ดจริงชุดที่ build เมื่อ 17 พ.ย. 2026 **ไม่ได้เขียนจาก README** · เลข `ไฟล์:บรรทัด` ในเอกสารนี้นับจากโค้ดวันนั้น โค้ดที่แก้หลังจากนั้นอาจเลื่อนไปไม่กี่บรรทัด (เช่น `main.js` เลื่อนราว 2 บรรทัดหลังเพิ่มปุ่มขอเกม 19 พ.ย.) — บรรทัดล่าสุดของทุกฟังก์ชันดูที่ [10-FUNCTION-INDEX.md](10-FUNCTION-INDEX.md) และ [06-MENU.md](06-MENU.md)
- อะไรที่โค้ดไม่ได้กำหนด เขียนว่า **ไม่ระบุในโค้ด** · คำแนะนำของผู้เขียนติดป้าย **(ข้อแนะนำ)**
- ตอนนี้ทุกระบบปิดอยู่: `apiUrl` ว่าง, `ui.menuOnly: true`, `ui.sidePanel: false` และเครื่องลูกยังไม่มีเอเจนต์ของระบบร้าน

การอ้างอิงบรรทัด (`ไฟล์:บรรทัด`) นับจาก `Menu\source\`:

| ชื่อย่อ | ไฟล์ |
|---|---|
| `main.js` | `electron/main.js` |
| `preload.js` | `electron/preload.js` |
| `api.js` | `src/lib/api.js` |
| `config.js` | `src/lib/config.js` |
| `totp.js` | `src/lib/totp.js` |
| `app/page.jsx` | `src/app/page.jsx` — HUD (หน้าต่างนับเวลาเล็กมุมขวา) |
| `dialog/page.jsx` | `src/app/dialog/page.jsx` — เมนูเกม + แท็บร้าน |
| `lock/page.jsx` | `src/app/lock/page.jsx` — หน้าล็อกเต็มจอ |
| `ShopTabs.jsx` | `src/components/ShopTabs.jsx` — แท็บซื้อไอดี / คลังรหัส / แชท / เติมเงิน-ต่อเวลา / บัญชี |
| `TopupPanel.jsx` | `src/components/TopupPanel.jsx` — กล่องเติมเงิน PromptPay |

สารบัญ

0. สรุปก่อนอ่าน — เมนูมีทางต่อเซิร์ฟเวอร์ 2 ทาง
1. วิธีเปิดใช้
2. พื้นฐานของ request
3. รายการ endpoint ทั้งหมด
4. Flow ของเวลา (หมดเวลา, หน้าล็อก, PIN/TOTP, ใครเป็นเจ้าของเวลา)
5. Flow ร้านไอดี (ระบบซื้อขายรหัส)
6. ความปลอดภัยที่ backend ต้องทำ
7. Checklist และแผนทดสอบขั้นต่ำ (มีตัวอย่าง curl)
8. ยังไม่ชัด / ข้อสังเกตในโค้ดเมนู

---

## 0. สรุปก่อนอ่าน — เมนูมีทางต่อเซิร์ฟเวอร์ 2 ทาง

โค้ดเมนูมีทางคุยกับเซิร์ฟเวอร์ **2 ทางที่แยกกันโดยสิ้นเชิง** ใช้ URL, การยืนยันตัวตน และหน้าจอคนละชุด

| | ทาง A — `apiUrl` (REST ตรงจากหน้าเมนู) | ทาง B — ระบบร้านผ่านเอเจนต์ (Cooper Agent รุ่น 1.20 ขึ้นไป) |
|---|---|---|
| เปิดด้วย | `Menu\config.json` → `apiUrl` | ไฟล์ `%ProgramData%\CooperAgent\gcafe.json` + `state.json` ที่เอเจนต์บนเครื่องลูกเขียน (ไม่ได้อยู่ใน `config.json`) |
| ใครยิง request | หน้าเว็บในเมนู (renderer, `fetch` ของ Chromium) → **ต้องมี CORS** | โปรเซสหลักของ Electron (`main.js`, `fetch` ของ Node) → ไม่เกี่ยวกับ CORS |
| URL | `<apiUrl><path>` เช่น `<apiUrl>/station/session` | `<server>/api/gcafe/<ชื่อ>` เช่น `<server>/api/gcafe/shop` |
| ระบุ / ยืนยันเครื่อง | header `X-Machine-ID` (= ชื่อเครื่อง) — **ไม่มี token จริง** | `Authorization: Bearer gt_…` token ของเครื่องนั้น |
| หน้าจอที่ใช้ทางนี้จริง | HUD: ดึงเวลา, heartbeat, ออกจากระบบ · เมนูเกม: รายชื่อเกม, รายงานการเปิดเกม | หน้าล็อก, เวลาบน HUD และเมนู, ซื้อไอดี, คลังรหัส, เติมเงิน/ต่อเวลา (PromptPay), แชทร้าน, บัญชี, สถิติเปิดเกม |
| โค้ด | `api.js`, `config.js` | `main.js:158-305`, `preload.js:40-45`, `ShopTabs.jsx`, `TopupPanel.jsx`, `lock/page.jsx` |

สิ่งที่ตามมา (สำคัญ):

1. **ตั้ง `apiUrl` อย่างเดียว ร้านไอดี / คลังรหัส / เติมเงิน / แชท / บัญชี จะยังใช้ไม่ได้** — แท็บเหล่านี้ใช้ทาง B เท่านั้น ถ้าเอเจนต์ไม่พร้อมจะขึ้นกล่อง "ต้องเชื่อมระบบร้าน" (`ShopTabs.jsx:725-732`) ฟังก์ชัน REST ของร้านไอดี/แชท/เติมเงิน/สมาชิกใน `api.js` มีอยู่ แต่ไม่มีหน้าจอไหนเรียก (ข้อ 3.A)
2. **ทาง A ไม่มีหน้าล็อก** เวลาหมดแล้วเมนูไม่ล็อก ไม่ออกจากระบบ (ข้อ 4.1) — หน้าล็อกมีเฉพาะทาง B
3. ถ้าจะให้หน้าจอที่มีอยู่แล้วทำ "ระบบซื้อขายรหัส" + "ระบบเวลา" ได้ **โดยไม่แก้โค้ดเมนู** = ต้องทำตามสัญญาทาง B ทั้งสองฝั่ง: เซิร์ฟเวอร์ `/api/gcafe/*` (ข้อ 3.B) และโปรแกรมบนเครื่องลูกที่เขียน `gcafe.json` / `state.json` ให้เมนู (ข้อ 2.3) — โค้ดออกแบบมาให้คู่กับ "เว็บร้าน" + Cooper Agent 1.20+ (`main.js:158-164`)
4. ถ้าจะใช้ทาง A ทำร้านไอดี/เติมเงิน ต้องแก้โค้ดเมนูก่อน (ต่อหน้าจอเข้ากับ `api.js` และเพิ่มที่มาของ token) — ข้อ 3.A บอกรูปแบบที่ `api.js` ส่ง/รับไว้ให้ แต่ต้องอ่านข้อ 6 ก่อน เพราะทาง A ไม่มีการยืนยันตัวตน

**(ข้อแนะนำ)** ใช้ทางใดทางหนึ่ง อย่าเปิดทั้งสองทางพร้อมกัน (ผลของการเปิดพร้อมกันดูข้อ 8 ข้อ 9)

---

## 1. วิธีเปิดใช้

### 1.1 คีย์ใน `Menu\config.json` ที่เกี่ยวข้อง

| คีย์ | ไม่ใส่ / ค่าว่าง = | ผล | โค้ด |
|---|---|---|---|
| `apiUrl` | `""` = ออฟไลน์ (ทาง A ปิด) | base URL ของทาง A | `main.js:119`, `config.js:22-27` |
| `machineId` | ชื่อเครื่องจาก `os.hostname()` เช่น `KORI12` | ค่าของ `X-Machine-ID` และ `machineId` ใน query/body ทาง A · ชื่อเครื่องบน HUD/เมนูเมื่อไม่ได้ต่อทาง B | `main.js:120`, `config.js:41-46` |
| `brandName` | `0JAYSHOP` | ชื่อร้านบน HUD / เมนู / หน้าล็อก, ชื่อหน้าต่าง, ชื่อแอปใน Windows, ชื่อไฟล์ exe ตอน build | `main.js:10`, `main.js:114` |
| `brandBadge` | `VIP` | ป้ายข้างชื่อร้านบน HUD | `main.js:115` |
| `brandLogo` | `data\brand\logo.png` (ถ้ามีไฟล์) | โลโก้ (ไฟล์เทียบกับโฟลเดอร์ `Menu\` หรือ URL) | `main.js:116` |
| `brandMark` | `data\brand\logo-mark.png` (ถ้ามีไฟล์) | โลโก้เล็กไม่มีตัวหนังสือ | `main.js:117` |
| `ui.menuOnly` | `false` | `true` = ไม่โชว์ HUD (หน้าต่างนับเวลา + ปุ่มออกจากระบบ), ไม่มีแท็บร้าน, ไม่มีชิปเวลาเหลือในเมนู — **ต้องเป็น `false` ถ้าจะใช้ระบบเวลา/ร้านไอดี** | `main.js:103`, `main.js:506`, `dialog/page.jsx:310-312`, `dialog/page.jsx:479` |
| `ui.sidePanel` | `true` | `false` = ไม่มีคอลัมน์ขวา (แบนเนอร์ / แนะนำจากร้าน / ประกาศ) **และไม่มีแถบสถานะล่าง** ที่โชว์เวลาเหลือ + ปุ่ม "แชทร้าน" | `dialog/page.jsx:311`, `dialog/page.jsx:433`, `dialog/page.jsx:468` |

ค่าที่ตั้งอยู่ตอนนี้: `apiUrl: ""`, `machineId: ""`, `ui.menuOnly: true`, `ui.sidePanel: false` = เมนูเกมอย่างเดียว ออฟไลน์

ข้อควรรู้:

- `machineId` **อย่าใส่ค่าใน `config.json`** — ไฟล์นี้ใช้ร่วมกันทุกเครื่อง ใส่แล้วทุกเครื่องได้ ID เดียวกัน ปล่อยว่างให้ใช้ชื่อเครื่อง
- ค่าใน localStorage ของโปรแกรมชนะ `config.json`: `gcafe_api_url` > `apiUrl` และ `gcafe_machine_id` > `machineId` (`config.js:24`, `config.js:43`) — ปัจจุบันไม่มีหน้าจอไหนเขียนค่านี้แล้ว แต่ถ้า Image เคยบันทึกค่าจากฟอร์มตั้งค่าลับรุ่นเก่าไว้ใน `%APPDATA%\0jayshop-timer-client` ค่านั้นจะชนะ
- ถ้า `/station/session` ตอบ `brand` มา ค่านั้นจะถูกเก็บใน localStorage แล้ว **ทับ** `brandName` / `brandBadge` / `brandLogo` ตั้งแต่การเปิดหน้าครั้งถัดไป (`api.js:48-50`, `config.js:57-70`)
- `config.json` ที่ JSON พัง → โปรแกรมอ่านได้ `{}` → ทุกคีย์กลับเป็นค่าเริ่ม (`apiUrl` ว่าง, `menuOnly` เป็น `false`) (`main.js:48-54`, `main.js:109`)

### 1.2 เปิดทาง A (`apiUrl`)

1. ทำเซิร์ฟเวอร์ตามข้อ 2.1 + 3.A (อย่างน้อย `/station/session`, `/station/heartbeat`, `/station/logout` และ CORS)
2. แก้ `Menu\config.json`:
   ```json
   "apiUrl": "http://192.168.51.202:8000/api",
   "machineId": "",
   "ui": { ..., "menuOnly": false, "sidePanel": true }
   ```
   - `apiUrl` ใส่ prefix ให้ครบ และ **ไม่มี `/` ท้าย** (โค้ดต่อสตริงตรงๆ `${apiUrl}${path}`: `api.js:21`)
   - `menuOnly: false` จึงจะเห็น HUD ที่โชว์เวลา
3. รีบูตเครื่องลูก (ข้อ 1.4)

### 1.3 เปิดทาง B (ระบบร้านผ่านเอเจนต์)

1. ทำเซิร์ฟเวอร์ `/api/gcafe/*` ตามข้อ 2.2 + 3.B
2. บนเครื่องลูกต้องมีโปรแกรมที่เขียน `%ProgramData%\CooperAgent\gcafe.json` และ `state.json` ตามข้อ 2.3 (ปกติคือ Cooper Agent 1.20+ — **ไม่มีตัวติดตั้งเอเจนต์ใน OSYNC** และวิธีติดตั้งไม่ระบุในโค้ดเมนู)
3. `config.json` → `ui.menuOnly: false` (ไม่งั้นไม่มี HUD / แท็บร้าน / ปุ่มออกจากระบบ) · `apiUrl` ไม่ต้องตั้ง (แนะนำให้ว่าง)
4. หน้าล็อกของทาง B **ทำงานแม้ `menuOnly: true`** — `main.js:271-282` ไม่ได้ดู `menuOnly` (ผลดูข้อ 8 ข้อ 8)

### 1.4 แก้ที่ไหน / ต้อง build ไหม / เครื่องลูกเห็นเมื่อไร

- **คอนโซล OSYNC (`http://localhost:4666`) แท็บ "ระบบร้าน"** (เพิ่ม 18 พ.ย. 2026) แก้ `apiUrl` / `machineId` / `brandName` / `ui.menuOnly` / `ui.sidePanel` ใน `Menu\config.json` ได้ พร้อมปุ่มทดสอบ `/station/session` (ทาง A) - คีย์อื่นใน config.json และไฟล์ของทาง B (`%ProgramData%\CooperAgent\gcafe.json`) ยังต้องแก้เองด้วย Notepad
- บันทึกเป็น UTF-8 (มี BOM ก็อ่านได้: `main.js:50`) และตรวจว่า JSON ถูกต้อง (ลูกน้ำ / วงเล็บ)
- `apiUrl`, `machineId`, `ui.*` → **ไม่ต้อง build ใหม่** โปรแกรมอ่าน `config.json` ทุกครั้งที่เปิดหน้า (`preload.js:4` → `main.js:652` → `loadConfig()` `main.js:108-124`)
- `brandName` / โลโก้ → build ใหม่: `OSYNC.bat` > 7 > 3 "Build the menu program" (ชื่อไฟล์ exe และไอคอนมาจากตอน build)
- **เครื่องลูก diskless เห็นค่าใหม่หลังรีบูต** — ไฟล์บนไดร์ฟเกมที่แก้หลังเครื่องลูกบูตแล้ว เครื่องลูกอาจอ่านไม่ได้จนกว่าจะรีบูต (`main.js:149-150`, `_ui_help` ใน `config.json`)
- ตัวติดตั้งสาขาใหม่ (`OSYNC-Setup.exe`) ส่ง `apiUrl` และ `machineId` เป็นค่าว่างเสมอ (`System\Scripts\Tool-Pack.ps1:54`)

---

## 2. พื้นฐานของ request

### 2.1 ทาง A — REST ตรงจากหน้าเมนู (`api.js:5-38`)

**URL**: `${apiUrl}${path}` ต่อสตริงตรงๆ (`api.js:21`) เช่น `apiUrl = http://192.168.51.202:8000/api` → `http://192.168.51.202:8000/api/station/session?machineId=KORI12`

ลำดับที่มาของ base URL (`config.js:22-27`): localStorage `gcafe_api_url` → `config.json` `apiUrl` → `NEXT_PUBLIC_API_URL` ตอน build (ตอนนี้ไม่ได้ตั้ง) → `""`

**Headers ทุก request** (`api.js:13-18`):

```http
Content-Type: application/json
X-Machine-ID: KORI12
Authorization: Bearer <token>
```

- `Content-Type: application/json` ส่ง **ทุก request รวม GET**
- `X-Machine-ID` = `getMachineId()`: localStorage `gcafe_machine_id` → `config.json` `machineId` → ชื่อเครื่อง (`os.hostname()`, `main.js:120`) · ค่า `PC-01` ใน `config.js:13` ใช้เฉพาะนอก Electron
- `Authorization` ส่งเฉพาะเมื่อ localStorage `gcafe_auth_token` มีค่า (`config.js:136-141`) — **แต่ไม่มีโค้ดส่วนไหนตั้งค่านี้** (`setAuthToken` ไม่มีที่เรียก) → ในทางปฏิบัติ **ไม่ถูกส่งเลย** ทาง A จึงไม่มี token

**Timeout**: 4000 ms (`config.js:17` `REQUEST_TIMEOUT_MS`, ยกเลิกด้วย `AbortController` `api.js:10-11`)

**สำเร็จ / ล้มเหลว** (`api.js:20-37`):

- สำเร็จ = HTTP 2xx **และ** body parse เป็น JSON ได้ → `{ ok: true, data }` (ไม่ดูฟิลด์ `ok` ใน body)
- 204 / body ว่าง / ไม่ใช่ JSON = ล้มเหลว → **ทุก endpoint ต้องตอบ JSON** แม้เป็น POST ที่ไม่ต้องคืนอะไร (ตอบ `{}`)
- ไม่ใช่ 2xx, timeout, ต่อไม่ได้ → `{ ok: false, error }` (ไม่ throw) แต่ละหน้าจอจัดการเองตามข้อ 3.A
- **ออฟไลน์** (`apiUrl` ว่าง): ทุกฟังก์ชันคืน `{ ok: false, error: 'offline' }` ทันที ไม่ยิงเน็ต (`api.js:8`)

**CORS (ต้องมี)**:

- หน้าเมนูทุกหน้า (HUD, เมนูเกม, หน้าล็อก) เสิร์ฟจากเซิร์ฟเวอร์ HTTP ในโปรแกรมเองที่ `http://127.0.0.1:<พอร์ตสุ่ม>` (`main.js:483` `server.listen(0, '127.0.0.1')`, `main.js:512`, `main.js:640`, `main.js:241`)
- พอร์ตสุ่มใหม่ทุกครั้งที่เปิดโปรแกรม → header `Origin` เป็น `http://127.0.0.1:NNNNN` ที่ NNNNN เปลี่ยนไปเรื่อยๆ — whitelist พอร์ตตายตัวไม่ได้
- ทุก request เป็นแบบ non-simple (`Content-Type: application/json` + `X-Machine-ID`) → เบราว์เซอร์ส่ง **preflight `OPTIONS` ก่อนทุก request รวม GET**
- Electron ไม่ได้ปิด `webSecurity` (`main.js:230`, `main.js:509`, `main.js:621`) → CORS ถูกบังคับจริง
- `fetch` ใช้ค่าเริ่ม (credentials = same-origin) → **ไม่ส่ง cookie** อย่าออกแบบ session ด้วย cookie

server ต้องตอบ preflight และ response จริงประมาณนี้:

```http
Access-Control-Allow-Origin: http://127.0.0.1:53123      ← ก็อปค่า Origin ที่ขึ้นต้น http://127.0.0.1: กลับไป
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, X-Machine-ID, Authorization
Access-Control-Max-Age: 600                              ← (ข้อแนะนำ) ลดจำนวน preflight
Vary: Origin
```

**(ข้อแนะนำ)** ตอบ `Access-Control-Allow-Origin` เฉพาะ Origin ที่ตรง `^http://127\.0\.0\.1:\d+$` ไม่ใช้ `*` (ข้อ 6)

**HTTPS**: `main.js` ไม่มีตัวจัดการ `certificate-error` → ใบรับรอง self-signed / CA ภายในจะใช้ไม่ได้ ต้องเป็นใบรับรองที่เครื่องลูกเชื่อถืออยู่แล้ว (ยังไม่ได้ทดสอบกับเซิร์ฟเวอร์จริง)

### 2.2 ทาง B — ระบบร้านผ่านเอเจนต์ (`main.js:284-305`)

หน้าเว็บในเมนูเรียก `window.electronAPI.agent.api(method, ชื่อ, body)` (`preload.js:44`) → `main.js` เป็นคนยิง HTTP เอง **token ไม่เคยถึงหน้าเว็บ** (`main.js:163`)

**URL**: `${server}/api/gcafe/${ชื่อ}` — `server` มาจาก `gcafe.json` (ตัด `/` ท้ายให้แล้ว: `main.js:184`)

**ชื่อที่อนุญาต** (allowlist `main.js:172`): `state`, `login`, `start`, `logout`, `panel`, `extend`, `topup`, `shop`, `buy`, `orders`, `steam-guard`, `qr-login`, `ticket`, `coupon`, `chat`, `account`, `launch` — ชื่ออื่นได้ `not allowed` ทันทีโดยไม่ยิง (`main.js:285`)

**Method / body**: ส่ง `'POST'` → POST พร้อม body `JSON.stringify(body || {})` · อย่างอื่น → GET ไม่มี body (`main.js:292-294`)

**Headers**:

```http
Authorization: Bearer gt_xxxxxxxxxxxx
Content-Type: application/json
```

ไม่มี `X-Machine-ID` — เซิร์ฟเวอร์ต้องรู้ว่าเป็นเครื่องไหน / การเช่าไหน จาก token

**Timeout**: 10000 ms (`main.js:289`)

**ผลที่หน้าเว็บได้รับ** = `{ ok, status, data }` (`main.js:297-299`):

- `ok` = HTTP 2xx **และ** body เป็น JSON ที่ `ok !== false` → ตอบ HTTP 200 + `{"ok": false, "error": "..."}` ก็นับว่าล้มเหลวได้
- body ไม่ใช่ JSON → `data = {}` → `ok: false`
- ต่อไม่ได้ / timeout → `{ ok: false, status: 0, data: { error: 'เชื่อมต่อร้านไม่ได้' } }` หรือ `'เชื่อมต่อร้านไม่ได้ (หมดเวลา)'` (`main.js:300-301`)
- ไม่มีเอเจนต์ / `gcafe.json` ไม่ครบ → `{ ok: false, status: 0, data: { error: 'ระบบร้านยังไม่พร้อม (ไม่พบเอเจนต์รุ่น 1.20+)' } }` (`main.js:287`)
- **ข้อความใน `data.error` โชว์ให้ลูกค้าเห็นตรงๆ** → เขียนเป็นภาษาไทยที่ลูกค้าอ่านเข้าใจ

**ข้อตกลงพิเศษที่หน้าจอใช้**:

| สัญญาณจาก server | หน้าจอทำอะไร | โค้ด |
|---|---|---|
| HTTP 409 (ไม่มี `priceChanged`) | ถือว่า "กำลังเตรียม" (token เพิ่งหมุนหลังเริ่ม/จบการเช่า) → รอ 2.5 วิ แล้วลองใหม่ 1 ครั้ง · เฉพาะแท็บร้านและปุ่มออกจากระบบ หน้าล็อกไม่ลองซ้ำ | `ShopTabs.jsx:43-50`, `app/page.jsx:166` |
| HTTP 403 ที่ `panel` | ไม่ใช่การเช่าแบบสมาชิก → ลอง `coupon {action:'panel'}` ต่อ | `ShopTabs.jsx:266-281` |
| `priceChanged: true` | ราคาเปลี่ยนระหว่างเลือก → โหลดตัวเลือกใหม่ | `ShopTabs.jsx:331`, `ShopTabs.jsx:438`, `lock/page.jsx:264-267` |
| `error: "TOTP_REQUIRED"` ที่ `login` | โชว์ช่องรหัสยืนยัน 2 ชั้น 6 หลัก | `lock/page.jsx:166` |
| `error: "wrong_network"` ที่ `login` | โชว์ "เครื่องนี้ยังเชื่อมต่อร้านไม่ได้ — แจ้งพนักงาน" | `lock/page.jsx:167` |
| `error` ที่มีคำว่า "ล็อกอินใหม่" ที่ `start` | ทิ้ง pass กลับไปหน้ากรอกรหัส | `lock/page.jsx:177` |

**หน่วย**:

- **เงินใน response ทุกช่องเป็นสตางค์** (ตัวเลข) — หน้าจอหาร 100 ก่อนโชว์ (`TopupPanel.jsx:15-18`) ได้แก่ `balance`, `price`, `compare`, `hourPrices[]`, `ratePerHour`, `amount`, `bonus`, `couponRefund`, `couponBalance`, `charged`, `toppedUp`, `spent`
- **ยกเว้น** `amount` ที่หน้าจอส่งไปตอน `topup {action:'create'}` และ `topup.min` / `topup.max` / `topupCfg.min` / `topupCfg.max` เป็น **บาท** (`TopupPanel.jsx:48`, `TopupPanel.jsx:72-75`)
- `expectedPrice` ที่หน้าจอส่งไป = `price` ที่ server ส่งมาเอง (สตางค์)
- เวลา: ฟิลด์ `*Sec` = วินาที, `minutes` = นาที · ฟิลด์ที่หน้าจอเอาไปลบกับนาฬิกา (`startedAt`, `endsAt`, `expiresAt` ของ QR และของ topup, `ending.until`, `updatedAt`) = **มิลลิวินาที epoch แบบตัวเลข** · ฟิลด์ที่แค่แปลงเป็นวันที่ (`createdAt`, `updatedAt` ของแชท, `at`, `memberSince`, `startedAt` ใน `recent`, `expiresAt` ของคูปอง) ผ่าน `new Date(x)` → มิลลิวินาทีหรือ ISO string ก็ได้

**CORS ไม่เกี่ยว** (ยิงจาก Node) · `server` ยอมทั้ง `http://` และ `https://` (`main.js:183`) **(ข้อแนะนำ)** ใช้ HTTPS เสมอ และหมายเหตุเรื่องใบรับรองเหมือนข้อ 2.1

### 2.3 ไฟล์เอเจนต์ — สัญญาระหว่างเอเจนต์กับเมนูบนเครื่องลูก (`main.js:158-215`)

ทาง B ใช้ได้เมื่อ **ทั้งสองไฟล์ถูกต้อง** (`integrated = ok && fresh`, `main.js:181-187`)

**`%ProgramData%\CooperAgent\gcafe.json`** — อ่านทุก 1 วิ

```json
{
  "server": "https://shop.example",
  "token": "gt_xxxxxxxxxxxx",
  "shop": "ชื่อร้าน",
  "machineName": "KORI12"
}
```

| ฟิลด์ | ชนิด | บังคับ | ความหมาย |
|---|---|---|---|
| `server` | string | ต้องมี | ขึ้นต้น `http://` หรือ `https://` (`main.js:183`) |
| `token` | string | ต้องมี | ต้องขึ้นต้น `gt_` (`main.js:183`) · comment ในโค้ดบอกว่าเอเจนต์หมุน token เมื่อเริ่ม/จบการเช่า (`main.js:161`) |
| `shop`, `machineName` | string | ไม่บังคับ | ใช้เมื่อ `state.json` ไม่มีค่า (`main.js:195-196`) |

**`%ProgramData%\CooperAgent\state.json`** — อ่านทุก 1 วิ (`main.js:942`)

```json
{
  "updatedAt": 1763452800000,
  "online": true,
  "serverOffsetMs": -350,
  "shop": "ชื่อร้าน",
  "machineName": "KORI12",
  "session": {
    "id": 1234,
    "mode": "hourly",
    "source": "web",
    "user": "ชื่อสมาชิก",
    "startedAt": 1763449200000,
    "endsAt": 1763456400000,
    "balanceText": "",
    "rateText": ""
  },
  "ending": null
}
```

| ฟิลด์ | ชนิด | ความหมาย / หน้าจอใช้ยังไง |
|---|---|---|
| `updatedAt` | ms | ต้องห่างจากนาฬิกาเครื่องไม่เกิน 60 วิ ไม่งั้นถือว่าไม่มีเอเจนต์ (`main.js:182`) → เอเจนต์ต้องเขียนไฟล์ซ้ำอย่างน้อยทุก 60 วิ |
| `online` | bool | HUD โชว์ `ONLINE` / `ออฟไลน์` (`app/page.jsx:113`) |
| `serverOffsetMs` | number | นาฬิกา server ลบนาฬิกาเครื่อง (ms) — ใช้คำนวณเวลาเหลือ และรหัส 2-Step ของไอดี (`app/page.jsx:102`, `ShopTabs.jsx:12-13`) |
| `shop`, `machineName` | string | ชื่อร้าน / ชื่อเครื่องบน HUD และหน้าล็อก |
| `session` | object หรือ `null` | **`null` = เครื่องว่าง → หน้าล็อก** · มีค่า = มีการเช่า → ปลดล็อก (`main.js:273`) |
| `session.startedAt` | ms | เวลาเริ่ม (นาฬิกา server) → "ใช้ไป" |
| `session.endsAt` | ms หรือ `null` | เวลาจบ (นาฬิกา server) → "เวลาคงเหลือ" · `null` = ไม่มีเวลาจบ (โหมดเครดิต) |
| `session.source` | `web` / `pc` / `guest` | ค่าเริ่ม `web` · `guest` = ลูกค้าไม่มีบัญชี (คูปอง/บัตร) — เปลี่ยนป้ายปุ่มเป็น "ต่อเวลา" และข้อความยืนยันออกจากระบบ (`app/page.jsx:111-123`) |
| `session.mode` | string | `credit` = HUD โชว์ `เครดิต <balanceText>` แทน `ONLINE` |
| `session.user` | string | ชื่อบน HUD |
| `session.balanceText` | string | ข้อความยอดเงินสำหรับโหมดเครดิต |
| `session.id`, `session.rateText` | — | อ่านแต่ไม่ได้ใช้ในหน้าจอ |
| `ending` | `{text, until}` หรือ `null` | ระหว่าง `until` (ms) ยังไม่ถึง → **ไม่ล็อก** แม้ `session` เป็น `null` (`main.js:198`, `main.js:273`) |

**`%ProgramData%\CooperAgent\gcafe\alive.json`** — เมนูเขียนทุก 2 วิ ถ้าโฟลเดอร์ `gcafe` มีอยู่แล้ว (เอเจนต์ต้องสร้างและให้ผู้ใช้ทั่วไปเขียนได้) (`main.js:210-215`):

```json
{ "at": 1763452800000, "pid": 4321, "managed": true, "showing": "hud", "version": "1.0.0" }
```

`showing` = `lock` หรือ `hud` · comment บอกว่าเอเจนต์ใช้ไฟล์นี้ซ่อนหน้าล็อก/หน้าเวลาของตัวเองขณะเมนูแสดงของเมนูอยู่ และแสดงของตัวเองถ้าไฟล์หยุดอัปเดต (`main.js:162`, `main.js:214`)

---

## 3. รายการ endpoint ทั้งหมด

ตัวเลข / ข้อความในตัวอย่าง JSON ทั้งหมดเป็นค่าสมมติ — ที่ตรงกับโค้ดคือ **ชื่อฟิลด์ ชนิด และหน่วย**

### 3.A ทาง A — REST (`api.js`)

| # | method + path | หน้าจอเรียกจริงไหม | เรียกเมื่อ / ความถี่ |
|---|---|---|---|
| A1 | `GET /station/session?machineId=` | ใช้ (HUD) | ครั้งเดียวตอน HUD โหลด (เปิดโปรแกรม) |
| A2 | `POST /station/heartbeat` | ใช้ (HUD) | ประมาณทุก 30 วิ ระหว่างยังมีเวลา |
| A3 | `POST /station/logout` | ใช้ (HUD) | กดออกจากระบบ (เมื่อไม่ได้ต่อทาง B) |
| A4 | `POST /station/lock` | **ไม่มีที่เรียก** | — |
| A5 | `GET /games?category=all` | ใช้ (เมนูเกม) | ทุกครั้งที่หน้าต่างเมนูเกมถูกสร้าง + ปุ่มโหลดใหม่ |
| A6 | `POST /games/launch` | ใช้ (เมนูเกม) | ทุกครั้งที่กดเล่น (ยกเว้นเกมที่มีหน้าต่างเลือกระดับภาพ) |
| A7 | `POST /games/sync-save` | **ไม่มีที่เรียก** | — |
| A8 | `POST /system/mouse` | **ไม่มีที่เรียก** | — |
| A9 | `GET /shop/games`, `POST /shop/buy`, `GET /shop/inventory` | **ไม่มีที่เรียก** | — |
| A10 | `GET /counter/chat`, `POST /counter/chat` | **ไม่มีที่เรียก** | — |
| A11 | `GET /billing/packages`, `POST /billing/promptpay` | **ไม่มีที่เรียก** | — |
| A12 | `GET /member/me`, `POST /member/redeem` | **ไม่มีที่เรียก** | — |

ทุกตัวส่ง headers ตามข้อ 2.1

#### A1 `GET /station/session?machineId=<id>` — เวลาของเครื่อง (`api.js:44-62`, `app/page.jsx:56-68`)

Request: ไม่มี body · `machineId` = ค่าเดียวกับ `X-Machine-ID` (encodeURIComponent แล้ว)

Response (JSON object):

| ฟิลด์ | ชนิด | บังคับ | หน้าจอทำอะไร |
|---|---|---|---|
| `totalSec` | number | ควรมี | เวลาทั้งหมด (วินาที) · ไม่ใช่ number → ใช้ 0 (`app/page.jsx:64`) |
| `usedSec` | number | ควรมี | ใช้ไปแล้ว (วินาที) · ไม่ใช่ number → ใช้ 0 (`app/page.jsx:65`) |
| `machineId` | string | ควรมี | ชื่อเครื่องบนแถบสถานะ — object ที่ตอบมาแทนที่ทั้งก้อน ไม่ส่ง = ชื่อว่าง (`app/page.jsx:63`, `app/page.jsx:112`) |
| `tier` | string | ไม่บังคับ | ข้อความหลังชื่อเครื่อง เช่น `VIP Gold` (`app/page.jsx:111`) |
| `lanSpeed` | string | ไม่บังคับ | ข้อความสถานะขวา · ว่าง = `Online` (`app/page.jsx:113`) |
| `brand` | `{name, badge, logoUrl}` | ไม่บังคับ | เก็บ localStorage `gcafe_brand` แล้วทับชื่อร้าน/ป้าย/โลโก้ตั้งแต่เปิดหน้าครั้งถัดไป (`api.js:48-50`, `config.js:57-70`) · `name` = `G-CAFE` ถูกข้าม |
| `username` | — | — | ไม่ได้ใช้ |

หน้าจอ: **เวลาคงเหลือ = max(0, `totalSec` − `usedSec`)** (`app/page.jsx:99`) แล้ว HUD นับ `usedSec` +1 ทุกวินาทีเอง (`app/page.jsx:71-83`) · แถบเวลา = เหลือ ÷ ทั้งหมด

ความถี่: **ครั้งเดียว** ตอนหน้า HUD โหลด ไม่มีการดึงซ้ำ · ถ้า `menuOnly: true` HUD ถูกซ่อนแต่ยังโหลดอยู่ จึงยังเรียก (`main.js:506`, `main.js:512`)

ล้มเหลว: ใช้ค่าแทน `{ machineId, username: '', tier: 'Guest', totalSec: 0, usedSec: 0, lanSpeed: 'Offline', isOffline: true }` (`api.js:53-61`) → HUD โชว์ `Guest`, `Offline`, `00:00:00` ไม่มีข้อความ error · ระหว่างรอ (สูงสุด 4 วิ) แถบสถานะโชว์ `กำลังเชื่อมต่อ...`

#### A2 `POST /station/heartbeat` (`api.js:64-69`, `app/page.jsx:71-83`)

Body:

```json
{ "machineId": "KORI12", "usedSec": 2730 }
```

- `usedSec` = ตัวนับในเครื่อง (เริ่มจาก `usedSec` ที่ได้จาก A1 แล้ว +1 ทุกวินาที)
- ส่งเมื่อค่าใหม่ของ `usedSec` หาร 30 ลงตัว และยังน้อยกว่า `totalSec` (`app/page.jsx:74-76`) → ประมาณทุก 30 วิ, ครั้งแรกอาจเร็วกว่า 30 วิ, **หยุดเมื่อเวลาหมด**, `totalSec = 0` → ไม่ส่งเลย
- Response: **ไม่ถูกอ่าน** (ตอบ `{}` ก็พอ)
- ล้มเหลว: เงียบ ไม่มีอะไรบนจอ
- `usedSec` เป็นค่าที่เครื่องลูกบอกเอง — ห้ามใช้คิดเงินหรือหักเวลา (ข้อ 6)

#### A3 `POST /station/logout` (`api.js:78-83`, `app/page.jsx:160-183`)

Body: `{ "machineId": "KORI12" }`

- เรียกเมื่อลูกค้ากด "ออกจากระบบ" → "ยืนยัน" บน HUD และ **ไม่ได้** ต่อทาง B (`app/page.jsx:181`)
- หลังเรียก HUD ซ่อนลง tray ทันที **ไม่ว่าผลเป็นอย่างไร** (`app/page.jsx:182`, `app/page.jsx:153-158`) · response ไม่ถูกอ่าน · ไม่ล็อกเครื่อง · ไม่รีเซ็ตตัวนับ
- ข้อความยืนยันบอกลูกค้าว่า "เวลาที่เหลือจะถูกบันทึกเก็บไว้ในบัญชีสมาชิก" (`app/page.jsx:115`) → server ต้องทำแบบนั้นจริง หรือต้องแก้ข้อความ

#### A4 `POST /station/lock` — ไม่มีที่เรียก (`api.js:71-76`)

Body ถ้ามีคนเรียก: `{ "machineId": "KORI12", "pin": "<pin>" }` · ไม่มีหน้าจอใส่ PIN ในโปรแกรม · response ไม่ระบุในโค้ด

#### A5 `GET /games?category=all` — รายชื่อเกม (`api.js:133-143`, `dialog/page.jsx:149-162`)

- หน้าจอเรียก `getGames()` แบบไม่ใส่ค่า → `category=all` เสมอ และ **ไม่ส่ง `q`** (ค้นหาทำในเครื่อง)
- เรียกทุกครั้งที่หน้าต่างเมนูเกมถูกสร้าง (ปิดแล้วเปิดใหม่ = สร้างใหม่) และปุ่มโหลดใหม่ (`dialog/page.jsx:390`) · ถ้า `menuOnly: true` หน้าต่างไม่ถูกทำลาย → ครั้งแรก + ปุ่มโหลดใหม่
- Response: **array ที่ไม่ว่าง → ใช้แทน `data\games.json` ทั้งรายการ** · array ว่าง / ล้มเหลว → ใช้ `games.json` (`api.js:135-142`)

ฟิลด์ของแต่ละเกมที่โปรแกรมใช้:

| ฟิลด์ | ชนิด | ใช้ทำอะไร |
|---|---|---|
| `id` | string | key, `ui.featured`, `ui.graphicsPicker`, คลิกขวา |
| `title` (หรือ `name`) | string | ชื่อบนการ์ด, ชื่อที่รายงานตอนเปิดเกม |
| `cmd` | string | **คำสั่งที่เครื่องลูกรันตอนกดเล่น** — ขึ้นต้น `xxx://` เปิดด้วย `shell.openExternal` · อย่างอื่นรันด้วย `spawn(cmd, { shell: true })` (`main.js:307-316`) |
| `cwd` | string | โฟลเดอร์ทำงานตอนรัน (ถ้ามีอยู่จริง) |
| `cat` (หรือ `category`) | string | หมวด · ไม่มี = `Online` |
| `platform` | string | ป้ายค่าย / ไอคอนมุมการ์ด |
| `img` | string | รูปปก (URL `http(s)` หรือ `data:`) |
| `icon` | string | ไอคอนเล็ก |

ข้อจำกัด: คลิกขวา "เปิดตำแหน่งไฟล์" หาเกมจาก `games.json` เท่านั้น (`main.js:404-406`) และไอคอนอัตโนมัติใส่ให้เฉพาะรายการจาก `games.json` (`main.js:653`)

#### A6 `POST /games/launch` — รายงานการเปิดเกม (`api.js:145-159`)

Body:

```json
{ "machineId": "KORI12", "title": "VALORANT", "cmd": "<คำสั่งเปิดเกมทั้งบรรทัด>", "id": "riot-valorant" }
```

- ยิงทุกครั้งที่กดเล่น **หลัง** สั่งเปิดเกม ไม่รอผล และยิงแม้เปิดเกมไม่สำเร็จ · response ไม่ถูกอ่าน
- เกมที่อยู่ใน `ui.graphicsPicker` (GTA V / FiveM) เปิดผ่านอีกทาง **ไม่ยิงตัวนี้** (`dialog/page.jsx:215`)

#### A7–A12 — มีฟังก์ชันใน `api.js` แต่ไม่มีหน้าจอเรียก

รูปแบบด้านล่างคือสิ่งที่ฟังก์ชันจะส่ง **ถ้า** มีคนต่อหน้าจอเข้ากับมันในอนาคต · response ที่ฟังก์ชันคาดคือ "array" หรือ "object" ตามตาราง ฟิลด์ข้างในไม่ระบุในโค้ด (ไม่มีหน้าจออ่าน)

| endpoint | request | ฟังก์ชันคาด response | ล้มเหลวคืน | โค้ด |
|---|---|---|---|---|
| `POST /games/sync-save` | `{machineId, email, password}` — **รหัสผ่านเป็นข้อความธรรมดา** | ไม่อ่าน | `{ok:false, error}` | `api.js:161-166` |
| `POST /system/mouse` | `{val}` (ไม่มี `machineId` ใน body, มีใน header) | ไม่อ่าน | `{ok:false, error}` | `api.js:168-173` |
| `GET /shop/games?category=<cat>` | — | array | `[]` | `api.js:90-96` |
| `POST /shop/buy` | `{machineId, items, total, contact, note, createdAt (ISO)}` | object (คืนทั้งก้อน) | `{status:'error', error}` | `api.js:98-115` |
| `GET /shop/inventory?machineId=` | — | array | `[]` | `api.js:117-124` |
| `GET /counter/chat?machineId=` | — | array | `[]` | `api.js:183-190` |
| `POST /counter/chat` | `{machineId, sender:'me', text, time:'HH:MM'}` | object | `null` | `api.js:192-209` |
| `GET /billing/packages` | — | array | `[]` | `api.js:216-222` |
| `POST /billing/promptpay` | `{machineId, packageId, amount (= price ของแพ็กเกจ), seconds (ไม่มี = 3600)}` | object | `{success:false, error}` | `api.js:224-239` |
| `GET /member/me` | — | object | `null` | `api.js:246-250` |
| `POST /member/redeem` | `{privilegeId}` | object | `{success:false, message}` | `api.js:252-259` |

`total`, `amount`, `seconds`, `price` ในตารางนี้มาจากเครื่องลูก — ถ้าจะทำจริง server ต้องคิดราคา/เวลาเองจาก `id` เท่านั้น (ข้อ 6)

### 3.B ทาง B — `/api/gcafe/*` (ผ่าน `main.js`)

| ชื่อ | method | body (action) | ใช้ที่ | เรียกเมื่อ / ความถี่ |
|---|---|---|---|---|
| `state` | GET | — | หน้าล็อก, เมนู | หน้าล็อกทุก 15 วิ · เมนูทุก 60 วิ |
| `login` | POST | `{username, password, code}` | หน้าล็อก | กดเข้าสู่ระบบ |
| `start` | POST | `{pass, option}` | หน้าล็อก | กดเริ่มเล่น |
| `qr-login` | POST | `create` / `poll` | หน้าล็อก | เปิดแท็บ QR · poll ทุก 2 วิ |
| `ticket` | POST | `{code}` | หน้าล็อก | ใส่บัตรเวลา 10 ตัว |
| `coupon` | POST | `check` / `merge` / `start` / `panel` / `extend` / `panelMerge` | หน้าล็อก, แท็บต่อเวลา | ตามการกด · `panel` ทุก 15 วิ |
| `panel` | GET | — | แท็บเติมเงิน/ต่อเวลา | ทุก 15 วิ ระหว่างแท็บเปิด |
| `extend` | POST | `{key, expectedPrice}` | แท็บเติมเงิน/ต่อเวลา | กดยืนยันต่อเวลา |
| `topup` | POST | `create` / `status` / `cancel` | หน้าล็อก, แท็บเติมเงิน | `status` ทุก 3 วิ (auto) / 5 วิ (slip, web) |
| `logout` | POST | `{}` | HUD | กดออกจากระบบ |
| `shop` | GET | — | แท็บซื้อไอดี | เปิดแท็บ + หลังซื้อ |
| `buy` | POST | `{productId, expectedPrice}` | แท็บซื้อไอดี | กดซื้อเลย |
| `orders` | POST | `list` / `reveal` | แท็บคลังรหัส | เปิดแท็บ / กดดูครั้งแรกต่อ order |
| `steam-guard` | POST | `{orderId}` | ซื้อไอดี, คลังรหัส | กดรับโค้ด Steam Guard |
| `chat` | POST | `list` / `open` / `send` | แท็บแชทร้าน | ทุก 15 วิ ระหว่างแท็บเปิด |
| `account` | POST | `{}` | แท็บบัญชี | เปิดแท็บ |
| `launch` | POST | `{title}` | ทุกการเปิดเกม | ทุกครั้ง ไม่รอผล |

#### B1 สถานะเครื่องและหน้าล็อก

**`GET state`** (`lock/page.jsx:118-147`, `dialog/page.jsx:70-77`)

```json
{
  "shop": "ชื่อร้าน",
  "machine": { "name": "KORI12" },
  "site": "https://shop.example",
  "storefront": { "loginAllowed": true, "why": "", "tickets": true, "coupons": true },
  "topup": { "auto": true, "min": 20, "max": 5000 },
  "screen": {
    "lock": { "tabs": { "member": true, "qr": true, "coupon": true, "signup": true }, "headline": "", "lines": "บรรทัด 1\nบรรทัด 2", "bg": "https://..." },
    "menu": { "notice": "ข้อความประกาศ", "banner": "https://...", "bannerText": "", "accent": "#f7931e" }
  }
}
```

| ฟิลด์ | หน้าจอใช้ยังไง |
|---|---|
| `shop`, `machine.name` | ชื่อร้าน / ชื่อเครื่องบนหน้าล็อก (ก่อนค่าจาก `state.json`) |
| `site` | โชว์ชื่อโดเมน · ทำรูป QR สมัครสมาชิกจาก `${site}/api/topup-qr?to=register` (โหลดเป็น `<img>` ตรง ไม่ผ่าน token: `lock/page.jsx:486`) |
| `storefront.loginAllowed` | `false` = ซ่อนฟอร์ม โชว์ `why` แทน · **ยังโหลด `state` ไม่ได้ = ถือว่า `true`** (`lock/page.jsx:139`) |
| `storefront.tickets` | ไม่ใช่ `false` = รับบัตรเวลา 10 ตัว |
| `storefront.coupons` | `true` = รับคูปอง 8 ตัว |
| `topup` | `{auto, min, max}` (บาท) ของกล่องเติมเงินบนหน้าล็อก · **ไม่มี = กล่องเติมเงินค้าง "กำลังโหลด…"** (`TopupPanel.jsx:86`) |
| `screen.lock.tabs.*` | `false` = ซ่อนแท็บนั้น |
| `screen.lock.headline`, `lines`, `bg` | หัวข้อ, บรรทัดประกาศ (แยกด้วยขึ้นบรรทัด), รูปพื้นหลัง |
| `screen.menu.notice`, `banner`, `bannerText`, `accent` | ประกาศ / แบนเนอร์ในคอลัมน์ขวาของเมนูเกม · `accent` ต้องเป็น `#rrggbb` |

ทุกฟิลด์ไม่บังคับ · ล้มเหลว: หน้าล็อกใช้ค่าเดิม / ค่าเริ่ม, เมนูเงียบ

**`POST login`** (`lock/page.jsx:157-168`)

Request: `{ "username": "...", "password": "...", "code": "" }` — `code` เป็น `""` จนกว่า server ตอบ `TOTP_REQUIRED` แล้วลูกค้าใส่รหัส 6 หลัก

Response สำเร็จ:

```json
{
  "pass": "<รหัสผ่านชั่วคราวสำหรับเลือกแพ็กเกจ>",
  "user": { "name": "ชื่อ", "balance": 15000, "timeBankSec": 1800, "timeBankTotalSec": 2400 },
  "options": [
    { "key": "bank", "label": "ใช้เวลาสะสม", "minutes": 30, "price": 0 },
    { "key": "p1", "label": "1 ชั่วโมง", "minutes": 60, "price": 2000 }
  ]
}
```

- `user` **ต้องมี** (หน้าจออ่าน `user.name`, `user.balance`) · `options` ไม่มี = "เครื่องนี้ยังไม่มีแพ็กเกจ"
- `key: "bank"` = ใช้เวลาสะสม — โชว์ "ฟรี / ไม่หักเงิน" และเลือกได้เสมอ · ตัวเลือกอื่นที่ `price > balance` เป็นสีเทา เลือกไม่ได้ (`lock/page.jsx:357-369`)
- `timeBankTotalSec − timeBankSec ≥ 60` → บอกลูกค้าว่ามีเวลาสะสมจากเครื่องที่ถูกกว่าซึ่งใช้ที่เครื่องนี้ไม่ได้ (`lock/page.jsx:352`) · ไม่ส่ง = ไม่โชว์
- เครื่องลูกนับอายุ `pass` เอง 110 วิ (`PASS_MS`, `lock/page.jsx:77`) แล้วล้างกลับหน้ากรอกรหัส · อายุจริงฝั่ง server ไม่ระบุในโค้ด (comment บอก 2 นาที)

**`POST start`** — Request `{ "pass": "...", "option": "p1" }` (`lock/page.jsx:170-178`)

- สำเร็จ: response ไม่ถูกอ่าน · หน้าจอโชว์ "เริ่มเล่นแล้ว — เครื่องกำลังปลดล็อก…" แล้ว **รอให้เอเจนต์เขียน `session` ลง `state.json`** หน้าล็อกจึงหาย
- ล้มเหลว: โชว์ `error` · มีคำว่า "ล็อกอินใหม่" = กลับหน้ากรอกรหัส

**`POST qr-login`** (`lock/page.jsx:181-205`)

- `{ "action": "create" }` → `{ "id": "...", "qr": "<src รูป QR: URL หรือ data:>", "url": "...", "expiresAt": 1763452920000 }` (`url` ไม่ได้ใช้)
- `{ "action": "poll", "id": "..." }` ทุก 2 วิ ระหว่างแท็บ QR เปิด จนเลย `expiresAt` + 3 วิ → `{ "status": "approved" | "expired" | "denied" | "error" | อื่นๆ = ยังรอ, "error": "..." }`
- `approved` ต้องมาพร้อม `pass`, `user`, `options` แบบเดียวกับ `login` (`lock/page.jsx:198`)

**`POST ticket`** — บัตรเวลาแบบเก่า 10 ตัว (`lock/page.jsx:224-231`)

- Request `{ "code": "K7Q9M2XD4P" }` (ตัวพิมพ์ใหญ่ A-Z0-9 ไม่มีขีด) · ส่งเมื่อ `storefront.tickets` ไม่ใช่ `false`
- สำเร็จ `{ "label": "..." }` → เริ่มเล่นทันที (ไม่มีขั้นเลือกแพ็กเกจ)

**`POST coupon` บนหน้าล็อก** — คูปองเงินสด 8 ตัว เมื่อ `storefront.coupons` เป็น `true` (`lock/page.jsx:208-268`)

| action | request | response สำเร็จ (ต้องมี `"ok": true` ใน body) |
|---|---|---|
| `check` | `{action, code}` | `{ok, code (ข้อความโชว์ เช่น ท้ายรหัส), balance, expiresAt, options:[{key,label,minutes,price}]}` |
| `merge` | `{action, code, add}` (`add` = อีกใบ) | `{ok, balance, expiresAt, options?, message?}` |
| `start` | `{action, code, option, expectedPrice}` | `{ok, label, balance}` · ล้มเหลว `{error, priceChanged?}` |

คูปองที่ตรวจแล้วค้างบนจอได้ 120 วิ (`COUPON_MS`, `lock/page.jsx:78`) · comment บอกว่าเว็บล็อกหลังใส่รหัสผิด 5 ครั้ง (`lock/page.jsx:235`)

#### B2 เวลาระหว่างเล่น — ต่อเวลา / ออกจากระบบ

**`GET panel`** — แท็บ "เติมเงิน/ต่อเวลา" ของสมาชิก (`ShopTabs.jsx:256-282`, `ShopTabs.jsx:386-409`)

```json
{
  "balance": 15000,
  "mode": "hourly",
  "remainingSec": 3200,
  "ratePerHour": 2000,
  "booting": false,
  "frozen": false,
  "options": [ { "key": "p1", "label": "1 ชั่วโมง", "minutes": 60, "price": 2000, "hot": true, "compare": 2500 } ],
  "hourPrices": [2000, 4000, 5500],
  "maxHours": 3,
  "topupCfg": { "auto": true, "min": 20, "max": 5000 }
}
```

- `mode: "hourly"` = แพ็กเกจ (โชว์ "เหลือเวลา") · ค่าอื่น = คิดตามเวลาที่เล่น (โชว์ `ratePerHour` และ "เล่นได้อีกประมาณ")
- `hourPrices[n-1]` = ราคา n ชั่วโมง → แถว "กำหนดเอง (1–N ชั่วโมง)" ส่ง `key: "hours:<n>"` · ไม่ส่ง = ไม่มีแถวนี้ (`ShopTabs.jsx:286-291`)
- `topupCfg` **ต้องมี** ไม่งั้นกล่องเติมเงินด้านขวาค้าง "กำลังโหลด…"
- เรียกทุก 15 วิ ระหว่างแท็บเปิด · HTTP 403 = ไม่ใช่สมาชิก → ลอง `coupon {action:'panel'}`

**`POST coupon {action:'panel'}`** — แท็บเดียวกันสำหรับคนเล่นด้วยคูปอง (`ShopTabs.jsx:335-385`) → `{ code, balance, remainingSec, expiresAt, options, hourPrices?, maxHours? }`

**`POST extend`** — `{ "key": "p1", "expectedPrice": 2000 }` (`ShopTabs.jsx:315-332`) · คูปองใช้ `POST coupon { "action": "extend", "key": "...", "expectedPrice": ... }`

- สำเร็จ: `{ "message": "..." }` (ไม่มี = "ต่อเวลาเรียบร้อย") → toast + โหลด `panel` ใหม่ · เวลาบน HUD เปลี่ยนเมื่อเอเจนต์เขียน `endsAt` ใหม่
- ล้มเหลว: `{ "error": "...", "priceChanged": true? }`

**`POST coupon {action:'panelMerge', add}`** — รวมคูปองอีกใบเข้าใบที่เล่นอยู่ (`ShopTabs.jsx:299-313`) → `{ ok: true, message?, ...ข้อมูลชุดเดียวกับ coupon panel }` (หน้าจอแทนข้อมูลทั้งแท็บด้วย response นี้)

**`POST logout`** — body `{}` (`app/page.jsx:162-180`)

- สำเร็จ: `{ "bankedSec": 1200, "couponRefund": 0, "couponBalance": 0 }` (ทุกฟิลด์ไม่บังคับ) → toast "เก็บเวลา N นาที" หรือ "คืนเข้าคูปอง ฿…"
- หน้าล็อกกลับมาเองเมื่อเอเจนต์เห็นว่าการเช่าจบ (`session: null`)
- HTTP 409 → ลองใหม่ 1 ครั้งหลัง 2.5 วิ · ล้มเหลว → "ออกจากระบบไม่สำเร็จ: <error>"

#### B3 เติมเงิน PromptPay — `POST topup` (`TopupPanel.jsx`)

ใช้ 2 ที่: หน้าล็อกหลังล็อกอิน (ส่ง `pass` ไปด้วย เพราะยังไม่มีการเช่า) และแท็บเติมเงินระหว่างเล่น (ไม่ส่ง `pass`) (`TopupPanel.jsx:49`)

| action | request | response |
|---|---|---|
| `create` | `{action, amount (บาทเต็ม · 0 เมื่อ cfg.auto ไม่ใช่ true), pass?}` | ดูตารางโหมดด้านล่าง |
| `status` | `{action, id (โหมด auto = id ที่ได้ · โหมดอื่น = 0), pass?}` | auto: `{status, amount, bonus, balance}` · slip/web: `{balance}` |
| `cancel` | `{action, id}` (เฉพาะ auto, ไม่รอผล) | ไม่อ่าน |

โหมดที่ `create` ตอบได้:

| `mode` | ฟิลด์ | หน้าจอ |
|---|---|---|
| `auto` | `id`, `qr` (src รูป QR PromptPay), `amount` (สตางค์ — ยอดมีเศษสตางค์เฉพาะคน), `expiresAt` (ms) | QR + ยอด + นับถอยหลัง "อย่าแก้ยอด" · poll `status` ทุก 3 วิ |
| `slip` | `qr` (QR ไปหน้าแนบสลิป), `payQr?` (QR จ่ายเข้าร้าน), `truewallet?` (bool), `account?` `{bank, no, name}` | QR แนบสลิป + เลขบัญชี · poll ทุก 5 วิ |
| `web` | `qr` (QR ไปหน้าเติมเงินของเว็บ) | poll ทุก 5 วิ |

ผลของ `status`:

- auto: `status: "success"` → "เติมเงินสำเร็จ ฿amount + โบนัส ฿bonus · ยอดตอนนี้ ฿balance" · `"expired"` หรือ `"gone"` → "หมดเวลาแล้ว" · ค่าอื่น = ยังรอ (`TopupPanel.jsx:58-60`)
- slip / web: หน้าจอจำ `balance` ครั้งแรกที่ poll ได้ แล้วถือว่าสำเร็จเมื่อ `balance` สูงขึ้น (`TopupPanel.jsx:62-63`)

ข้อกำหนดจากหน้าจอ: chip 50 / 100 / 200 / 500 บาท โชว์เฉพาะที่อยู่ใน `[min, max]` · โหมด auto ตรวจ `min ≤ amount ≤ max` ก่อนส่ง · **การยืนยันว่าเงินเข้าทำฝั่ง server เท่านั้น** หน้าจอไม่เพิ่มเงินหรือเวลาเอง (`TopupPanel.jsx:4-6`)

#### B4 ร้านไอดี (ระบบซื้อขายรหัส)

**`GET shop`** (`ShopTabs.jsx:413-470`)

```json
{
  "enabled": true,
  "balance": 15000,
  "products": [
    { "id": 12, "name": "[VALORANT] ไอดีตัวอย่าง", "description": "รายละเอียด", "price": 35000, "stock": 3, "image": "https://..." }
  ]
}
```

- `enabled: false` → "ร้านค้าปิดชั่วคราว"
- `products` **ต้องเป็น array** · `stock ≤ 0` = "สินค้าหมด" · `price > balance` = ปุ่ม "ยอดเงินไม่พอ" · `image` ไม่มี = กล่องสีแทน
- เรียกตอนเปิดแท็บ และหลังซื้อสำเร็จ

**`POST buy`** — `{ "productId": 12, "expectedPrice": 35000 }` (`ShopTabs.jsx:426-439`)

- สำเร็จ: `{ "productName": "...", "secret": "<ข้อความไอดี ดูข้อ 5.2>", "orderId": 345, "steam": false }` → หน้าต่าง "ซื้อสำเร็จ" โชว์ `secret` ทันที + toast บน HUD
- ล้มเหลว: `{ "error": "...", "priceChanged": true? }` · `priceChanged` = ปิดหน้ายืนยันแล้วโหลดสินค้าใหม่

#### B5 คลังรหัส

**`POST orders {action:'list'}`** (`ShopTabs.jsx:551-555`) → `{ "orders": [ { "id": 345, "name": "...", "createdAt": 1763452800000, "price": 35000, "steam": false } ] }` — **ไม่มี secret ในรายการ** · เรียกครั้งเดียวตอนเปิดแท็บ

**`POST orders {action:'reveal', orderId}`** (`ShopTabs.jsx:557-563`) → `{ "secret": "..." }` — เรียกเมื่อกด "ดูข้อมูลไอดี" หรือ "รับรหัส 2-Step" ครั้งแรกของ order นั้น แล้วจำไว้ในหน้าต่าง (หน้าต่างปิด = ลืม)

**`POST steam-guard {orderId}`** (`ShopTabs.jsx:155-170`, `ShopTabs.jsx:513-516`) → `{ "ok": true, "code": "AB12C" }` — โค้ด Steam Guard ที่ server อ่านจากเมลของไอดี · ปุ่มนี้โชว์เมื่อ order มี `steam: true`

#### B6 แชทกับร้าน — `POST chat` (`ShopTabs.jsx:598-665`)

| action | request | response |
|---|---|---|
| `list` | `{action}` | `{tickets:[{id, subject, status, updatedAt, unread}], thread?}` |
| `open` | `{action, ticketId}` | `{thread:{id, subject, status, messages:[{id, from, author, body, at}]}, tickets?}` |
| `send` | `{action, ticketId?, body}` | `{thread, tickets?}` |

- `status`: `open` (รอทีมงาน) / `answered` (ทีมงานตอบแล้ว) / `closed` (ปิดแล้ว)
- `from: "me"` = ข้อความของลูกค้า (ชิดขวา) · ค่าอื่น = ทีมงาน โชว์ `author`
- `send` ไม่ส่ง `ticketId` เมื่อเริ่มเรื่องใหม่หรือเรื่องเดิมปิดแล้ว · `body` ตัดที่ 1000 ตัวอักษร
- poll ทุก 15 วิ ระหว่างแท็บเปิด (`list` หรือ `open` เรื่องที่เปิดอยู่)
- comment บอกว่าเป็นระบบ "แจ้งปัญหา" ของเว็บร้าน (`ShopTabs.jsx:594`) — ไม่ใช่แชทเรียลไทม์

#### B7 บัญชีสมาชิก — `POST account` body `{}` (`ShopTabs.jsx:668-713`)

```json
{
  "user": { "name": "ชื่อ", "username": "demo", "balance": 15000, "timeBankSec": 1800, "memberSince": 1735689600000 },
  "stats": { "rentals": 12, "minutesPlayed": 900, "toppedUp": 100000, "spent": 85000, "favoriteMachine": "KORI12", "favoriteCount": 5 },
  "recent": [ { "id": 1, "machine": "KORI12", "startedAt": 1763449200000, "charged": 2000 } ]
}
```

`user`, `stats`, `recent` **ต้องมีครบ** (หน้าจออ่านตรงๆ) · ไม่มีแต้ม / สิทธิพิเศษ ในหน้าจอนี้

#### B8 สถิติเปิดเกม — `POST launch` `{ "title": "VALORANT" }` (`main.js:318-320`)

ชื่อเกมไม่เกิน 80 ตัว · ทุกครั้งที่เปิดเกม (รวม GTA V / FiveM) · ไม่รอผล ไม่สนผล

---

## 4. Flow ของเวลา

### 4.1 ทาง A — แค่ "โชว์เวลา" ไม่ใช่ระบบคุมเวลา

```
เปิดโปรแกรม ─▶ GET /station/session ─▶ totalSec, usedSec
     │
     ▼
HUD นับ usedSec +1 ทุกวินาทีในเครื่อง ── ทุกหลัก 30 ──▶ POST /station/heartbeat {usedSec}  (ไม่อ่านผล)
     │
     ▼ usedSec = totalSec
นาฬิกาหยุดที่ 00:00:00 ── จบ (ไม่ล็อก ไม่ออกจากระบบ ไม่เรียก /station/lock หยุด heartbeat)
```

- **เวลาหมดแล้วไม่มีอะไรเกิดขึ้น** นอกจากตัวเลขเป็นศูนย์ (`app/page.jsx:71-83`) — ร้านต้องคุมเครื่องด้วยระบบอื่น
- **ไม่มีการดึงเวลาใหม่** — เติมเวลาที่เคาน์เตอร์ HUD ไม่เห็นจนกว่าจะเปิดโปรแกรมใหม่ / รีบูต
- ออกจากระบบ → `POST /station/logout` แล้วซ่อน HUD (ข้อ 3.A A3)

### 4.2 ทาง B — server เป็นเจ้าของเวลา

```
server ──(เอเจนต์)──▶ state.json { session: {startedAt, endsAt}, serverOffsetMs }  ◀── main.js อ่านทุก 1 วิ
                                                                                      │
             session = null และไม่มี ending ─────────────────────────────▶ หน้าล็อกเต็มจอ
             session มีค่า ──────────────────────────────────────────────▶ ปิดหน้าล็อก, โชว์ HUD
             HUD: เวลาคงเหลือ = endsAt − (เวลาเครื่อง + serverOffsetMs)
```

- **เจ้าของเวลาคือ server** เมนูไม่นับเวลาแล้วส่งกลับ แค่คำนวณจาก `endsAt` ที่ได้ (`app/page.jsx:100-109`, `dialog/page.jsx:276-278`)
- **หน้าล็อก** (`main.js:217-282`): ทุก 1 วิตรวจ `integrated && !session && !ending` → เปิดหน้าต่างเต็มจอทุกจอ (จอหลัก = หน้าล็อกอิน, จอรอง = สีดำ) แบบ kiosk, อยู่บนสุดระดับ screen-saver, ปิดไม่ได้, ห้ามออกไปหน้าอื่น, ซ่อน HUD, ทำลายหน้าต่างเมนูเกม (ลูกค้าคนถัดไปเริ่มใหม่) · ระหว่างล็อกเปิดเมนูไม่ได้ (`main.js:597`)
- **ปลดล็อก** = เอเจนต์เขียน `session` ที่ไม่ใช่ `null` → ปิดหน้าล็อก โชว์ HUD (`main.js:277`)
- **เวลาหมด**: เมนูไม่ทำอะไรเอง — server / เอเจนต์จบการเช่า → `session: null` → หน้าล็อกขึ้นภายใน 1 วิ · `ending` = ช่วงผ่อนผันที่ยังไม่ล็อก · (TEST-PLAN R-05: ระบบร้านอาจสั่งรีสตาร์ตเครื่องหลังจบการเช่า — เป็นพฤติกรรมของเอเจนต์ ไม่ใช่เมนู)
- **ต่อเวลา**: `extend` → server เลื่อน `endsAt` → เอเจนต์เขียน `state.json` → HUD เปลี่ยนเอง
- **โหมดเครดิต** (`endsAt: null`): HUD โชว์ "เครดิต <balanceText>" และเวลาคงเหลือ `00:00:00`
- **เอเจนต์หยุดเขียน `state.json` เกิน 60 วิ** → เมนูถือว่าไม่ได้ต่อระบบร้าน → **ปิดหน้าล็อก** (ข้อ 8 ข้อ 12)

### 4.3 PIN และ TOTP

- **ไม่มี PIN** ในหน้าจอไหนเลย · `POST /station/lock {machineId, pin}` (ทาง A) ไม่มีที่เรียก · ลูกค้าล็อกเครื่องเองไม่ได้ (ทางเดียวคือ "ออกจากระบบ")
- **TOTP มี 2 แบบ และไม่ใช่ตัวปลดล็อกเครื่อง**:
  1. **ล็อกอินสมาชิกที่เปิดยืนยัน 2 ชั้น** — server ตอบ `login` ด้วย `error: "TOTP_REQUIRED"` → หน้าล็อกโชว์ช่องรหัส 6 หลัก → ส่ง `login` ใหม่พร้อม `code` · server ตรวจรหัสเอง (`lock/page.jsx:166`)
  2. **รหัส 2-Step ของไอดีเกมที่ซื้อ** (`totp.js`) — หาคีย์ 2FA ในข้อความ `secret` แล้ว **คำนวณบนเครื่องลูก** (RFC 6238: HMAC-SHA1, 6 หลัก, เปลี่ยนทุก 30 วิ) ตามนาฬิกา server (`serverOffsetMs`) · server ไม่ต้องมี endpoint (`totp.js:1-3`, `totp.js:82-95`, `ShopTabs.jsx:90-117`)

### 4.4 ห้ามเพิ่มเวลาฝั่ง client

โค้ดเขียนไว้ชัด 3 ที่:

- `api.js:236` — "time is never added here: it only changes when the shop system confirms a real payment"
- `TopupPanel.jsx:6` — "Nothing here ever adds time or money by itself: the balance only changes when the shop web says so."
- `main.js:928` — IPC `add-time` เดิมที่ให้หน้าเติมเงินเพิ่มเวลาได้โดยไม่จ่ายเงิน ถูกเอาออกแล้ว "time only changes from real rentals now"

ดังนั้น backend ต้อง:

- เพิ่มเวลา/เงิน **เฉพาะ** เมื่อ server เห็นการจ่ายเงินจริง (PromptPay เข้าบัญชี, สลิปผ่าน, พนักงานรับเงินสด) หรือหักจากยอดในบัญชีที่ server เก็บเอง
- ไม่มี endpoint ที่ client บอกว่า "จ่ายแล้ว" หรือ "เพิ่ม N วินาที"
- ไม่เชื่อค่าจาก client: `usedSec` (heartbeat), `amount` / `seconds` (`/billing/promptpay`), `total` / ราคาใน `items` (`/shop/buy`) — ทาง B ส่งแค่ `key` / `productId` + `expectedPrice` ให้ server คิดราคาเองแล้วเทียบ (`priceChanged` ถ้าไม่ตรง)

---

## 5. Flow ร้านไอดี (ระบบซื้อขายรหัส)

### 5.1 ขั้นตอน (ทาง B)

```
แท็บ "ซื้อไอดี"   GET shop ─▶ การ์ดสินค้า (ราคา, เหลือ N, ยอดเงิน)
                  กด "ซื้อ" ─▶ หน้ายืนยัน (ยอดเงิน → เหลือ)
                  กด "ซื้อเลย" ─▶ POST buy {productId, expectedPrice}
                                 ├─ สำเร็จ ─▶ หน้าต่าง "ซื้อสำเร็จ" โชว์ secret ทันที (+ ปุ่ม Steam Guard ถ้า steam)
                                 │            toast บน HUD "ดูได้ที่คลังรหัส" · โหลด shop ใหม่
                                 └─ priceChanged ─▶ โหลด shop ใหม่
แท็บ "คลังรหัส"   POST orders {list} ─▶ แถวละ order: ชื่อ · #id · วันที่ · ราคา
                  "ดูข้อมูลไอดี" ─▶ POST orders {reveal} ─▶ หน้าต่าง secret
                  "รับรหัส 2-Step" ─▶ steam: POST steam-guard · ไม่ใช่ steam: reveal แล้วหา 2FA ในข้อความ → รหัส 6 หลักสด
```

ไม่มีตะกร้า (ซื้อทีละชิ้น) · ไม่มีช่องติดต่อ / หมายเหตุ · หักจากยอดเงินในบัญชีที่ server เก็บ (เติมด้วย `topup` หรือเงินสดที่เคาน์เตอร์)

### 5.2 รูปแบบ `secret` — ไม่มีฟิลด์ username / password แยก

ข้อมูลไอดีทั้งหมดอยู่ใน **ข้อความหลายบรรทัดก้อนเดียว** (`secret`) หน้าจอแยกเป็นแถวเอง (`ShopTabs.jsx:119-152`, `totp.js:102-132`):

- แยกบรรทัดด้วย `\n` หรือ `\r\n` · ตัดช่องว่างหัวท้าย · บรรทัดว่างทิ้ง
- **บรรทัดขึ้นต้น `#` ไม่โชว์** ("ข้อมูลของร้าน") — แต่ถูกส่งถึงเครื่องลูกแล้ว (ข้อ 6)
- `ป้าย: ค่า` (ป้ายยาว 1–30 ตัว, ใช้ `:` หรือ `：`) → แถว [ไอคอน + ป้าย] [ค่า] [ปุ่มคัดลอก] · ไม่มี `:` → ทั้งบรรทัดเป็นค่า ไม่มีป้าย · บรรทัดที่เป็น URL ล้วน → แถวลิงก์ (คัดลอกได้ ไม่เปิดให้)
- ไอคอนเลือกจากคำในป้าย: `รหัส` / `pass` / `user` / `ชื่อผู้ใช้` / `account` / `email` / `อีเมล` / `ลิงก์` / `url` / `otp` ฯลฯ (`ShopTabs.jsx:75-87`)
- **คีย์ 2FA** ถูกจับเมื่อ (`totp.js:105-118`):
  - ป้ายตรงคำ `2fa`, `totp`, `authenticator`, `auth key`, `2-step`, `two-factor`, `secret key`, `otp key`, `รหัส 2`, `คีย์ 2`, `ยืนยันตัวตน 2` และค่าเป็น base32 16–128 ตัว (เว้นวรรค / ขีด / `=` ท้ายได้) หรือ
  - ลิงก์ `otpauth://totp/...?secret=...` หรือ
  - บรรทัด base32 ตัวพิมพ์ใหญ่ล้วน 16–64 ตัวที่มีตัวเลข 2–7 อย่างน้อยหนึ่งตัว
  
  → แถวนั้นโชว์คีย์ และใต้แถวมีกล่องรหัส 6 หลักสด + นับถอยหลัง + ปุ่มคัดลอก
- ปุ่ม "คัดลอก" ทุกแถว และ "คัดลอกทั้งหมด" (เฉพาะบรรทัดที่มองเห็น ต่อด้วย `\n`) — ไม่มีการซ่อน/แสดงรหัสผ่าน ค่าโชว์ตรงๆ
- `secret` ว่าง → "ไม่มีข้อมูลไอดี — สอบถามพนักงานที่เคาน์เตอร์"

ตัวอย่าง (ค่าปลอม):

```text
ชื่อผู้ใช้: demo_user_01
รหัสผ่าน: <รหัสผ่านของไอดี>
อีเมล: demo01@example.com
เว็บเมล: https://mail.example.com
2FA: JBSWY3DPEHPK3PXP
# บรรทัดนี้ไม่โชว์บนจอ แต่ถูกส่งมาถึงเครื่องลูก
```

### 5.3 ทาง A (ไม่ได้ต่อหน้าจอ)

`POST /shop/buy` และ `GET /shop/inventory?machineId=` ใน `api.js` ไม่มีหน้าจอเรียก (ข้อ 3.A) — README เก่าที่บอกว่ามี "ตะกร้า", "ช่องทางรับรหัส", "รหัสผ่าน (ซ่อน/แสดง)" **ไม่ตรงกับโค้ดปัจจุบัน** · `/shop/inventory` ใช้แค่ `machineId` ระบุเจ้าของ = ใครก็ขอรหัสของเครื่องอื่นได้ ห้ามทำแบบนั้น (ข้อ 6)

---

## 6. ความปลอดภัยที่ backend ต้องทำ

1. **คลังรหัสคืนรหัสผ่าน → ต้องยืนยันตัวตนต่อเครื่องและต่อลูกค้า**
   - ทาง B: token ใน `gcafe.json` ต้องผูกกับ "เครื่องนี้ + การเช่าปัจจุบัน + บัญชีลูกค้าคนนั้น" (comment `ShopTabs.jsx:4`: เว็บตรวจว่า token เป็นของการเช่าปัจจุบัน) · `orders` คืนเฉพาะของบัญชีที่กำลังเช่า · token ต้องใช้ไม่ได้ทันทีเมื่อการเช่าจบ (หมุน token)
   - **ถือว่าลูกค้าเห็น token ได้**: เมนูรันในบัญชี Windows ของลูกค้าและอ่าน `gcafe.json` ได้ (`main.js:181`) โปรแกรมอื่นของบัญชีเดียวกันจึงอ่านได้ด้วย → สิทธิ์ของ token ต้องไม่เกินสิทธิ์ของลูกค้าคนนั้น
   - ทาง A: **ไม่มีการยืนยันตัวตนเลย** (`Authorization` ไม่ถูกส่ง ข้อ 2.1) → ห้ามทำ endpoint ที่คืนรหัส / แตะเงิน / แตะเวลาบนทาง A จนกว่าจะแก้โค้ดเมนูให้มี token ต่อเครื่อง
   - ใช้ HTTPS ถ้าเซิร์ฟเวอร์ไม่ได้อยู่ใน LAN ร้าน · **(ข้อแนะนำ)** ใน LAN ก็ควรใช้ เพราะ HTTP ในวงเดียวกันดักอ่านได้
2. **`X-Machine-ID` ปลอมได้** — ค่าคือชื่อเครื่อง (เดาได้ เช่น `KORI01`…) ใครใน LAN ก็ใส่ header เองได้ด้วย curl · `machineId` ใน query/body ก็เช่นกัน → ใช้แค่ "ระบุ" ไม่ใช่ "ยืนยัน" · **(ข้อแนะนำ)** IP ก็ปลอมได้ ใช้ token ต่อเครื่องแบบทาง B
3. **`/games` (ทาง A) = สั่งรันคำสั่งบนเครื่องลูก** — `cmd` ของทุกเกมรันด้วย shell (`main.js:311-316`) ใครคุม response ได้ = รันโปรแกรมได้ทุกเครื่อง · ต้องจำกัดคนแก้รายการเกม และใช้ HTTPS · **(ข้อแนะนำ)** ถ้าไม่จำเป็นอย่าตอบ `/games` (ตอบ `[]` → เมนูใช้ `games.json` ของ OSYNC)
4. **Rate limit ฝั่ง server** (หน้าจอไม่ได้จำกัดอะไร): `login` (เดารหัสผ่านจากหน้าล็อก), `coupon check/merge` และ `ticket` (เดารหัสคูปอง/บัตร — comment บอกว่าเว็บเดิมล็อกที่ 5 ครั้ง), `qr-login`, `steam-guard` (เปิดเมล), `orders reveal`, `topup create` (สร้าง QR รัวๆ), `chat send`
5. **PromptPay ยืนยันฝั่ง server เท่านั้น** — หน้าจอแค่ poll `status`; server ต้องจับคู่เงินเข้าเอง (ยอดเฉพาะคนที่มีเศษสตางค์ตามที่หน้าจอบอกลูกค้า `TopupPanel.jsx:110` / ตรวจสลิป) และตั้งเวลาหมดอายุ QR · ห้ามมีทางที่ client ประกาศว่าจ่ายแล้ว (ข้อ 4.4)
6. **ไม่เชื่อค่าจาก client**: `usedSec`, `amount`, `seconds`, `total`, ราคา, `createdAt`, `time`, `sender` — `expectedPrice` ใช้แค่เทียบแล้วตอบ `priceChanged`
7. **บรรทัด `#` ใน `secret` ซ่อนแค่บนจอ** (`totp.js:120-123`) ข้อมูลถึงเครื่องลูกแล้ว และคนที่ถือ token เรียก `orders reveal` เองก็เห็น → อย่าใส่ข้อมูลที่ลูกค้าห้ามรู้ (เช่น token เข้าเมล) — เก็บไว้ฝั่ง server แบบที่ `steam-guard` ทำ
8. **CORS ทาง A**: **(ข้อแนะนำ)** ตอบ `Access-Control-Allow-Origin` เฉพาะ `http://127.0.0.1:<พอร์ต>` — ถ้าใช้ `*` หน้าเว็บอะไรก็ได้ที่เปิดในเบราว์เซอร์เครื่องไหนก็ได้ในวงร้านจะอ่าน API นี้ได้ (CORS กัน curl ไม่ได้ จึงไม่ใช่การยืนยันตัวตน)
9. **ฝั่งเครื่องลูก** (ไม่ใช่งาน backend แต่กระทบความปลอดภัย): clipboard ไม่ถูกล้างเมื่อจบการเช่า และหน้าล็อกปิดเองเมื่อเอเจนต์หยุด (ข้อ 8 ข้อ 12, 24)

**(ข้อแนะนำ) ประมาณโหลด** สำหรับ N เครื่อง: ทาง A heartbeat ≈ N/30 ครั้งต่อวินาที (+ preflight ถ้าไม่ตั้ง `Access-Control-Max-Age`) · ทาง B `state` ทุก 15 วิต่อเครื่องที่ล็อกอยู่ + ทุก 60 วิต่อเครื่องที่เปิดเมนู + poll ของแท็บที่เปิดอยู่ (ตารางข้อ 3.B) — ภาระที่เอเจนต์ยิงเองไม่ระบุในโค้ดเมนู

---

## 7. Checklist และแผนทดสอบขั้นต่ำ

### 7.1 Checklist ก่อนเปิดใช้จริง

- [ ] เลือกแล้วว่าจะใช้ทาง A หรือทาง B (ข้อ 0) — ระบบซื้อขายรหัส / เติมเงิน / หน้าล็อก ต้องทาง B
- [ ] ทุก endpoint ตอบ JSON เสมอ (ทาง A: 2xx + JSON · ทาง B: ล้มเหลวตอบ `{"ok": false, "error": "ข้อความไทย"}`)
- [ ] ทาง A: CORS + preflight ผ่านสำหรับ Origin `http://127.0.0.1:<พอร์ตใดก็ได้>`
- [ ] ทาง A: `apiUrl` ไม่มี `/` ท้าย, ตอบภายใน 4 วิ
- [ ] ทาง B: `gcafe.json` (`server`, `token` ขึ้นต้น `gt_`) และ `state.json` (`updatedAt` สดภายใน 60 วิ) เขียนครบ · โฟลเดอร์ `gcafe\` ให้ผู้ใช้ทั่วไปเขียนได้
- [ ] ทาง B: เงินเป็นสตางค์ทุกช่อง ยกเว้น `topup create amount` และ `min/max` (บาท) · เวลาที่คำนวณเป็น ms epoch
- [ ] ทาง B: `state.topup` และ `panel.topupCfg` มีเสมอ (ไม่งั้นกล่องเติมเงินค้าง)
- [ ] token ผูกกับการเช่า, หมุนเมื่อจบ, ตอบ 409 ระหว่างเตรียม
- [ ] rate limit ครบตามข้อ 6 ข้อ 4 · PromptPay ยืนยันฝั่ง server
- [ ] `config.json`: `ui.menuOnly: false` (และ `sidePanel` ตามต้องการ) · JSON ถูกต้อง · รีบูตเครื่องลูก

### 7.2 ตัวอย่าง curl

ไวยากรณ์ bash (Git Bash / Linux) · บน PowerShell ใช้ `curl.exe` และส่ง body จากไฟล์ (`-d "@body.json"`) เพราะ PowerShell 5.1 ตัดเครื่องหมายคำพูดใน JSON · ค่าใน `<...>` เปลี่ยนเป็นของจริงตอนทดสอบ

**ทาง A**

```bash
API=http://192.168.51.202:8000/api
H=(-H "Content-Type: application/json" -H "X-Machine-ID: KORI12")

# CORS preflight (ต้องได้ Access-Control-Allow-Origin / -Headers ตามข้อ 2.1)
curl -i -X OPTIONS "$API/station/session?machineId=KORI12" \
  -H "Origin: http://127.0.0.1:53123" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: content-type,x-machine-id"

# ใช้จริง
curl -i "$API/station/session?machineId=KORI12" "${H[@]}" -H "Origin: http://127.0.0.1:53123"
curl -i -X POST "$API/station/heartbeat" "${H[@]}" -d '{"machineId":"KORI12","usedSec":2730}'
curl -i -X POST "$API/station/logout"    "${H[@]}" -d '{"machineId":"KORI12"}'
curl -i "$API/games?category=all" "${H[@]}"
curl -i -X POST "$API/games/launch" "${H[@]}" -d '{"machineId":"KORI12","title":"VALORANT","cmd":"<cmd>","id":"riot-valorant"}'

# ไม่มีหน้าจอเรียก (ใช้ทดสอบเมื่อมีคนต่อหน้าจอในอนาคต)
curl -i -X POST "$API/station/lock"       "${H[@]}" -d '{"machineId":"KORI12","pin":"<pin>"}'
curl -i -X POST "$API/games/sync-save"    "${H[@]}" -d '{"machineId":"KORI12","email":"<email>","password":"<password>"}'
curl -i -X POST "$API/system/mouse"       "${H[@]}" -d '{"val":50}'
curl -i "$API/shop/games?category=all"    "${H[@]}"
curl -i -X POST "$API/shop/buy"           "${H[@]}" -d '{"machineId":"KORI12","items":[{"id":1,"qty":1}],"total":350,"contact":"","note":"","createdAt":"2026-11-18T10:00:00.000Z"}'
curl -i "$API/shop/inventory?machineId=KORI12" "${H[@]}"
curl -i "$API/counter/chat?machineId=KORI12"   "${H[@]}"
curl -i -X POST "$API/counter/chat"       "${H[@]}" -d '{"machineId":"KORI12","sender":"me","text":"ทดสอบ","time":"10:00"}'
curl -i "$API/billing/packages"           "${H[@]}"
curl -i -X POST "$API/billing/promptpay"  "${H[@]}" -d '{"machineId":"KORI12","packageId":1,"amount":20,"seconds":3600}'
curl -i "$API/member/me"                  "${H[@]}"
curl -i -X POST "$API/member/redeem"      "${H[@]}" -d '{"privilegeId":1}'
```

**ทาง B**

```bash
S=https://shop.example          # ค่า server ใน gcafe.json
T=gt_<token ทดสอบ>
H=(-H "Authorization: Bearer $T" -H "Content-Type: application/json")
G="$S/api/gcafe"

curl -s "$G/state" "${H[@]}"
# หน้าล็อก
curl -s -X POST "$G/login"    "${H[@]}" -d '{"username":"demo","password":"<password>","code":""}'
curl -s -X POST "$G/start"    "${H[@]}" -d '{"pass":"<pass จาก login>","option":"p1"}'
curl -s -X POST "$G/qr-login" "${H[@]}" -d '{"action":"create"}'
curl -s -X POST "$G/qr-login" "${H[@]}" -d '{"action":"poll","id":"<id>"}'
curl -s -X POST "$G/ticket"   "${H[@]}" -d '{"code":"K7Q9M2XD4P"}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"check","code":"AFQW1FA2"}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"merge","code":"AFQW1FA2","add":"<อีกใบ 8 ตัว>"}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"start","code":"AFQW1FA2","option":"p1","expectedPrice":2000}'
# ระหว่างเล่น
curl -s "$G/panel" "${H[@]}"
curl -s -X POST "$G/extend"   "${H[@]}" -d '{"key":"hours:2","expectedPrice":4000}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"panel"}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"extend","key":"p1","expectedPrice":2000}'
curl -s -X POST "$G/coupon"   "${H[@]}" -d '{"action":"panelMerge","add":"<8 ตัว>"}'
curl -s -X POST "$G/logout"   "${H[@]}" -d '{}'
# เติมเงิน
curl -s -X POST "$G/topup"    "${H[@]}" -d '{"action":"create","amount":100}'
curl -s -X POST "$G/topup"    "${H[@]}" -d '{"action":"status","id":"<id>"}'
curl -s -X POST "$G/topup"    "${H[@]}" -d '{"action":"cancel","id":"<id>"}'
curl -s -X POST "$G/topup"    "${H[@]}" -d '{"action":"create","amount":100,"pass":"<pass>"}'   # แบบหน้าล็อก
# ร้านไอดี + คลังรหัส
curl -s "$G/shop" "${H[@]}"
curl -s -X POST "$G/buy"      "${H[@]}" -d '{"productId":12,"expectedPrice":35000}'
curl -s -X POST "$G/orders"   "${H[@]}" -d '{"action":"list"}'
curl -s -X POST "$G/orders"   "${H[@]}" -d '{"action":"reveal","orderId":345}'
curl -s -X POST "$G/steam-guard" "${H[@]}" -d '{"orderId":345}'
# แชท / บัญชี / สถิติ
curl -s -X POST "$G/chat"     "${H[@]}" -d '{"action":"list"}'
curl -s -X POST "$G/chat"     "${H[@]}" -d '{"action":"open","ticketId":7}'
curl -s -X POST "$G/chat"     "${H[@]}" -d '{"action":"send","body":"ทดสอบ"}'
curl -s -X POST "$G/account"  "${H[@]}" -d '{}'
curl -s -X POST "$G/launch"   "${H[@]}" -d '{"title":"VALORANT"}'

# ความปลอดภัย: ต้องถูกปฏิเสธ
curl -s -X POST "$G/orders" -H "Content-Type: application/json" -d '{"action":"list"}'                                  # ไม่มี token
curl -s -X POST "$G/orders" -H "Authorization: Bearer <token เก่าหลังจบการเช่า>" -H "Content-Type: application/json" -d '{"action":"list"}'
```

### 7.3 ทดสอบบนเครื่องลูกเครื่องเดียวก่อนเปิดทุกเครื่อง

`Menu\config.json` ใช้ร่วมกันทุกเครื่อง แก้แล้วทุกเครื่องได้ค่าใหม่หลังรีบูต จึง **ไม่ควรแก้ไฟล์กลางเพื่อทดสอบ** · **(ข้อแนะนำ)** ใช้สำเนาเมนูบนไดร์ฟ C: ของเครื่องทดสอบ (diskless: รีบูตแล้วหายเอง)

1. เครื่องลูก 1 เครื่อง (ไม่ใช่โหมด super workstation) ล็อกอินแบบแอดมิน
2. คัดลอก `<ไดร์ฟเกม>\OSYNC\Menu\app` และ `Menu\data` ไปเป็น `C:\MenuTest\app` และ `C:\MenuTest\data` — โปรแกรมหา `config.json` และ `data\` ที่โฟลเดอร์แม่ของ `app\` (`main.js:42-46`)
3. สร้าง `C:\MenuTest\config.json`:
   ```json
   { "brandName": "0JAYSHOP", "apiUrl": "http://192.168.51.202:8000/api", "machineId": "", "ui": { "menuOnly": false, "sidePanel": true } }
   ```
   (ทดสอบทาง B อย่างเดียว ให้ `apiUrl` เป็น `""`)
4. ปิดเมนูตัวจริงด้วย Task Manager (โปรแกรมเปิดได้ทีละตัวต่อเครื่อง `main.js:21-24` และเมนู tray ไม่มีปุ่มออก `main.js:587`) แล้วเปิด `C:\MenuTest\app\0JAYSHOP.exe`
5. ทาง B ต้องมี `gcafe.json` + `state.json` บนเครื่องนั้น — เครื่องอื่นที่ไม่มีไฟล์ยังเป็นออฟไลน์เหมือนเดิม (TEST-PLAN F-10) · ถ้ายังไม่มีเอเจนต์จริง ใช้สคริปต์จำลองด้านล่าง **เฉพาะเครื่องที่ไม่มีเอเจนต์จริง** (ทับไฟล์ของเอเจนต์จริง)
6. ผ่านครบตาม 7.4 แล้วจึงแก้ `Menu\config.json` กลาง แล้วรีบูตเครื่องลูกทั้งหมด

**(ข้อแนะนำ) สคริปต์จำลองเอเจนต์สำหรับนักพัฒนา** — รันแบบแอดมิน, ทำงาน `$Minutes` นาทีแล้วหยุดและลบไฟล์เอง · ไม่ใส่ `-Rental` = เครื่องว่าง → **หน้าล็อกคลุมทุกจอ** จนสคริปต์หยุด (หลังหยุดไม่เกิน 60 วิหน้าล็อกหาย `main.js:182`) · ใส่ `-Rental` = มีการเช่า 1 ชั่วโมง

```powershell
param([string]$Server = 'http://192.168.51.202:8000', [string]$Token = 'gt_test_only', [int]$Minutes = 10, [switch]$Rental)
$d = Join-Path $env:ProgramData 'CooperAgent'
New-Item -ItemType Directory -Force $d | Out-Null
@{ server = $Server; token = $Token } | ConvertTo-Json | Set-Content -Encoding ascii (Join-Path $d 'gcafe.json')
$start = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$stop = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $stop) {
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $sess = $null
  if ($Rental) { $sess = @{ id = 1; mode = 'hourly'; source = 'web'; user = 'test'; startedAt = $start; endsAt = $start + 3600000 } }
  @{ updatedAt = $now; online = $true; serverOffsetMs = 0; machineName = $env:COMPUTERNAME; session = $sess } |
    ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii (Join-Path $d 'state.json')
  Start-Sleep -Seconds 5
}
Remove-Item (Join-Path $d 'gcafe.json'), (Join-Path $d 'state.json')
```

### 7.4 แผนทดสอบขั้นต่ำ

| ID | ทำอะไร | ต้องเห็น |
|---|---|---|
| A-01 | `apiUrl` ว่าง | HUD `Guest` / `Offline` / `00:00:00` ทันที, server ไม่ได้รับ request |
| A-02 | session ตอบ `totalSec: 3600, usedSec: 0` | HUD `01:00:00` นับลงทุกวินาที |
| A-03 | ดู log server 2 นาที | heartbeat ทุก ~30 วิ, `usedSec` เพิ่มทีละ 30 · preflight `OPTIONS` ผ่าน |
| A-04 | ปิด server แล้วเปิดโปรแกรม | ภายใน 4 วิ HUD เป็น `Offline`, เมนูเกมยังใช้ `games.json` ได้ |
| A-05 | `/games` ตอบ array / `[]` | array = เมนูใช้รายการ server · `[]` = ใช้ `games.json` |
| A-06 | ปล่อยเวลาหมด | ยืนยันว่าเครื่อง **ไม่ล็อก** (ทาง A ไม่มีหน้าล็อก) — ร้านรับได้หรือไม่ |
| B-01 | `state.json` `session: null` | หน้าล็อกทุกจอ, เปิดเมนูไม่ได้, `alive.json` `showing: "lock"` |
| B-02 | login ผิด / ถูก / บัญชีเปิด 2 ชั้น | ข้อความไทยจาก `error` · ช่อง 6 หลักขึ้นเมื่อได้ `TOTP_REQUIRED` |
| B-03 | start / QR / คูปอง / บัตร | "เครื่องกำลังปลดล็อก…" แล้วหน้าล็อกหายเมื่อ `state.json` มี `session` |
| B-04 | ตั้ง `serverOffsetMs` ±60000 | เวลาเหลือบน HUD ตรงกับ server ไม่ใช่นาฬิกาเครื่อง |
| B-05 | ปล่อย `endsAt` ผ่านไป | server จบการเช่า → `session: null` → หน้าล็อกภายใน 1 วิ |
| B-06 | ต่อเวลา, ราคาเปลี่ยนระหว่างเลือก, ตอบ 409 ครั้งแรก | `endsAt` เลื่อน · `priceChanged` โหลดใหม่ · 409 ลองซ้ำเองแล้วผ่าน |
| B-07 | เติมเงิน auto ด้วยยอดน้อยที่สุด / ปล่อยหมดเวลา | `success` ยอดขึ้น · `expired` "หมดเวลาแล้ว" · ไม่มีเงินขึ้นถ้าไม่ได้จ่ายจริง |
| B-08 | ซื้อไอดี → คลังรหัส → ดูข้อมูล → 2-Step | `secret` แยกแถวถูก, บรรทัด `#` ไม่โชว์, รหัส 6 หลักตรงกับแอป authenticator, Steam Guard ได้โค้ด |
| B-09 | ความปลอดภัย | token เครื่อง A ขอ `orders` ของลูกค้าเครื่อง B ไม่ได้ · token หลังจบการเช่าใช้ไม่ได้ · login ผิดเกินกำหนดถูกจำกัด |
| B-10 | แชท / บัญชี | ส่งข้อความแล้วเห็นในหลังบ้าน, คำตอบขึ้นเองภายใน 15 วิ · หน้าบัญชีครบไม่ error |
| B-11 | ออกจากระบบ | toast เก็บเวลา / คืนคูปอง → หน้าล็อกกลับมา · ลูกค้าคนถัดไปไม่เห็นข้อมูลคนก่อน |
| B-12 | หยุดเอเจนต์ (หรือหยุดสคริปต์จำลอง) | ภายใน 60 วิ เมนูถือว่าออฟไลน์ — ตรวจว่าเอเจนต์จริงล็อกเครื่องเองแทน (ข้อ 8 ข้อ 12) |

---

## 8. ยังไม่ชัด / ข้อสังเกตในโค้ดเมนู

ข้อที่กระทบการต่อเซิร์ฟเวอร์ (ไม่ได้แก้โค้ดใดๆ — บันทึกไว้ให้ตัดสินใจ)

1. **เอกสารเก่าอธิบายผิด** (20 พ.ย. 2026: `Menu\source\README.md` และ `Menu\README-TH.txt` เขียนใหม่ให้ตรงโค้ดแล้ว ข้อความด้านล่างเป็นบันทึกของฉบับเก่า · `_help` ใน `config.json` ยังเหมือนเดิม) — `source/README.md:62-148` และ `Menu/README-TH.txt:78-90` บอกว่าตั้ง `apiUrl` แล้วร้านไอดี / แชท / เติมเงิน / สมาชิกใช้ได้ (จริง: ใช้ทาง B) · `source/README.md:66-69` บอกค่าเริ่ม `http://127.0.0.1:8000/api` และ key `0jayshop_api_url` (จริง: ค่าเริ่มว่าง `config.js:12`, key `gcafe_api_url` `config.js:24`) · `source/README.md:152-163` บอกฟอร์มตั้งค่าลับ `Ctrl+Shift+S` (ถูกเอาออกแล้ว `app/page.jsx:324`) · `README-TH.txt` ยังใช้ path `H:\OSYNC\GCafe` · `_help` ใน `config.json` ชวนให้คิดว่าตั้ง `apiUrl` แล้วทุกระบบพร้อม
2. **โค้ด REST ที่ไม่มีใครเรียก** — `sessionService.lock` (`api.js:71-76`), `gameShopService` ทั้งชุด + `menuService` (`api.js:89-125`, `api.js:177`), `chatService` (`api.js:182-210`), `topupService` (`api.js:215-240`), `memberService` (`api.js:245-260`), `syncCloudSave` (`api.js:161-166`), `setMouseSensitivity` (`api.js:168-173`) · ใน `config.js`: `isOnline` (29-31), `setApiBaseUrl` (33-37), `setMachineId` (48-52), `setAuthToken` (143-151)
3. **ทาง A ไม่มีที่มาของ token** — `getAuthToken` อ่าน localStorage อย่างเดียว (`config.js:136-141`) และไม่มีโค้ดเขียน → header `Authorization` (`api.js:16`) ไม่เคยถูกส่ง
4. **ทาง A เวลาหมดไม่ล็อก / ไม่ออกจากระบบ** และไม่เรียก `/station/lock` (`app/page.jsx:71-83`) — หน้าล็อกผูกกับทาง B เท่านั้น (`main.js:273`)
5. **ทาง A ไม่ดึงเวลาใหม่** — `getSession` ครั้งเดียว (`app/page.jsx:56-68`), ผล heartbeat ไม่ถูกอ่าน (`app/page.jsx:76`) → เวลาที่ server เพิ่ม/ลดไม่ขึ้นจนเปิดโปรแกรมใหม่
6. **heartbeat ผูกกับ `usedSec % 30`** ไม่ใช่ตัวจับเวลา (`app/page.jsx:74-76`) — ไม่ส่งเมื่อ `totalSec = 0` หรือเวลาหมด → ใช้เป็นสัญญาณ "เครื่องยังเปิดอยู่" ไม่ได้ · และเรียกจากใน state updater ของ React
7. **ออกจากระบบทาง A** ไม่สนผล ซ่อน HUD ทันที ไม่รีเซ็ตตัวนับ (`app/page.jsx:181-182`) · ข้อความสัญญาว่าเวลาที่เหลือเก็บเข้าบัญชีสมาชิก (`app/page.jsx:115`) — server ต้องทำให้จริง
8. **`menuOnly: true`** — HUD ถูกซ่อนแต่ยังโหลด จึงยังเรียก `/station/session` + heartbeat ถ้าตั้ง `apiUrl` (`main.js:506`, `main.js:512`) · หน้าล็อกทาง B ยังทำงาน แต่ลูกค้าไม่มีปุ่มออกจากระบบและไม่เห็นเวลาเหลือ (ปุ่มอยู่บน HUD เท่านั้น `app/page.jsx:267-272`; แท็บว่าง `dialog/page.jsx:312`; ชิปเวลาซ่อน `dialog/page.jsx:330`)
9. **เปิดทั้งสองทางพร้อมกัน** — HUD ใช้เวลาจากเอเจนต์ แต่ยังส่ง heartbeat ทาง A ตาม `totalSec` ของทาง A (`app/page.jsx:71-83`) · ออกจากระบบไปทาง B อย่างเดียว (`app/page.jsx:162-180`) · การเปิดเกมรายงานทั้งสองทาง (`api.js:154-157`, `main.js:320`)
10. **Bug: `sess.coupon` ไม่มีวันมีค่า** — `readAgent` คัดลอกเฉพาะ `id, mode, source, user, startedAt, endsAt, balanceText, rateText` (`main.js:188-192`) ไม่มี `coupon` → HUD โชว์ "ลูกค้าทั่วไป" แทน "คูปอง XXXX" (`app/page.jsx:111`) และข้อความยืนยันออกจากระบบบอกลูกค้าคูปองว่า "ลูกค้าทั่วไปเก็บเวลาไม่ได้ — เวลาที่เหลือจะหายไป" ทั้งที่ระบบคืนเงินเข้าคูปอง (`app/page.jsx:118-122`) · ชื่อฟิลด์ coupon ใน `state.json` จึงไม่ระบุในโค้ด
11. **`ending` ไม่ชัด** — ระหว่าง `ending` หน้าล็อกไม่ขึ้น (`main.js:273`) ข้อความ `ending.text` บนหน้าล็อก (`lock/page.jsx:308`) จึงแทบไม่มีโอกาสเห็น และ HUD ไม่โชว์ `ending` · ใครตั้ง ตั้งนานเท่าไร ไม่ระบุในโค้ดเมนู
12. **หน้าล็อกปิดเองเมื่อเอเจนต์หยุด (fail-open)** — `state.json` เก่ากว่า 60 วิ → `integrated = false` → ปิดหน้าล็อก ปลดเครื่อง (`main.js:182`, `main.js:273-277`) · ต้องพึ่งเอเจนต์ล็อกเองแทน (ตรงข้ามกับ `alive.json` ที่ให้เอเจนต์ล็อกเมื่อเมนูหาย `main.js:162`, `main.js:214`)
13. **โหมดเครดิต** (`endsAt: null`) HUD โชว์ "เวลาคงเหลือ 00:00:00" และแถบ 0% ระหว่างที่ลูกค้าเล่นอยู่ (`app/page.jsx:104`, `app/page.jsx:110`)
14. **หน่วยเงินปนกัน** — `topup create amount`, `topup.min/max` เป็นบาท (`TopupPanel.jsx:48`, `TopupPanel.jsx:72-75`) ส่วนอื่นเป็นสตางค์ (`TopupPanel.jsx:15-18`, `TopupPanel.jsx:109`)
15. **เติมเงินโหมด slip / web ถือว่าสำเร็จเมื่อ `balance` สูงขึ้น** (`TopupPanel.jsx:62-63`) — เงินเข้าทางอื่นระหว่างนั้น (เช่นพนักงานเติมเงินสด) ก็ขึ้นว่าเติมสำเร็จ · `status` ส่ง `id: 0` ในโหมดนี้ (`TopupPanel.jsx:55`) ความหมายฝั่ง server ไม่ระบุ
16. **`/games` ทาง A** — `cmd` รันด้วย shell (`main.js:311-316`) · คลิกขวาหาตำแหน่งไฟล์ใช้ `games.json` เท่านั้น (`main.js:404-406`, `main.js:870-886`) · ไอคอนอัตโนมัติไม่ใส่ให้รายการจาก server (`main.js:653`) · `q` ไม่เคยถูกส่ง (`dialog/page.jsx:151`)
17. **เกมในหน้าต่างเลือกระดับภาพ** (GTA V / FiveM) ไม่รายงาน `/games/launch` ทาง A (`dialog/page.jsx:215`) แต่รายงาน `launch` ทาง B (`main.js:864` → `main.js:320`)
18. **`/games/launch` ส่ง `cmd` ทั้งบรรทัด** (path ในเครื่อง) ไป server และส่งแม้เปิดเกมไม่สำเร็จ (`api.js:145-157`)
19. **`brand` จาก `/station/session` ค้างถาวร** ใน localStorage และทับ `config.json` แม้เลิกใช้ server (`api.js:48-50`, `config.js:57-70`) · เห็นผลตอนเปิดหน้าครั้งถัดไปเพราะ HUD อ่านแบรนด์ก่อน session ตอบ (`app/page.jsx:57-60`)
20. **localStorage ชนะ `config.json`** (`config.js:24`, `config.js:43`) — Image ที่เคยบันทึก `gcafe_api_url` / `gcafe_machine_id` จากฟอร์มรุ่นเก่า (`%APPDATA%\0jayshop-timer-client`) จะไม่สนค่าใน `config.json`
21. **`config.json` พัง = ค่าเริ่มทั้งหมด** (`main.js:48-54`, `main.js:109`) — `menuOnly` กลายเป็น `false` (HUD + แท็บร้านโผล่), `brandName` กลายเป็น `0JAYSHOP`
22. **ชื่อเครื่องบน HUD** — ระหว่างรอ session โชว์ค่าตั้งต้น `PC-12` (`app/page.jsx:10`) ได้นานสุด 4 วิ · session ที่ไม่มี `machineId` ทำให้ชื่อว่าง (`app/page.jsx:63`, `app/page.jsx:112`) · ค่าเริ่มของ `machineId` มาจาก `os.hostname()` (`main.js:120`) ตัวพิมพ์ใหญ่/เล็กขึ้นกับ Windows — **(ข้อแนะนำ)** server เทียบแบบไม่สนตัวพิมพ์
23. **HTTPS ใบรับรองภายใน** — ไม่มีตัวจัดการ `certificate-error` ทั้งไฟล์ `main.js` · ทาง B ยิงด้วย `fetch` ของ Node ซึ่งอาจไม่ได้อ่าน CA ที่ติดตั้งใน Windows (ยังไม่ได้ทดสอบ)
24. **Clipboard ไม่ถูกล้างเมื่อจบการเช่า** — รหัสที่ลูกค้ากดคัดลอก (`ShopTabs.jsx:70-72`) ยังอยู่หลังหน้าล็อกขึ้น (`showLock` `main.js:218-247` ไม่ล้าง) ลูกค้าคนถัดไปกดวางได้ ถ้าไม่ได้รีบูตระหว่างคน
25. **บรรทัด `#` ใน `secret` ซ่อนแค่บนจอ** (`totp.js:120-123`) — ข้อมูลถึงเครื่องลูกแล้ว
26. **หน้าล็อกตอนยังโหลด `state` ไม่ได้ ถือว่า `loginAllowed`** (`lock/page.jsx:139`) — ฟอร์มขึ้นแม้ server ล่ม error ไปโผล่ตอนกด · `state.topup` ไม่มี = กล่องเติมเงินค้าง "กำลังโหลด…" (`TopupPanel.jsx:86`)
27. **อายุ `pass` ของหน้าล็อก** นับฝั่งเครื่อง 110 วิ (`lock/page.jsx:77`) ขยายเมื่อเติมเงิน (`lock/page.jsx:387-389`) — อายุจริงฝั่ง server และการขยายเมื่อมี QR ค้าง ไม่ระบุในโค้ดเมนู (มีแค่ comment)
28. **ไม่มี "แต้ม / สิทธิพิเศษ"** ในหน้าจอที่ใช้งาน — แท็บบัญชีทาง B ไม่มี (`ShopTabs.jsx:668-713`) ส่วน `/member/me`, `/member/redeem` ไม่มีที่เรียก
29. **ฟิลด์ที่ส่งมาแต่ไม่ได้ใช้** — `session.id`, `session.rateText` (`main.js:189-191`), `qr-login` `url`, `/station/session` `username`, `isOffline` (`api.js:60`)
30. **วิธีติดตั้งเอเจนต์ / ใครสร้างโฟลเดอร์ `gcafe\`** ไม่อยู่ในโค้ดเมนูและไม่มีตัวติดตั้งใน OSYNC — ข้อ 2.3 คือทั้งหมดที่เมนูต้องการ
