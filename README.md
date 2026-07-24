# Event Booking API

Backend API สำหรับระบบจองตั๋วคอนเสิร์ต สร้างด้วย Ruby on Rails (API-only mode) และ PostgreSQL ออกแบบตามหลัก **Clean Architecture**

---

## 1. วิธีรันโปรเจกต์

### วิธีที่ 1: Docker Compose (แนะนำ — ใช้งานได้ทุก OS)

```bash
docker compose up --build
```

ระบบจะทำทุกอย่างให้อัตโนมัติ: build container → รอ PostgreSQL พร้อม → migrate → seed ข้อมูลตัวอย่าง

API พร้อมใช้งานที่: **http://localhost:3000**

---

### วิธีที่ 2: รันแบบ Native (ต้องมี Ruby 3.x + PostgreSQL)

```bash
# 1. ติดตั้ง dependencies
bundle install

# 2. ตั้งค่า database
export DATABASE_URL="postgres://postgres:password@localhost:5432/event_booking_development"

# 3. สร้าง DB + migrate + seed ข้อมูลตัวอย่าง
bin/rails db:create db:migrate db:seed

# 4. เริ่ม server
bin/rails server
```

รัน RSpec tests:
```bash
bundle exec rspec
```

---

## ข้อมูลเริ่มต้นสำหรับทดสอบ (Mock Data)

โปรเจกต์นี้มาพร้อมข้อมูลจำลองผ่าน `db/seeds.rb` ซึ่งช่วยเตรียมระบบทดสอบทันทีเมื่อสั่งรัน โดยประกอบด้วยอีเวนต์ดังต่อไปนี้:

1. **Coldplay Music of the Spheres World Tour**
   - วันจัดงาน: (1 เดือนถัดไป)
   - จำนวนที่นั่งจำลองเริ่มต้น (Capacity): **100 ที่นั่ง**
2. **Taylor Swift The Eras Tour**
   - วันจัดงาน: (2 เดือนถัดไป)
   - จำนวนที่นั่งจำลองเริ่มต้น (Capacity): **50 ที่นั่ง**
3. **Ed Sheeran +-=÷x Tour**
   - วันจัดงาน: (3 เดือนถัดไป)
   - จำนวนที่นั่งจำลองเริ่มต้น (Capacity): **5 ที่นั่ง** *(เหมาะสำหรับนำไปทดสอบกรณีที่นั่งเหลือน้อยหรือทดสอบ Race Condition)*

### การรีเซ็ตยอดจองและตั๋ว (Reset Database)
หากจองตั๋วจนหมดแล้วต้องการเริ่มทดสอบใหม่จากศูนย์ สามารถทำได้ดังนี้:

**กรณีใช้ Docker:**
```bash
# ลบ volume และสร้างฐานข้อมูลพร้อมเมล็ดพันธุ์ข้อมูลใหม่
docker compose down -v && docker compose up --build
```

**กรณีรันแบบ Native:**
```bash
bin/rails db:seed
```

---

## 2. ทดสอบด้วย Postman

### วิธี Import Collection

1. เปิด Postman
2. คลิก **Import** → เลือกไฟล์ `postman_collection.json` ในโปรเจกต์นี้
3. คลิก Collection → **Variables** → ตรวจสอบว่า `base_url = http://localhost:3000`

### ขั้นตอนการทดสอบ

> **⚠️ สำคัญ**: ต้องรัน **Folder 1 (Setup)** ก่อนเสมอ เพื่อให้ระบบบันทึก `event_id` ที่ถูกต้องจาก Database ให้อัตโนมัติ (ID จริงใน DB อาจไม่ได้เริ่มที่ 1)

| ลำดับ | Folder | เนื้อหา |
|---|---|---|
| 1 | **1. Setup** | ดึงรายการ Event — บันทึก event_id อัตโนมัติ |
| 2 | **2. User Story 1** | ตรวจสอบข้อมูล Event (name, date, available_tickets) |
| 3 | **3. User Story 2 & 3** | ทดสอบจองตั๋วกรณีต่างๆ (สำเร็จ / error / ตั๋วไม่พอ) |
| 4 | **4. Inventory Tracking** | ตรวจสอบจำนวนตั๋วลดลงจริงหลังจอง |
| 5 | **5. Concurrency** | ทดสอบการป้องกัน Overbooking |

