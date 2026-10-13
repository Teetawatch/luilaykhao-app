# Luilaykhao 1.15.0 (49)

รุ่นก่อนหน้าบนสโตร์: **1.14.0 (48)** — ดู [RELEASE_1.14.0.md](RELEASE_1.14.0.md)

65 คอมมิตนับจากตัด 1.14.0 (2026-09-04 → 2026-10-13) ขึ้นเป็น **1.15.0** เพราะเป็น
ฟีเจอร์ใหม่ที่ผู้ใช้เห็นเยอะ ไม่ใช่ชุดแก้บั๊ก

## เรื่องที่ผู้ตรวจจะถามแน่ ๆ — สิทธิ์ใหม่สองตัว

- **ตำแหน่งต่อหลังล็อกจอ** — iOS เพิ่ม `UIBackgroundModes = location`, Android เพิ่ม
  `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` (ไม่ขอ
  `ACCESS_BACKGROUND_LOCATION` และยังไม่เคยขอ always บน iOS) ใช้กับ 3 อย่างที่ผู้ใช้
  กดเริ่มเองทุกครั้ง: บันทึกเส้นทางเดินป่า, แชร์ตำแหน่งให้เพื่อนร่วมรอบ, และสวิตช์
  "ใช้มือถือนี้เป็น GPS ของรถ" (เฉพาะบัญชีทีมงาน)
- **ไมโครโฟน** — ข้อความเสียงในห้องแชททริป ขอสิทธิ์ตอนกดปุ่มไมค์ครั้งแรก

## ก่อนส่งตรวจ — สิ่งที่ต้องเช็ค

- [ ] **deploy หลังบ้านก่อน** (`8398bee` ส่ง `booking_opens_at` มากับรายการรอบ) ไม่งั้น
      ปุ่ม "เปิดจอง" ของรอบที่ตั้งเวลาไว้จะไม่ทำงาน (แอปไม่พัง แค่กลับไปเป็น "จองเลย")
- [ ] **บัญชีทดสอบสำหรับผู้ตรวจ** ยังเป็น `<TODO>` ในโน้ตข้างล่าง เติมก่อนส่ง
- [ ] บัญชีนั้นต้องมีใบจองที่ **อยู่ในช่วงวันเดินทาง** (ไม่งั้นปุ่มบันทึกเส้นทางและสวิตช์
      แชร์ตำแหน่งจะไม่โผล่ ผู้ตรวจจะหาฟีเจอร์ที่ใช้ background location ไม่เจอ แล้ว
      ปฏิเสธด้วย 2.5.4) และควรมีใบจองที่จบทริปแล้วพร้อมเช็คอิน (เหรียญต้องเช็คอิน)
- [ ] **Google Play Console → App content → Foreground service permissions** ต้องประกาศ
      ประเภท *Location* พร้อมคำอธิบายและลิงก์วิดีโอสั้นที่โชว์การกดเริ่มบันทึกเส้นทาง
      (Android 14 ขึ้นไปบังคับ ไม่ประกาศ = รีวิวไม่ผ่าน)
- [ ] **Google Play → Data safety** เพิ่ม *Audio → Voice or sound recordings*
      (ข้อความเสียงในแชท: เก็บ, ไม่แชร์ต่อ, ใช้เพื่อฟังก์ชันของแอป)
- [ ] App Store Connect → App Privacy เพิ่ม *Audio Data* ในหมวดเดียวกัน

## หลังรุ่นนี้ขึ้นสโตร์แล้ว — ตั้งค่าฝั่งเซิร์ฟเวอร์

```
LATEST_MOBILE_VERSION=1.15.0
MIN_MOBILE_VERSION=1.13.0
```

ตั้ง **หลัง**ผ่านรีวิวทั้งสองสโตร์แล้วเท่านั้น (MIN ไม่ต้องขยับ — ไม่มีอะไรในรุ่นนี้
ที่ทำให้รุ่นเก่าใช้ไม่ได้)

---

## What's New — ภาษาไทย (App Store Connect: "รายการใหม่ในเวอร์ชันนี้")

ข้อความล้วน ไม่มี markdown วางได้ทั้งก้อน

