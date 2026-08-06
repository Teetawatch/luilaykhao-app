# Luilaykhao 1.13.0 (45)

รุ่นก่อนหน้า: 1.12.1 (43) — เตรียมส่งแล้วแต่ **ยกเลิกการส่งไป** ยังไม่เคยขึ้นสโตร์
ดู [RELEASE_1.12.1.md](RELEASE_1.12.1.md)

ขึ้นเป็น **1.13.0** ไม่ใช่ build ใหม่ของ 1.12.1 เพราะรุ่นนี้มีของใหม่ที่ผู้ใช้เห็นได้
ที่ไม่เคยมีมาก่อน ไม่ใช่ตัวแก้บั๊ก

**เลข build เป็น 45 ไม่ใช่ 44** — 44 ถูกเผาไปกับก้อนที่เตรียมไว้ก่อนจะเพิ่มเครื่องมือ
ดูแลเนื้อหา (report/block) เข้ามา เลข build เดินหน้าอย่างเดียวเสมอไม่ว่าจะเกิดอะไรขึ้น
กับเลขก่อนหน้าบน App Store Connect เพราะเลขที่เคยอัปโหลดไปแล้วใช้ซ้ำไม่ได้ แม้จะ
ยกเลิกการส่งตรวจไปแล้วก็ตาม การกระโดดข้ามเลขไม่มีผลอะไรกับผู้ใช้ แต่การชนเลขทำให้
อัปโหลดไม่ผ่านทันที

**ยังเป็น 1.13.0 ไม่ใช่ 1.14.0** เพราะรุ่นนี้ยังไม่เคยถึงมือใคร ของที่เพิ่มเข้ามาจึงนับ
เป็นเนื้อหาของ 1.13.0 เอง — เหมือนที่ 1.12.1 ถูกกลืนเข้ามาเป็นส่วนหนึ่งของรุ่นนี้
เลขเวอร์ชันที่ผู้ใช้ไม่เคยเห็นไม่ควรถูกเผาทิ้งเปล่า ๆ

**เนื้อหาของ 1.12.1 ทั้งหมดรวมอยู่ในรุ่นนี้ด้วย** เพราะรุ่นนั้นไม่เคยถึงมือใครเลย
ข้อความ What's New ข้างล่างจึงเล่าของทั้งสองรุ่นรวมกัน

## ของใหม่ในรุ่นนี้ (ที่ไม่มีใน 1.12.1)

**การ์ด "วันเดินทาง" บนหน้าจอล็อก / Dynamic Island** — ตอนตี 4 ที่ยืนรอรถอยู่ข้างถนน
ไม่มีใครเปิดแอป เขาปลดล็อกจอแล้วดู ทั้งหมดขับเคลื่อนจากเซิร์ฟเวอร์ผ่าน APNs โดยตรง
(`TripActivityService` เป็นแหล่งเดียวของข้อความและ ETA) ฝั่ง Android ใช้ ongoing
notification รับ state ก้อนเดียวกัน

**แผนที่เพื่อนร่วมทริป** — ตำแหน่งสดของคนในรอบเดียวกัน เปิด/ปิดเองทุกครั้ง เห็นเฉพาะ
ช่วงทริป และปิดแล้วลบข้อมูลทิ้งจริง

**เครื่องมือดูแลเนื้อหา (รายงาน / บล็อก)** — เพิ่มเข้ามาเพราะ App Store Guideline 1.2
บังคับให้แอปที่มีเนื้อหาจากผู้ใช้ต้องมีครบสี่อย่าง เดิมมีปุ่มรายงานอยู่ที่เดียวคือ
โพสต์ในฟีด ตอนนี้:

| ข้อกำหนดของ Apple | ของที่มีในรุ่นนี้ |
|---|---|
| กรองเนื้อหาไม่เหมาะสม | `ContentFilterService` ปฏิเสธคำหยาบตั้งแต่กดส่ง (แชท/รีวิว/โพสต์/คอมเมนต์) |
| รายงานเนื้อหาได้ | ชีตเดียวใช้ได้ทุกที่ + คิวให้แอดมินที่ `/admin/content-reports` |
| บล็อกผู้ใช้ที่ก่อกวน | บล็อกได้จากแชท/รีวิว/ฟีด/กำแพงรูป จัดการที่ โปรไฟล์ > ผู้ใช้ที่ถูกบล็อก |
| มีข้อมูลติดต่อ | หน้า "ติดต่อเรา" เดิม |

เนื้อหาที่ถูกรายงานครบ 5 ครั้งถูกซ่อนอัตโนมัติระหว่างรอทีมงานตรวจ การบล็อกมีผล
สองทาง — คนที่ถูกบล็อกก็ไม่เห็นเนื้อหาของคนบล็อกเช่นกัน ไม่งั้นเขาจะยังตอบโต้
ข้อความที่อีกฝ่ายมองไม่เห็นได้

## ก่อนส่งตรวจ — สิ่งที่ต้องเช็ค

- [ ] **บัญชีทดสอบสำหรับผู้ตรวจ** ยังเป็น `<TODO>` ในโน้ตข้างล่าง ต้องเติมก่อนส่ง
- [ ] บัญชีนั้นต้องมีใบจองที่ **ออกเดินทางภายใน 18 ชม.** ไม่งั้นผู้ตรวจจะไม่เห็นการ์ด
      บนหน้าจอล็อกเลยแล้วอาจตีกลับว่าฟีเจอร์ไม่ทำงาน
- [ ] prod ต้องตั้ง `APNS_*` ครบและ `trip-activity:sync` ต้องเดินทุกนาที ไม่งั้นการ์ด
      จะขึ้นครั้งเดียวแล้วค้างตัวเลขเดิม

## หลังปล่อยรุ่นนี้ — ตั้งค่าฝั่งเซิร์ฟเวอร์

```
LATEST_MOBILE_VERSION=1.13.0
MIN_MOBILE_VERSION=1.12.1
```

ตั้ง `MIN_MOBILE_VERSION` เป็น **1.12.1 ไม่ใช่ 1.13.0** — คนที่ยังติดอยู่บน 1.12.0 ที่พัง
ต้องถูกดันให้อัปเดต แต่ไม่มีเหตุผลจะบังคับคนที่ใช้รุ่นก่อนหน้าได้ปกติอยู่แล้ว และตั้ง
**หลัง**รุ่นนี้ผ่านรีวิวขึ้นสโตร์แล้วเท่านั้น

---

## What's New — ภาษาไทย (App Store Connect: "รายการใหม่ในเวอร์ชันนี้")

ช่องนี้เป็นข้อความล้วน ตัวหนาและ markdown ใด ๆ จะโผล่เป็นเครื่องหมายจริง ๆ ในสโตร์
ก้อนข้างล่างจึงไม่มี syntax ปนและตัดขึ้นบรรทัดเฉพาะที่ตั้งใจ วางได้ทั้งก้อน