---

## 3. ทดสอบด้วย curl

### GET /events — ดูรายการ Event ทั้งหมด

```bash
curl http://localhost:3000/events
```

**Response (200 OK)**:
```json
[
  { "id": 1, "name": "Coldplay Music of the Spheres World Tour", "date": "...", "available_tickets": 100 },
  { "id": 2, "name": "Taylor Swift The Eras Tour",               "date": "...", "available_tickets": 50  },
  { "id": 3, "name": "Ed Sheeran +-=÷x Tour",                    "date": "...", "available_tickets": 5   }
]
```

> **หมายเหตุ**: ID จริงใน Database อาจไม่ใช่ 1, 2, 3 — ให้ดู `id` จาก response ก่อนแล้วใช้ค่านั้นใน request ถัดไป

---

### POST /events/:id/bookings — จองตั๋ว

แทน `EVENT_ID` ด้วย `id` ที่ได้จาก GET /events

```bash
curl -X POST http://localhost:3000/events/EVENT_ID/bookings \
  -H "Content-Type: application/json" \
  -d '{"booking": {"email": "john@example.com", "quantity": 2}}'
```

**กรณีสำเร็จ (201 Created)**:
```json
{
  "id": 1,
  "event_id": 2,
  "email": "john@example.com",
  "quantity": 2,
  "created_at": "2026-07-21T06:50:00.000Z"
}
```

**กรณีตั๋วไม่พอ (422)**:
```json
{ "error": "Only 48 ticket(s) remaining; you requested 9999." }
```

**กรณี Email ไม่ถูกรูปแบบ (422)**:
```json
{ "error": "Email is invalid" }
```

**กรณี Event ไม่มีในระบบ (404)**:
```json
{ "error": "Event does not exist" }
```

---

## 4. การทดสอบ Race Condition (ป้องกัน Overbooking)

ทดสอบว่าเมื่อผู้ใช้ 2 คนกดจองตั๋วใบสุดท้ายพร้อมกัน ระบบจะให้ตั๋วแค่คนเดียวเท่านั้น

### การรันผ่าน Docker (รองรับทุกระบบปฏิบัติการ Windows / macOS / Linux)

เนื่องจากระบบทำงานบน Docker อยู่แล้ว จึงสามารถสั่งรันจำลองการจองตั๋วพร้อมกันผ่านคำสั่งนี้ได้โดยตรง (ไม่ต้องติดตั้ง Ruby บนเครื่องของคุณ):

```bash
docker compose exec web ruby scripts/test_concurrency.rb
```

คำสั่งนี้จะสั่งให้จำลอง Alice และ Bob ยิงจองตั๋วใบสุดท้ายเข้ามาพร้อมกันด้วยความเร็วระดับ Milliseconds (ผ่านระบบ Threads ของ Ruby) และแสดงผลลัพธ์:

```
============================================================
  Race Condition Test — Overbooking Prevention
============================================================
  Event   : Ed Sheeran +-=÷x Tour
  Tickets : 5 remaining

  Alice and Bob will each try to book 5 tickets simultaneously.
  Expected: exactly one 201 ✅  and one 422 ❌
============================================================

✅ WIN   Bob   — HTTP 201 (0.022s)
❌ LOSE  Alice — HTTP 422 (0.024s)

✅ PASSED — Pessimistic lock worked correctly!
   Tickets were booked exactly once. No overbooking.
============================================================
```

> **ผลที่คาดหวัง**: จะมีผู้ชนะเพียง 1 คนเสมอ (`201 OK`) และอีกคนจะถูกปฏิเสธ (`422 Unprocessable Entity`)

หากต้องการ Reset ข้อมูลการจองเพื่อทดสอบใหม่ ให้ใช้คำสั่ง:
```bash
docker compose down -v && docker compose up --build
```

---

## 5. สถาปัตยกรรมระบบการจองแบบ Asynchronous (Redis + Sidekiq)

เพื่อรองรับปริมาณการจองตั๋วขนาดใหญ่ (High-Scale Ticket Sales) และจำกัดการเข้าทำลายฐานข้อมูลพร้อมกันโดยตรง ระบบจึงออกแบบด้วยแนวทาง **Asynchronous Task Queue** ร่วมกับ **Pessimistic Locking** เพื่อความยุติธรรมและประสิทธิภาพสูงสุด:

