# Luilaykhao 1.12.0 (42)

รุ่นก่อนหน้า: 1.11.0 (40) — ตัดรุ่นเมื่อ 2026-08-04
เนื้อหารุ่นนี้คือทุก commit หลังจาก `252d21a` (8 commit)

> build (41) ใช้ไม่ได้ อย่าปล่อยออกไป — คำสั่ง build โดนกลืน `\` ท้ายบรรทัด ค่า
> `--dart-define` ทั้งก้อนเลยไหลไปรวมอยู่ใน `API_BASE_URL` แอปจึงยิง API ไม่ออก
> สักเส้นและทุกหน้าว่างเปล่า (42) คือของเดิมที่ build ใหม่ด้วย
> `./scripts/build-release.sh` ซึ่งอ่านค่าจาก `dart_defines/prod.json` และตรวจ
> ไบนารีหลัง build ให้แล้ว

ขึ้น minor เป็น **1.12.0** เพราะมีของใหม่ที่ผู้ใช้เห็นและเปิดใช้เองได้ (ธีมมืดทั้งแอป)
ไม่ใช่แค่แก้บั๊ก จึงไม่ใช่ 1.11.1 และไม่มีอะไรที่เปลี่ยนพฤติกรรมเดิมหรือทำให้ของเก่า
ใช้ไม่ได้จนต้องขึ้น 2.0.0 ส่วนที่เหลือของรุ่นนี้คือความถูกต้องของยอดเงิน การแก้หน้าจอว่าง
และงานขัดผิวหน้าตาทั้งแอปให้เป็นชุดเดียวกัน

---

## What's New — ภาษาไทย (App Store / Play Store)

รอบนี้เน้นสองเรื่อง คือธีมมืดที่ใช้ได้จริงทั้งแอป และยอดเงินที่แสดงต้องตรงกับที่ต้องโอนจริง

**ธีมมืด**
เปิดได้ที่ โปรไฟล์ → การตั้งค่า → ธีมมืด แล้วทั้งแอปเปลี่ยนตาม ไม่ใช่แค่แถบด้านบน
ตัวหนังสือ เส้นคั่น พื้นการ์ด และพื้นหลังทุกหน้าปรับสีให้อ่านสบายตาในที่มืด
แอปจำค่าที่เลือกไว้ให้ ไม่ต้องตั้งใหม่ทุกครั้งที่เปิด

**ยอดที่ต้องโอนตรงกับความจริง**
- มัดจำแบบระบุจำนวนเงินคิดต่อคน จองเป็นกลุ่มแล้วเคยขึ้นยอดของคนเดียว ตอนนี้ขึ้นยอด
  ของทั้งกลุ่มถูกต้อง
- ส่วนลดมัดจำตามระดับสมาชิกแสดงในรายละเอียดแล้ว บอกชัดว่าหักไปเท่าไร
- ทุกยอดในหน้าชำระเงินอ่านมาจากเซิร์ฟเวอร์ทางเดียว แอปไม่คำนวณเองอีกต่อไป
  ยอดที่เห็นในแอปกับยอดที่ทีมงานตรวจสลิปจึงเป็นตัวเดียวกันเสมอ

**แก้หน้า "การจองของฉัน" ว่างเปล่า**
ใครที่เคยไปทริปมาแล้ว เปิดหน้าการจองของฉันแล้วเจอหน้าว่าง ตอนนี้เห็นรายการครบทั้ง
ทริปที่กำลังจะถึงและทริปที่ผ่านมาแล้ว

**ห้องแชทบอกได้ว่าใครเพิ่งเข้ามา**
ทีมงานเข้าห้องจะขึ้นข้อความแยกสีและไอคอนจากผู้ร่วมทริปทั่วไป จะได้รู้ว่าถามตอนนี้
มีคนตอบ และถ้าใครเข้า ๆ ออก ๆ ห้อง จะไม่เด้งข้อความซ้ำกวนทั้งห้อง

**หน้าจอบอกรูปร่างตั้งแต่ยังโหลดไม่เสร็จ**
หน้าที่เคยขึ้นวงกลมหมุนเปล่า ๆ ตอนนี้ขึ้นโครงของเนื้อหาที่กำลังจะมา และถ้าไม่มีข้อมูล
หรือโหลดไม่สำเร็จ มีปุ่มลองใหม่ให้กดตรงนั้น ไม่ต้องถอยออกแล้วเข้าใหม่

**ปุ่มเล็กแตะง่ายขึ้น**
ปุ่มไอคอนขนาดเล็กหลายจุดขยายพื้นที่รับการแตะให้ถึงขนาดมาตรฐาน โดยหน้าตาเท่าเดิม
และปุ่มที่มีแต่ไอคอนมีคำอธิบายให้โปรแกรมอ่านหน้าจอแล้ว

**หน้าตาเป็นชุดเดียวกันทั้งแอป**
- ข้อความแจ้งผลด้านล่างจอมีรูปแบบเดียวกันทุกหน้า พร้อมไอคอนบอกว่าสำเร็จหรือผิดพลาด
  และถ้ามีข้อความใหม่ จะแทนที่อันเก่าทันที ไม่ต้องรอคิว
- ความโค้งมุม ขนาดตัวอักษร และชุดสีทั้งแอปยุบเหลือชุดเดียว หน้าต่าง ๆ จึงดูเป็นแอป
  เดียวกัน ไม่เหมือนคนละแอปมาต่อกัน

---

## บันทึกประจำรุ่น — Google Play (th-TH)

Play Console จำกัด 500 ตัวอักษรต่อภาษา ฉบับนี้ 479 ตัวอักษร วางในช่อง
`<th-TH>...</th-TH>` ของ Release notes ได้เลย

```
รอบนี้เน้นธีมมืดที่ใช้ได้จริงทั้งแอป และยอดเงินที่ต้องตรงกับที่ต้องโอนจริง