```
รู้ว่ารถถึงเมื่อไหร่ โดยไม่ต้องเปิดแอป
ตอนตี 4 ที่ยืนรอรถอยู่ข้างถนน ไม่มีใครอยากปลดล็อกจอแล้วหาแอป รุ่นนี้เลยเอาคำตอบไปไว้ตรงหน้าจอล็อกเลย

ตั้งแต่ก่อนวันเดินทาง จะมีการ์ดขึ้นบนหน้าจอล็อกนับถอยหลังให้ พอถึงเช้าวันเดินทางมันจะเปลี่ยนเป็นเวลาที่รถจะถึงจุดรับของคุณ แล้วนับลดลงเรื่อย ๆ เอง รถถึงแล้วก็บอก ขึ้นรถแล้วก็เปลี่ยนเป็นขอให้เดินทางปลอดภัย ทั้งหมดนี้เกิดขึ้นเองโดยที่คุณไม่ต้องแตะอะไรเลย จบทริปแล้วการ์ดหายไปเอง

บน iPhone ที่มี Dynamic Island เวลาถึงจะโผล่อยู่ตรงนั้นด้วย เหลือบดูได้ระหว่างทำอย่างอื่น
(ต้องใช้ iOS 16.2 ขึ้นไป และปิดได้ที่ ตั้งค่า > ลุยเลเขา > Live Activities)

เห็นว่าเพื่อนร่วมทริปอยู่ตรงไหน
พอขึ้นดอยจริงคนกระจายกันเป็นกิโล คำถามที่ดังที่สุดคือหัวแถวถึงยัง กับน้องคนนั้นหายไปไหน ตอนนี้มีแผนที่ที่เห็นได้ในหน้าวันเดินทาง

เปิดสวิตช์แชร์แล้วเพื่อนในรอบเดียวกันจะเห็นว่าคุณอยู่ตรงไหน พร้อมบอกว่าห่างกันเท่าไร เห็นกันครั้งสุดท้ายเมื่อไหร่ และแบตของแต่ละคนเหลือเท่าไร เพราะคนที่หายไปเพราะแบตหมด กับคนที่หายไปเพราะเดินเข้าที่อับสัญญาณ เป็นคนละเรื่องกันสำหรับคนที่กำลังตามหา

เรื่องความเป็นส่วนตัวเราวางไว้แคบมากตั้งแต่แรก คุณกดเปิดเองทุกครั้ง ไม่มีการเปิดให้อัตโนมัติ เห็นได้เฉพาะคนที่อยู่ในรอบเดินทางเดียวกันเท่านั้น ใช้ได้เฉพาะช่วงวันทริป และพอกดปิด ตำแหน่งของคุณถูกลบออกจากระบบทันที ไม่ได้แค่ซ่อน เราไม่เก็บประวัติว่าคุณเดินไปทางไหนมาบ้าง

ธีมมืด
เปิดได้ที่ โปรไฟล์ ไปที่ การตั้งค่า แล้วเลือกธีมมืด ทั้งแอปเปลี่ยนตาม ไม่ใช่แค่แถบด้านบน ตัวหนังสือ เส้นคั่น พื้นการ์ด และพื้นหลังทุกหน้าปรับสีให้อ่านสบายตาในที่มืด แอปจำค่าที่เลือกไว้ให้ ไม่ต้องตั้งใหม่ทุกครั้งที่เปิด

ยอดที่ต้องโอนตรงกับความจริง
มัดจำแบบระบุจำนวนเงินคิดต่อคน จองเป็นกลุ่มแล้วเคยขึ้นยอดของคนเดียว ตอนนี้ขึ้นยอดของทั้งกลุ่มถูกต้อง
ส่วนลดมัดจำตามระดับสมาชิกแสดงในรายละเอียดแล้ว บอกชัดว่าหักไปเท่าไร
ทุกยอดในหน้าชำระเงินอ่านมาจากเซิร์ฟเวอร์ทางเดียว แอปไม่คำนวณเองอีกต่อไป ยอดที่เห็นในแอปกับยอดที่ทีมงานตรวจสลิปจึงเป็นตัวเดียวกันเสมอ

หน้าอัปโหลดสลิปบอกได้แล้วว่าแนบอะไรไป
เลือกรูปแล้วจะเห็นตัวอย่างรูปที่แนบก่อนกดส่ง กดพลาดรูปผิดก็เปลี่ยนได้ทันที ไม่ต้องส่งไปแล้วมาลุ้นทีหลัง

แก้หน้าการจองของฉันว่างเปล่า
ใครที่เคยไปทริปมาแล้ว เปิดหน้าการจองของฉันแล้วเจอหน้าว่าง ตอนนี้เห็นรายการครบทั้งทริปที่กำลังจะถึงและทริปที่ผ่านมาแล้ว

ห้องแชทบอกได้ว่าใครเพิ่งเข้ามา
ทีมงานเข้าห้องจะขึ้นข้อความแยกสีและไอคอนจากผู้ร่วมทริปทั่วไป จะได้รู้ว่าถามตอนนี้มีคนตอบ และถ้าใครเข้า ๆ ออก ๆ ห้อง จะไม่เด้งข้อความซ้ำกวนทั้งห้อง

ห้องแชทและรีวิวที่คุณดูแลเองได้
กดค้างที่ข้อความ รีวิว โพสต์ หรือรูปของคนอื่น จะมีทั้งรายงานให้ทีมงานตรวจ และบล็อกคนคนนั้น บล็อกแล้วคุณจะไม่เห็นเนื้อหาของเขา และเขาก็ไม่เห็นของคุณ เลิกบล็อกได้ที่ โปรไฟล์ ไปที่ ผู้ใช้ที่ถูกบล็อก

และอีกหลายจุดที่ทำให้ใช้ง่ายขึ้น
หน้าจอที่กำลังโหลดจะขึ้นโครงของเนื้อหาแทนวงกลมหมุนเปล่า ๆ โหลดไม่สำเร็จก็กดลองใหม่ได้ตรงนั้น ปุ่มไอคอนเล็ก ๆ ทั่วแอปกดง่ายขึ้นและอ่านออกเสียงได้ด้วย VoiceOver
```