```
                            [ HTTP POST /events/:id/bookings ]
                                            │
                                            ▼
                               [ BookingsController ]
                                            │
                       (สร้าง BookingPending / ยัดงานลง Queue)
                                            │
                                            ▼
                                   [ Redis / Sidekiq ]
                                            │
                                            ▼
                              [ ProcessBookingJob (Default) ]
                                            │
                      ┌─────────────────────┴─────────────────────┐
                      ▼                                           ▼
             [ CreateBooking Service ]                    [ Event.with_lock ]
                      │                                           │
         (ตรวจสอบยอดตั๋วคงเหลือจริง)                   (ล็อกและทำรายการจองตั๋ว)
                      │                                           │
                      └─────────────────────┬─────────────────────┘
                                            ▼
                              [ อัปเดต Booking -> Success ]
                                    (ยิง Domain Event)
```

### การทำ RESTful Asynchronous API
1. **ส่งคำขอจอง (`POST /events/:id/bookings`)**: 
   - ระบบจะสร้างตั๋วในสถานะ `pending` ลงฐานข้อมูลทันที และนำส่ง Job ID เข้าสู่ Redis
   - ส่งตอบกลับทันทีด้วยสถานะ **`202 Accepted`** เพื่อให้ฝั่งหน้าบ้านไม่ต้องรอการล็อก DB ซึ่งจะลดอัตราการ Timeout ของ Server ลง
2. **การติดตามผลการจอง (`GET /events/:event_id/bookings/:id`)**:
   - หน้าบ้านสามารถนำ `id` การจองที่ได้จากขั้นตอนแรก มายิงตรวจสอบสถานะล่าสุด (Polling) เพื่อดูว่าการจองนั้นเปลี่ยนสถานะเป็น `success` หรือ `failed` (พร้อมเหตุผลเช่น ตั๋วเต็ม) เรียบร้อยหรือยัง

---

## 6. Concurrency Handling: Pessimistic Locking & Queue

ระบบเลือกใช้การประสานพลังกันระหว่าง **FIFO Queue** ของ Redis และ **Pessimistic Locking** ใน PostgreSQL:

* **Redis Queue**: ทำหน้าที่ควบคุมการเข้าถึงฐานข้อมูล จัดเรียงคิวผู้จองเข้าประมวลผลตามลำดับอย่างเป็นธรรม (First-Come, First-Served) ป้องกันภาวะคอขวดที่ตัวฐานข้อมูลหลัก
* **PostgreSQL Pessimistic Locking (`event.with_lock`)**: ด่านสุดท้ายสำหรับการการันตียอดตั๋วคงเหลือในตอนบันทึกผลงานลง Disk ตัวฐานข้อมูลจะบังคับให้ทำรายการแบบเรียงคิวห้ามจองพร้อมกัน ทำให้ **ยอดขายตั๋วไม่มีทางเกินโควต้า 100% (No Overbooking)**

---

## 7. สิ่งที่จะพัฒนาเพิ่มเติม (If we had more time)

1. **Ticket Holding / Reservation Holding**:
   - เมื่อกดเลือกตั๋ว ระบบจะ Hold (ล็อกตั๋วไว้ให้ชั่วคราว) 10 นาที เพื่อให้ผู้ใช้สามารถกรอกข้อมูลจ่ายเงินได้อย่างเท่าเทียม และคืนที่นั่งเข้าสู่ระบบหากทำรายการไม่เสร็จภายในกำหนดเวลา (Expired event)
2. **Authentication / Authorization**:
   - ระบบสมาชิกผู้ซื้อตั๋ว และระบบสิทธิ์แอดมินสำหรับการจัดการสร้างแก้ไขอีเวนต์คอนเสิร์ต
3. **WebSockets (ActionCable) / SSE**:
   - ส่งสัญญาณบอกหน้าบ้านทันทีที่ Sidekiq ประมวลผลสถานะตั๋วเสร็จสิ้น โดยที่หน้าบ้านไม่ต้องส่ง Polling Request มาถามซ้ำๆ
4. **DLQ (Dead Letter Queue) / Retry logic**:
   - สำหรับจัดการกรณีที่ระบบประมวลผลตั๋วเกิดข้อผิดพลาดด้าน Network หรือระบบหลังบ้านขัดข้อง