```
เหรียญพิชิตทริป
เดินจบทริปแล้วได้เหรียญเก็บไว้ในตู้เหรียญของคุณ แต่งการ์ดเหรียญแล้วแชร์ลงสตอรี่ได้ ปรบมือให้เพื่อนที่จบรอบเดียวกัน ตั้งเป้าหมายรายเดือนรายปี และดูสรุปการเดินทางทั้งปีของคุณแบบสตอรี่

ห้องแชททริปทำได้มากกว่าเดิม
ส่งข้อความเสียงได้แล้ว ถามทีมงานแบบส่วนตัวได้โดยไม่ต้องพิมพ์ในห้องรวม โหวตเมื่อกลุ่มเลือกไม่ได้ สั่งอาหารจากบนรถแล้วหารบิล ขอแวะพักแบบไม่ต้องบอกชื่อ ขอยาถึงที่นั่ง แจ้งแพ้อาหาร ดูว่าพักห้องไหนกับใคร ประกาศของหาย และกด "ถึงบ้านแล้ว" หลังจบทริป
ปิดเสียงห้องที่ไม่อยากให้เด้งได้ และแจ้งเตือนแชทไม่ซ้อนกันเป็นตั้งอีกต่อไป

เช็คอินรายคน บัตรขึ้นรถของใครของมัน
ทุกคนในใบจองมี QR ขึ้นรถของตัวเอง ส่งให้เพื่อนแต่ละคนได้ บอกได้ว่าใครไปไม่ได้ และถ้าไปไม่ได้ทั้งที่นั่ง ส่งต่อที่นั่งให้คนอื่นได้ในแอปเลย

รู้ว่ารถคันไหนของคุณ
วันเดินทางมีการ์ดบอกทะเบียน สี และรูปรถ พร้อมรูปจุดที่รถจอดจริง หลังขึ้นรถแล้ว การ์ดเปลี่ยนเป็นแผนการเดินทางของวันนั้นและบอกเมื่อใกล้ถึงจุดส่ง
บันทึกเส้นทางและแชร์ตำแหน่งให้เพื่อนทำงานต่อแม้เก็บมือถือลงกระเป๋า

จองง่ายขึ้น
ขั้นเลือกจุดขึ้นรถและกรอกผู้เดินทางออกแบบใหม่ รอบที่ยังไม่ถึงเวลาเปิดจองบอกชัดว่าเปิดเมื่อไร มีคำอธิบายว่าจอยทริปคืออะไร และหน้ารายละเอียดทริปอ่านง่ายขึ้น
ซื้อบัตรของขวัญแบบระบุยอดให้คนที่คุณรัก หรือขอเหมาทริปสำหรับกลุ่มของคุณ ทีมงานส่งใบเสนอราคากลับมาในแอป
การจองที่ทีมงานจองให้ทาง LINE ดึงเข้าบัญชีในแอปได้ด้วยรหัสการจอง

ชำระเงินและใบเสร็จ
ยอดที่ทีมงานเพิ่มทีหลังจ่ายในแอปได้ ใบเสร็จแยกรายคนพร้อมปุ่มแชร์ และประวัติการจองแบ่งเป็นการเดินทางที่กำลังจะถึงกับที่ผ่านมา
ถ้าทริปถูกยกเลิกเพราะเหตุสุดวิสัยหรือคนไม่ครบ เลือกรอบใหม่หรือรับเงินคืนเต็มจำนวนได้เองในแอป

หน้าตาใหม่
แถบล่างมีปุ่มเช็คอิน QR ตรงกลางและแท็บทริปที่ถูกใจ หน้าแรกบอกสภาพอากาศของทริปถัดไป หน้ารีวิวมีภาพรวมคะแนนและกรองดูรีวิวที่มีรูปได้ กล่องยืนยันทุกจุดออกแบบใหม่ทั้งหมด และแถบออฟไลน์เล็กลงไม่บังจอ
การ์ดสตอรี่แต่งเองได้ มีแบบสติกเกอร์พื้นใส บันทึกลงคลังรูปได้ และเปลี่ยนรีวิวของคุณเป็นการ์ดสตอรี่ได้

แก้ไขแล้ว
หน้าคิวรอที่นั่งไม่ว่างเปล่าอีกต่อไป
ตัวหนังสือบางจุดที่อ่านไม่ออกในโหมดมืด
และอื่น ๆ อีกหลายจุด
```