## Google Play — ก้อนสั้น (จำกัด 500 ตัวอักษร)

Play ตัดที่ 500 ตัวอักษรพอดี ก้อนนี้จึงเล่าเฉพาะสองเรื่องใหญ่

```
รู้ว่ารถถึงเมื่อไหร่โดยไม่ต้องเปิดแอป — วันเดินทางจะมีการ์ดขึ้นบนแถบแจ้งเตือน บอกเวลาที่รถจะถึงจุดรับของคุณ แล้วนับลดลงเองจนรถมาถึง

เห็นว่าเพื่อนร่วมทริปอยู่ตรงไหนบนแผนที่ พร้อมระยะห่างและแบตที่เหลือ คุณกดเปิดแชร์เองทุกครั้ง เห็นเฉพาะคนในรอบเดียวกัน ใช้ได้เฉพาะช่วงทริป และกดปิดแล้วลบทิ้งทันที

พร้อมธีมมืด ยอดชำระเงินที่ตรงกับความจริงทุกกรณี หน้าอัปโหลดสลิปที่เห็นรูปก่อนส่ง และแก้หน้าการจองของฉันที่เคยว่างเปล่า
```

---

## App Review Notes — English (App Store Connect: "Notes for Review")

ช่องนี้เป็นข้อความล้วนเหมือนกัน ก้อนข้างล่างจึงไม่มี markdown ปน วางได้ทั้งก้อน

> ยังมี TODO: ช่องบัญชีทดสอบสำหรับผู้ตรวจ ต้องเติมก่อนส่ง
>
> ตัดหัวข้อ "ของที่ยกมาจาก 1.12.1" ออกเพราะช่องนี้จำกัด 4,000 ตัวอักษร — ของเก่า
> ไม่ได้เปลี่ยนผลการรีวิว ส่วนที่เหลือคือสิ่งที่ผู้ตรวจต้องใช้ตัดสินจริง ๆ

