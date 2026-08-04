# Luilaykhao 1.11.0 (40)

รุ่นก่อนหน้า: 1.10.0 (39) — ตัดรุ่นเมื่อ 2026-07-23
เนื้อหารุ่นนี้คือทุก commit หลังจาก `055b250` (19 commit)

ขึ้น minor เป็น **1.11.0** เพราะมีของใหม่ที่ลูกค้าเห็น (ผู้ช่วยส่วนตัว, การ์ดสรุป
การเดินทาง, โพลในแชท, จำนวนของเสริมแบบ stepper, เครื่องมือสตาฟชุดใหม่) ไม่ใช่แค่แก้บั๊ก
จึงไม่ใช่ 1.10.1 และไม่มีอะไรที่เปลี่ยนพฤติกรรมเดิมจนต้องขึ้น 2.0.0

---

## What's New — ภาษาไทย (App Store / Play Store)

รอบนี้เน้นเรื่องเดียว คือให้แอปตอบคำถามที่ลูกค้าต้องโทรมาถามได้เอง และให้ทุกอย่าง
ยังทำงานตอนสัญญาณไม่ดี

**ผู้ช่วยส่วนตัว**
ถามเรื่องทริปของคุณได้ตรง ๆ — ออกกี่โมง ขึ้นรถที่ไหน ค้างชำระเท่าไร ต้องเตรียมอะไรไป
ตอบจากข้อมูลการจองจริง แล้วมีปุ่มพาไปยังหน้าที่ทำเรื่องนั้นต่อได้เลย อยู่ในเมนูช่วยเหลือ

**การ์ดสรุปการเดินทาง**
ใบจองขึ้นต้นด้วยคำตอบสี่ข้อในที่เดียว ตั้งแต่วันที่จอง — ขึ้นรถกี่โมงที่ไหน (กดเปิดแผนที่ได้)
รถทะเบียนอะไร คนขับและสตาฟเบอร์ไหน (กดโทรได้) ข้อไหนที่ยังไม่ถึงเวลาจัด จะบอกว่าจะยืนยัน
ให้เมื่อไร แทนที่จะหายไปเฉย ๆ

**ห้องแชทตอบคำถามได้**
- ปุ่มคำถามด่วนเหนือช่องพิมพ์ (ขึ้นรถกี่โมง · จุดรับที่ไหน · ทะเบียนรถ · เบอร์ติดต่อ)
  กดแล้วได้คำตอบทันทีเฉพาะคุณ ไม่กวนคนทั้งห้อง
- รายชื่อสตาฟและคนขับครบทุกคนพร้อมปุ่มโทร ไม่ต้องเลื่อนหาการ์ดที่ซ่อนอยู่นอกจอ
- โพลในห้อง โหวตแล้วเห็นผลสดทันที

**รู้ผลตรวจสลิปทันที**
แจ้งชำระเงินแล้วถ้ายอดตรง ระบบยืนยันที่นั่งให้เลยและบอกตรงนั้นว่าเรียบร้อย ไม่ต้องรอ
ลุ้นว่า "กำลังดำเนินการ" แปลว่าอะไร พร้อมหน้าสรุปว่าส่งอะไรไปแล้ว และขั้นต่อไปคืออะไร

**เลือกจำนวนของเสริมได้**
ของเสริมแต่ละอย่างมีปุ่ม − จำนวน + ของตัวเอง เช่าเสื่อ 2 ชิ้นจากผู้เดินทาง 4 คนได้
และจำนวนที่เลือกไว้ยังอยู่ถ้ากลับมากรอกจองต่อทีหลัง

**เตือนก่อนรูปทริปหาย**
รูปจากทริปมีอายุไม่กี่วันหลังอัปโหลด หน้ารูปจึงบอกวันสุดท้ายที่โหลดได้ และเปลี่ยนเป็น
สีแดงเมื่อเหลือวันสุดท้าย

**แจ้งเตือน SOS ไม่หลุดอีก**
ถ้าเครื่องดับ แบตหมด หรือไม่มีสัญญาณตอนเกิดเหตุ เปิดแอปขึ้นมาแล้วจะเห็นเหตุที่ยังไม่ปิดทันที
เสียงเตือนหยุดเองเมื่อเหตุถูกปิด และไม่ดังค้างจนแบตหมด