• ธีมมืด เปิดที่ โปรไฟล์ → การตั้งค่า → ธีมมืด แล้วเปลี่ยนทั้งแอป
• แก้ยอดมัดจำของการจองแบบกลุ่มที่เคยแสดงน้อยกว่าความจริง
• แสดงส่วนลดมัดจำตามระดับสมาชิก
• แก้หน้าการจองของฉันว่างเปล่าสำหรับคนที่เคยไปทริปมาแล้ว
• แชทบอกเมื่อทีมงานเข้าห้อง
• หน้าจอขึ้นโครงเนื้อหาระหว่างโหลด และมีปุ่มลองใหม่เมื่อโหลดไม่สำเร็จ
• ปุ่มไอคอนเล็ก ๆ แตะง่ายขึ้นและรองรับโปรแกรมอ่านหน้าจอ
• ปรับหน้าตาทั้งแอปให้เป็นชุดเดียวกัน
```

### Play Console — App access

ไม่ต้องแก้จากรุ่นก่อน ถ้าบัญชีทดสอบเดิมยังใช้ได้ — เนื้อหาส่วนใหญ่ยังต้องล็อกอิน
และการชำระเงินยังเป็นบริการจริงนอกแอป (ที่นั่งบนรถและทริปนำเที่ยว) จ่ายผ่าน
พร้อมเพย์/โอนธนาคาร จึงไม่เข้าข่าย Google Play Billing ตามข้อยกเว้นสินค้าและบริการ
ที่ใช้งานนอกแอป

---

## App Review Notes — English

App Store Connect จำกัดช่อง "Notes for Review" ไว้ 4000 ตัวอักษร ตัวข้างล่างนี้
3891 ตัวอักษร (นับตั้งแต่ "About the app" ลงไป) วางได้ทั้งก้อน

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
Unchanged from 1.11.0. Everything sold is a real-world physical service: a seat on a
guided trip departing on a specific date, transport, and optional physical equipment
rental. Under Guideline 3.1.3(e)/3.1.5 these are consumed outside the app and are not
eligible for in-app purchase. No digital content, subscription or unlockable feature
is sold anywhere in the app.

Payment is by Thai bank transfer / PromptPay QR: the app shows a QR code, the customer
pays in their own banking app, then uploads the transfer slip. This build adds no new
purchase path. It fixes a display bug: a fixed-amount deposit is charged per passenger,
but a group booking was shown only one passenger's share. Amounts now come from the
server's payment quote rather than being recomputed on the device.

### New in this build
1. Dark mode. Profile -> Settings -> ธีมมืด toggles the whole app, and the choice is
   persisted locally. Page text, hairlines, card fills and backgrounds resolve through
   the theme; QR code backgrounds stay light on purpose, since an inverted QR will not
   scan.
2. Payment amounts sourced from the server, as described above, including a members'
   tier discount line in the deposit breakdown.
3. Fixed a blank "My bookings" screen for any account with a past trip — an unbounded
   layout constraint in the completed-trip row took the whole list down. Widget tests
   were added for that screen.
4. Group chat shows a distinct notice when a staff member enters the room, so customers
   know someone can answer right now. Repeats are suppressed for three minutes per
   person.
5. Loading states now show a skeleton of the content instead of a bare spinner, and
   empty or failed loads offer a retry action in place.
6. Accessibility: thirteen icon-only controls that were drawn under the 44pt minimum now
   have a 44pt hit area (their visual size is unchanged), and icon-only buttons carry
   accessibility labels for VoiceOver.
7. Visual consistency pass: one snackbar style with a success/error icon, and a single
   radius, type and colour scale across the app.

### Permissions (unchanged from 1.11.0)
- Location (When In Use): sort pickup points by distance and show the customer next to
  the van on the tracking map. No background location is declared; vehicle GPS is
  uploaded by our separate driver app.
- Camera: check-in QR scan and photographing a bank transfer slip.
- Photo Library / Add: picking a profile photo or slip image, and saving trip photos
  and the Trip Recap card.
- Calendar (write-only): the "Add to calendar" button on a booking.
- Face ID: optional unlock instead of re-entering the password.
- Notifications: departure reminders, payment due dates, driver-arrival and SOS alerts,
  and group chat messages.

### Account and language
Sign in with Apple is offered alongside phone/email. Account deletion is in-app at
Profile -> Settings -> ลบบัญชี (Delete account), and removes the account and personal data
server-side. The interface is Thai only and dates use the Thai Buddhist calendar; the
market is Thailand.

Equipment handout and passenger check-in are staff-only, gated by a server-side role,
and are not reachable with the demo account.

The tracking screen can use the Google Maps SDK when a key is supplied at build time.
This build ships without the key and uses the same OpenStreetMap renderer as 1.11.0.