```
About the app
Luilaykhao books guided hiking day trips in Thailand. Customers book seats on a dated
departure, then on the travel day use the app to find their pickup point and track the
shuttle van. Most of the interface is Thai, as our customers are. 1.12.1 was prepared
but its submission was cancelled, so this build carries its contents plus the two
features below.

Demo account
- Phone / email: <TODO: fill in reviewer test account>
- Password: <TODO> (no OTP required)
It has one upcoming and one completed booking, so booking detail, the trip-day screen,
group chat, Trip Recap and Passport are reachable without a purchase. The upcoming
booking departs within 18 hours, which is what makes item 1 appear.

1. Live Activity for the travel day (iOS 16.2+)
Our customers wait for a shuttle van by the roadside, often before dawn. Rather than
make them unlock the phone and find an app to learn how far away the van is, this build
puts that answer on the Lock Screen and in the Dynamic Island.

The card begins as a countdown the day before departure, becomes a live ETA to the
customer's own pickup point on the morning of the trip, confirms when the van arrives,
and ends after they board. The app starts the Activity once; every later update is
computed on our server and delivered over APNs, so it stays correct while the app is
closed. It shows only the customer's own trip name, pickup point and the van's ETA.

To see it: sign in, open the confirmed booking, tap "วันเดินทาง" (Travel Day), then lock
the device. Users can turn it off in Settings > Luilaykhao > Live Activities.

2. Live location sharing between travellers on the same trip
On a mountain trail a group spreads out over a kilometre or more, and what matters most
is where everyone else is. Until now the app could show the van but not the people.
This is opt-in and deliberately narrow:
- Off by default; the user turns it on for each trip.
- Visible only to travellers booked on the same departure plus the staff and driver
  assigned to it. Never public, never shared with third parties.
- Available only during the trip window; outside it the server refuses reads and writes.
- Turning it off deletes the record on our server immediately, not hidden or archived.
- One current position per person, never a track or history. Positions older than 30
  minutes are not served at all.
- Collected only in the foreground with sharing on. No background location is declared.
The location purpose strings were updated in this build to state this use explicitly.

To see it: same Travel Day screen, "เพื่อนร่วมทริปอยู่ตรงไหน". The map is readable
without sharing anything; the switch at the bottom controls sharing.

3. User-generated content and moderation (Guideline 1.2)
The app carries content written by customers: a group chat per departure, trip reviews
with photos and video, a post-trip photo feed, and a public photo wall built from those
reviews. This build adds the full set of controls for it.

- Filtering: a server-side word filter rejects abusive text at submission time, across
  chat, reviews, feed posts and comments. It cannot be bypassed from the client.
- Reporting: every piece of user content has a report action with a reason and an
  optional note. Long-press a chat message, or use the "..." button on a review, feed
  post or gallery photo.
- Automatic removal: content reaches our staff queue immediately, and anything reported
  by five different users is hidden automatically while it waits to be reviewed, so
  offensive material does not stay visible during the response window.
- Blocking: any customer can block another from the same menu, and manage the list under
  Profile > ผู้ใช้ที่ถูกบล็อก (Blocked users). A block hides content in both directions
  and suppresses push notifications between the two people. Staff and drivers cannot be
  blocked, because they are the safety contact during a trip.
- Contact: Profile > ติดต่อเรา (Contact us) carries our phone, email and LINE, and
  Profile > แชทกับทีมงาน reaches our staff directly.

Payments - no in-app purchase, by design
Unchanged from 1.11.0. Everything sold is a real-world physical service: a seat on a
guided trip departing on a specific date, transport, and optional physical equipment
rental. Under Guideline 3.1.3(e)/3.1.5 these are consumed outside the app and are not
eligible for in-app purchase. No digital content, subscription or unlockable feature is
sold anywhere, and this build adds no new purchase path. Payment is by Thai bank
transfer / PromptPay QR: the app shows a QR code, the customer pays in their own banking
app, then uploads the slip for our staff to verify.

Permissions
- Location (When In Use): sort pickup points by distance, show the customer beside the
  van on the tracking map, and - new here, opt-in only - share position with fellow
  travellers on the same departure. No background location; vehicle GPS comes from our
  separate driver app.
- Camera: check-in QR scan and photographing a transfer slip.
- Photo Library / Add: profile photo, slip image, saving trip photos and the Recap card.
- Calendar (write-only): the "Add to calendar" button on a booking.
- Face ID: optional unlock instead of the password.
- Notifications: departure and payment reminders, driver-arrival and SOS alerts, group
  chat, and Live Activity updates.

```
