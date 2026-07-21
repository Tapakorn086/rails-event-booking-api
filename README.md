# Event Booking API (Backend)

Backend API สำหรับระบบจองตั๋วคอนเสิร์ต ออกแบบและจัดโครงสร้างโค้ดตามหลัก **Clean Architecture** / **Separation of Concerns** ด้วย Ruby on Rails (API-only mode) และ PostgreSQL

---

## 1. How to run (วิธีการรันโปรเจกต์)

### วิธีที่ 1: รันผ่าน Docker Compose (แนะนำ)
สามารถรันได้เหมือนกันทุกระบบปฏิบัติการ (Windows / macOS / Linux) ด้วยคำสั่งเดียว:

```bash
docker compose up --build
```

- ระบบจะทำการ build container, รอ PostgreSQL พร้อมทำงาน, ดำเนินการ `db:prepare` (create DB + run migrations) และ `db:seed` (ลงข้อมูล sample events) ให้อัตโนมัติผ่าน [entrypoint script](file:///Users/pond/Documents/odds/project/rails_test/bin/docker-entrypoint)
- API จะเปิดให้บริการที่ `http://localhost:3000`

---

### วิธีที่ 2: รันแบบ Native (เครื่องผู้ประเมิน)

**Prerequisites**:
- Ruby 3.x
- PostgreSQL service กำลังรันอยู่บน local Machine (port 5432)

**Steps**:
1. ติดตั้ง Gems:
   ```bash
   bundle install
   ```
2. ตั้งค่า database URL ใน `config/database.yml` หรือผ่าน ENV variable:
   ```bash
   export DATABASE_URL="postgres://postgres:password@localhost:5432/event_booking_development"
   ```
3. สร้าง Database, Run Migrations และ Seed ข้อมูล:
   ```bash
   bin/rails db:create db:migrate db:seed
   ```
4. เริ่มต้น Rails Server:
   ```bash
   bin/rails server
   ```
5. รัน RSpec Test Suite:
   ```bash
   bundle exec rspec
   ```

---

## 2. ตัวอย่าง Curl Commands สำหรับทดสอบ API

### 1) GET /events (ดึงรายการ Event ทั้งหมด)
```bash
curl -X GET http://localhost:3000/events \
  -H "Accept: application/json"
```

**Response (200 OK)**:
```json
[
  {
    "id": 1,
    "name": "Coldplay Music of the Spheres World Tour",
    "date": "2026-08-21T06:45:00.000Z",
    "available_tickets": 100
  },
  {
    "id": 2,
    "name": "Taylor Swift The Eras Tour",
    "date": "2026-09-21T06:45:00.000Z",
    "available_tickets": 50
  }
]
```

---

### 2) POST /events/:event_id/bookings (กรณีจองตั๋วสำเร็จ)
```bash
curl -X POST http://localhost:3000/events/1/bookings \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "quantity": 2
  }'
```

**Response (201 Created)**:
```json
{
  "id": 1,
  "event_id": 1,
  "email": "john.doe@example.com",
  "quantity": 2,
  "created_at": "2026-07-21T06:50:00.000Z"
}
```

---

### 3) POST /events/:event_id/bookings (กรณีตั๋วไม่พอ / Error Handling)
```bash
curl -X POST http://localhost:3000/events/1/bookings \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "quantity": 9999
  }'
```

**Response (422 Unprocessable Entity)**:
```json
{
  "error": "Not enough tickets available. Remaining tickets: 98"
}
```

> **Note**: หากกรณี `curl` สั่งไปที่ `:event_id` ที่ไม่มีในระบบ (เช่น ยิงไปที่ id 1 แต่ใน DB เริ่มที่ id 4) API จะคืนค่า `422 Unprocessable Entity` พร้อมข้อความ `{"error": "Event does not exist"}`

---

## 3. Postman Collection
สามารถนำไฟล์ `postman_collection.json` ที่แนบมาในโปรเจกต์นี้ Import เข้าสู่โปรแกรม Postman เพื่อทดสอบ API ได้ทันที โดยมีตัวอย่าง Request และ Response (Saved Examples) ครบทุก Endpoint (ทั้งกรณี Success และ Error)

---

## 3. เหตุผลในการแยก Service Layer ออกจาก Controller / Model

สถาปัตยกรรมนี้ยึดหลัก **Clean Architecture** และ **Dependency Direction** (`Controller -> Service -> Model`):

1. **Single Responsibility Principle (SRP)**:
   - `Model` (`app/models`): ทำหน้าที่เป็น Entity แบบบาง เก็บเฉพาะ Data Validation, DB Association และ Calculation Methods ง่ายๆ (เช่น `available_tickets`) ไม่มี Logic เชิงตัดสินใจธุรกิจ
   - `Controller` (`app/controllers`): ทำหน้าที่เป็น HTTP Adapter แปลง Params, ส่งต่อให้ Service และแปลงผลลัพธ์คืน HTTP Status Response (ไม่มี Query หรือ Business Logic อยู่ใน Controller)
   - `Service Object` (`app/services`): เก็บ Core Business Logic / Use Case (`CreateBooking`) ทั้งหมด แยกอิสระจาก Framework (ไม่รู้จัก HTTP, Status Code, หรือ ActionController)

2. **Testability (การทดสอบง่ายและรวดเร็ว)**:
   - สามารถเขียน Unit Test ทดสอบ Business Logic ใน Service Object ได้โดยตรง (Service Spec) โดยไม่ต้องผ่าน HTTP Stack ของ Rails
   - รองรับการทำ Stub/Mock หรือ Inject Dependencies ได้สะดวก

3. **Dependency Direction & Reusability**:
   - Class ใน Service สามารถนำไปเรียกใช้งานซ้ำจาก Background Worker (เช่น Sidekiq, ActiveJob), CLI Task, หรือ GraphQL Resolvers ได้ทันทีโดยไม่ต้องแก้ Business Logic ใหม่

---

## 4. Concurrency Handling: Pessimistic Locking (`with_lock`)

ในการจองตั๋วคอนเสิร์ต กรณีมีผู้ใช้งานสองคนกดจองตั๋วใบสุดท้ายพร้อมกัน (Race Condition) อาจเกิดปัญหา **Overbooking** หากไม่มีการควบคุม Concurrency

### ทำไมถึงเลือก Pessimistic Locking (`event.with_lock`)?

1. **กลไกการทำงาน**:
   - ใน `CreateBooking` service ใช้ `event.with_lock do ... end` ซึ่งจะรันคำสั่ง `SELECT ... FOR UPDATE` ในระดับ PostgreSQL Row Level Lock
   - เมื่อ Request A เข้ามา จะทำการล็อก Row ของ Event ไว้ Request B ที่เข้ามาพร้อมกันจะถูกบล็อกและรอที่ระดับ Database จนกว่า Transaction ของ Request A จะ Commit/Rollback
   - เมื่อ Request B ได้รับ Lock จะอ่านค่า `available_tickets` ล่าสุดที่อัปเดตแล้ว ทำให้พบว่าตั๋วหมดและถูกปฏิเสธอย่างถูกต้อง

2. **เปรียบเทียบกับ Optimistic Locking (`lock_version`)**:
   - **Optimistic Locking** เหมาะกับระบบที่มี Read มาก และ Concurrent Write ต่ำ หากเกิด Collision จะ throw `StaleObjectError` ให้ User ลองใหม่ (Retry)
   - สำหรับระบบขายตั๋วคอนเสิร์ตที่มี **High Contention** (คนแย่งกันจองตั๋วใบสุดท้ายพร้อมกันนับพันคน) การใช้ Optimistic Locking จะทำให้ Request จำนวนมากล้มเหลวและต้องทำ Retry ซ้ำๆ ซึ่งสูญเสีย CPU/DB Resources
   - **Pessimistic Locking** การันตีว่าคำขอที่เข้ามาก่อนใน Transaction Queue จะได้รับการประมวลผลตามลำดับอย่างปลอดภัย การันตีความถูกต้อง 100% ว่าจะไม่มีทางเกิด Overbooking

---

## 5. สิ่งที่จะพัฒนาเพิ่มเติมหากมีเวลามากกว่านี้ (Future Enhancements)

1. **Authentication & Authorization**:
   - เพิ่มระบบ User JWT / OAuth2 Authentication เพื่อยืนยันตัวตนผู้จอง
2. **Pagination & Search Filtering**:
   - เพิ่ม Kaminari/Pagy ใน `GET /events` รองรับ Query Params เช่น `?page=1&per_page=10&query=Coldplay`
3. **Async Email Confirmation (Background Job)**:
   - ใช้ ActiveJob + Sidekiq / Redis ส่ง Email ยืนยันการจองแบบ Asynchronous หลังจาก CreateBooking สำเร็จ
4. **Ticket Cancellation / Refund Endpoint**:
   - เพิ่ม API `DELETE /bookings/:id` คืนจำนวนตั๋วกลับเข้าสู่ Event
5. **Waiting Queue (Virtual Waiting Room)**:
   - ใช้ Redis Queue (เช่น BullMQ / Redlock) หรือ Ticket Reservation Holding System (ล็อกตั๋วไว้ 10 นาทีระหว่างชำระเงิน) สำหรับ Event สเกลใหญ่ที่มีผู้ใช้งานเข้าพร้อมกันจำนวนมาก