**เน็ตไม่ดีก็ยังบอกเป็นภาษาคน**
สัญญาณหลุดกลางทางแล้วขึ้นข้อความภาษาไทยว่าเน็ตมีปัญหา ไม่ใช่ข้อความ error ภาษาอังกฤษ
ยาว ๆ การอ่านข้อมูลลองใหม่ให้อัตโนมัติ ส่วนการจ่ายเงินและการจองไม่ลองซ้ำเอง เพื่อไม่ให้
เกิดรายการซ้ำ และการอัปโหลดสลิปไม่ค้างหมุนอีกต่อไป

**สะสมแต้มและระดับสมาชิก**
ระดับสมาชิกนับจาก "จำนวนทริปที่ไปด้วยกัน" แล้ว หน้าสะสมแต้มจึงบอกว่าเหลืออีกกี่ทริป
และมีบรรทัดเตือนแต้มที่ใกล้หมดอายุ

**สำหรับสตาฟ**
เมนูอุปกรณ์สำหรับแจก/รับคืนของเช่าทั้งรอบ พร้อมความคืบหน้าต่อชนิด และเช็คอินลูกค้าได้
จากรายชื่อโดยไม่ต้องเปิดกล้อง สำหรับเคสแบตหมดหรือไม่มีสัญญาณ

**อื่น ๆ**
- ราคาจุดรับแบบปักหมุดเองแสดงตรงกับที่คิดจริง และบอกว่าอ้างอิงจุดรับไหน
- การ์ดชวนเพื่อนช่วยเปิดรอบย้ายมาอยู่บนใบจอง ตั้งแต่ยังมีเวลาชวน
- ภาพหน้าแรกเลื่อนเองและปัดเปลี่ยนรูปได้
- ชื่อหัวข้อบนแถบด้านบนไม่จางเมื่อเลื่อนเนื้อหาผ่าน
- แถบด้านล่างทุกหน้าชิดขอบจอพอดี ไม่ลอยเห็นพื้นหลังแลบ
- รองรับการขยายขนาดตัวอักษรของเครื่องได้ถึง 1.3 เท่าโดยหน้าจอไม่ล้น
- ปุ่มไอคอนมีคำอธิบายสำหรับโปรแกรมอ่านหน้าจอ
- แก้แผนที่เส้นทางรถล่มเมื่อเจอพิกัดผิดรูปแบบเพียงจุดเดียว
- แก้การแตะแจ้งเตือนแล้วไม่เปิดหน้าที่ควรเปิด หลังจากเคยมีเหตุ SOS

---

## บันทึกประจำรุ่น — Google Play (th-TH)

Play Console จำกัด 500 ตัวอักษรต่อภาษา ฉบับนี้ 492 ตัวอักษร วางในช่อง
`<th-TH>...</th-TH>` ของ Release notes ได้เลย

```
รอบนี้เน้นให้แอปตอบคำถามเรื่องทริปได้เอง แม้สัญญาณไม่ดี

• ผู้ช่วยส่วนตัว ถามเรื่องทริปของคุณได้ตรง ๆ
• การ์ดสรุปการเดินทางบนใบจอง บอกเวลา จุดรับ รถ และเบอร์ติดต่อ
• ห้องแชทมีปุ่มคำถามด่วน รายชื่อสตาฟพร้อมปุ่มโทร และโพล
• แจ้งชำระเงินแล้วรู้ผลตรวจสลิปทันที
• เลือกจำนวนของเสริมได้ทีละชิ้น
• เตือนก่อนรูปจากทริปหมดอายุ
• แจ้งเตือน SOS ไม่ตกหล่นแม้เครื่องเพิ่งเปิด
• เน็ตหลุดแล้วบอกเป็นภาษาไทย ไม่ใช่ข้อความ error
• ระดับสมาชิกนับตามจำนวนทริป และเตือนแต้มใกล้หมดอายุ
• แก้บั๊กและปรับความลื่นไหล
```

### Play Console — App access