## Google Play — Release notes (จำกัด 500 ตัวอักษร)

```
ใหม่: เหรียญพิชิตทริป ตู้เหรียญ และสรุปการเดินทางทั้งปี
ห้องแชทส่งข้อความเสียงได้ ถามทีมงานแบบส่วนตัว โหวต สั่งอาหาร หารบิล
QR ขึ้นรถรายคน และส่งต่อที่นั่งให้คนอื่นได้
การ์ดบอกว่ารถคันไหนของคุณ บันทึกเส้นทางได้แม้ล็อกจอ
บัตรของขวัญ ขอเหมาทริป และรอบที่ยังไม่เปิดจองบอกเวลาเปิดชัดเจน
หน้าแรก หน้ารีวิว และขั้นตอนจองออกแบบใหม่
```

---

## App Review Notes — English (App Store Connect: "Notes for Review")

> จำกัด 4,000 ตัวอักษร — เติมบัญชีทดสอบแล้วนับใหม่ก่อนวาง:
>
> ```
> awk '/^## App Review Notes/,0' RELEASE_1.15.0.md \
>   | awk '/^```$/{n++; next} n==1' | python3 -c 'import sys; print(len(sys.stdin.read()))'
> ```

```
Luilaykhao books guided outdoor trips: customers reserve a seat on a dated departure,
then use the app on the travel day. The interface is Thai. Previous store release: 1.14.0.

Demo account
- Phone / email: <TODO: reviewer test account>
- Password: <TODO> (no OTP required)
It holds a booking whose trip is in progress today, so the Travel Day screen, trek
recorder, location-sharing switch and group chat are reachable without a purchase, plus
a completed, checked-in trip that has earned a medal.

Two new permissions in this version
1. Background location (UIBackgroundModes: location). Still "When In Use" only - the app
never requests Always. It keeps reading location after the screen locks for three
features, each started by the user tapping a button and stopped the same way:
- Trek recorder: records the route a customer walks on a multi-hour hike. Open the
in-progress booking > "วันเดินทาง", card "บันทึกการเดินของฉัน", tap "เริ่มบันทึก".
The track stays on the device unless the customer taps "บันทึก" to save it.
- Location sharing with travellers on the same departure (already reviewed in 1.13.0,
now continues while locked). Off by default, visible only to that departure's members
and staff during the trip window; turning it off deletes the record.
- Staff accounts only: "use this phone as the van's GPS", so customers see where their
van is.
iOS shows the blue location indicator the whole time. Nothing runs at app launch or
when no trip is in progress.
2. Microphone: voice messages in the trip group chat. Recording runs only from
tapping the mic button until the user taps send or discard. Permission is asked on
first use.

Payments - no in-app purchase, by design
Everything sold is a real-world service consumed outside the app: a seat on a guided
trip, transport, and physical equipment rental (Guidelines 3.1.3(e)/3.1.5). New: gift
vouchers with a fixed baht value, redeemable only against those same trips; group
charter quotes. Both are paid by Thai bank transfer / PromptPay QR like every booking,
and neither unlocks any digital content or app feature.

Other new things, no new data or permissions
Finisher medals and a yearly recap generated on the device; one boarding QR per
traveller; handing a seat to another person by link; a card showing the plate and
photo of the customer's van; private questions to staff in the chat; polls and food
orders in the chat; refunds or re-booking when a departure is cancelled.

User-generated content (Guideline 1.2), unchanged
Every chat message from someone else - text, photo or voice - has "report or block
sender" on long-press. A server-side filter rejects abusive text; anything reported
by five people is hidden pending staff review; blocking hides content both ways and is
managed at Profile > Blocked users. Profile > Contact us reaches our team.

Other permissions (unchanged): Camera (QR check-in, documents), Photo Library / Add
(profile, documents, saving trip photos and share cards), Calendar write-only (Add to
calendar), Face ID (optional unlock), Notifications, Live Activity.
```