ไม่ต้องแก้จากรุ่นก่อน ถ้าบัญชีทดสอบเดิมยังใช้ได้ — เนื้อหาส่วนใหญ่ยังต้องล็อกอิน
และการชำระเงินยังเป็นบริการจริงนอกแอป (ที่นั่งบนรถและทริปนำเที่ยว) จ่ายผ่าน
พร้อมเพย์/โอนธนาคาร จึงไม่เข้าข่าย Google Play Billing ตามข้อยกเว้นสินค้าและบริการ
ที่ใช้งานนอกแอป

---

## App Review Notes — English

App Store Connect จำกัดช่อง "Notes for Review" ไว้ 4000 ตัวอักษร ตัวข้างล่างนี้
3913 ตัวอักษร (นับตั้งแต่ "About the app" ลงไป) วางได้ทั้งก้อน

### About the app
Luilaykhao books guided hiking day trips in Thailand. Customers pick a departure
date, book seats on it, and on the travel day use the app to find their pickup point
and track the shuttle van.

### Demo account
- Phone / email: <TODO: fill in reviewer test account>
- Password: <TODO> (no OTP required)

It has one upcoming and one completed booking, so booking detail, the trip-day
screen, group chat, Trip Recap and Passport are reachable without a purchase.

### Payments — no in-app purchase, by design
Unchanged from 1.10.0. Everything sold is a real-world physical service: a seat on a
guided trip departing on a specific date, transport, and optional physical equipment
rental. Under Guideline 3.1.3(e)/3.1.5 these are consumed outside the app and are not
eligible for in-app purchase. No digital content, subscription or unlockable feature
is sold anywhere in the app.

Payment is by Thai bank transfer / PromptPay QR: the app shows a QR code, the customer
pays in their own banking app, then uploads the transfer slip. This build changes only
the feedback afterwards - the server already verified the amount at upload time, so
when it matches the app now says the seat is confirmed instead of showing an indefinite
"processing" state. No new purchase path was added.

### New in this build
1. Trip assistant (Help -> assistant) answers questions about the signed-in user's own
   booking - departure time, pickup point, outstanding balance, what to pack - from
   data already on the server. It reads only that account's bookings.
2. Trip summary card at the top of booking detail: pickup time and place, vehicle
   plate, driver and staff phone with call buttons. Rows not assigned yet say when
   they will be confirmed instead of disappearing.
3. Group chat: quick-question buttons that reply privately to the asker, a contact
   sheet of staff and drivers, and in-room polls.
4. Add-on quantity stepper in the booking flow - same physical extras as before.
5. Trip photo expiry notice: the backend deletes shared trip photos a few days after
   upload, so the screen now shows the deadline.
6. SOS catch-up: the emergency screen is re-checked on launch and resume, so a phone
   that was off or out of signal during an incident still sees an open case. The alarm
   is capped at three minutes and stops when the case is resolved.

Equipment handout and passenger check-in are staff-only, gated by a server-side role,
and are not reachable with the demo account.

### Permissions (unchanged from 1.10.0)
- Location (When In Use): sort pickup points by distance and show the customer next to
  the van on the tracking map. No background location is declared; vehicle GPS is
  uploaded by our separate driver app.
- Camera: check-in QR scan and photographing a bank transfer slip.
- Photo Library / Add: picking a profile photo or slip image, and saving trip photos
  and the Trip Recap card.
- Calendar (write-only): the "Add to calendar" button on a booking.
- Face ID: optional unlock instead of re-entering the password.
- Notifications: departure reminders, payment due dates, driver-arrival and SOS
  alerts, and group chat messages.

### Account, language, fixes
Sign in with Apple is offered alongside phone/email. Account deletion is in-app at
Profile -> Settings -> ลบบัญชี (Delete account), and removes the account and personal data
server-side. The interface is Thai only and dates use the Thai Buddhist calendar; the
market is Thailand.

Fixed in this build: a crash when the vehicle-route map received a malformed
coordinate; notification taps not opening the right screen after an SOS alert; raw
Dart error text shown on network failures; and a transfer-slip upload that could hang
with no timeout.

The tracking screen can use the Google Maps SDK when a key is supplied at build time.
This build ships without the key and uses the same OpenStreetMap renderer as 1.10.0.
