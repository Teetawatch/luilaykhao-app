# Luilaykhao 1.14.0 (48)

รุ่นก่อนหน้าที่**อยู่บน App Store จริง**: 1.13.0 (45) — ดู [RELEASE_1.13.0.md](RELEASE_1.13.0.md)

ระหว่างทางมี **1.13.1 (47)** ที่ตัดไว้เพื่อแก้ ITMS-90683 (ตัวสแกนของ Apple อ่านเจอ
`requestAlwaysAuthorization` ในโค้ดของ Geolocator เลยบังคับให้ต้องมีคีย์ always ใน
Info.plist ถึงแอปจะไม่เคยเรียกก็ตาม) รุ่นนั้น**ไม่เคยขึ้นสโตร์** เนื้อหาของมันจึงถูก
นับรวมมาอยู่ในรุ่นนี้ทั้งหมด และเลข build เดินต่อเป็น 48 เพราะ 46/47 ถูกเผาไปแล้ว —
เลขที่เคยอัปโหลดขึ้น App Store Connect ใช้ซ้ำไม่ได้ แม้จะยกเลิกการส่งตรวจไปแล้ว

ขึ้นเป็น **1.14.0** ไม่ใช่ 1.13.2 เพราะรุ่นนี้มีของใหม่ที่ผู้ใช้เห็นได้เยอะมาก
(68 คอมมิตนับจากจุดที่ตัด 1.13.0) ไม่ใช่ชุดแก้บั๊ก

## เรื่องใหญ่ในรุ่นนี้

**จ่ายด้วย QR ที่ยืนยันตัวเอง (Beam Checkout)** — เดิมลูกค้าต้องถ่ายสลิป กรอกวันที่
กรอกเวลา แล้วรอทีมงานตรวจ ตอนนี้เซิร์ฟเวอร์ได้ยินจากธนาคารโดยตรง ที่นั่งยืนยันภายใน
ไม่กี่วินาที **เปิดใช้จริงเมื่อฝั่งเซิร์ฟเวอร์ตั้งค่า credential ของ Beam แล้วเท่านั้น**
(`payment_gateway.provider == 'beam'` ในเพย์โหลดการจอง) ถ้ายังไม่ตั้ง แอปจะกลับไปใช้
หน้าอัปโหลดสลิปแบบเดิมโดยอัตโนมัติ — ทั้งสองทางยังอยู่ในไบนารีนี้

**ทริปต่างประเทศ / รอบที่เดินทางด้วยเครื่องบิน** — หน้าทริปตอบเรื่องวีซ่า สกุลเงิน
ปลั๊กไฟ และเวลาต่างกันกี่ชั่วโมง ขั้นตอนจองขอเลขพาสปอร์ตกับวันหมดอายุเพิ่ม รอบที่บิน
ไม่มีผังที่นั่งและไม่มีจุดรับ (นัดพบกันที่สนามบิน) และหน้ารวมทริปกรองตามปลายทางได้

**ประเภทรถต่อรอบ + ผังที่นั่งบัส** — รอบเดียวอาจวิ่งทั้งบัสและตู้ที่ราคาต่างกัน
ขั้นตอนจองจึงถามก่อนว่าขึ้นคันไหน ผังที่นั่งย่อทั้งคันให้พอดีจอ (เดิมบัสห้าที่ต่อแถว
ล้นออกนอกจอ) และล็อกที่นั่งผูกกับคันที่เลือก

**วิดเจ็ตหน้าโฮม "ทริปถัดไป"** — นับถอยหลังทริปถัดไปกับยอดที่ต้องจ่ายงวดหน้า
ทั้ง iOS และ Android วิดเจ็ตไม่ยิงเน็ตเอง แอปเป็นคนเติมข้อมูลให้

**การ์ดนับถอยหลังสำหรับสตอรี่** — 1080×1920 พร้อม QR ลิงก์เชิญของคนโพสต์เอง
(ไม่มีเลขที่ใบจองบนการ์ด — การ์ดนี้ทำมาให้คนแปลกหน้าเห็น)

## ก่อนส่งตรวจ — สิ่งที่ต้องเช็ค

- [ ] **บัญชีทดสอบสำหรับผู้ตรวจ** ยังเป็น `<TODO>` ในโน้ตข้างล่าง ต้องเติมก่อนส่ง
- [ ] บัญชีนั้นต้องมีใบจองที่ **ออกเดินทางภายใน 18 ชม.** ไม่งั้นผู้ตรวจจะไม่เห็น
      การ์ดบนหน้าจอล็อกและวิดเจ็ตหน้าโฮมจะว่าง
- [ ] iOS: App Group `group.com.luilaykhao.app` ต้องเปิดไว้ทั้ง `com.luilaykhao.app`
      และ `com.luilaykhao.app.LiveActivity` ไม่งั้นวิดเจ็ตขึ้นสถานะว่างเปล่าเงียบ ๆ
- [ ] prod ต้องตั้ง `APNS_*` ครบและ `trip-activity:sync` ต้องเดินทุกนาที

## หลังปล่อยรุ่นนี้ — ตั้งค่าฝั่งเซิร์ฟเวอร์

```
LATEST_MOBILE_VERSION=1.14.0
MIN_MOBILE_VERSION=1.13.0
```

ตั้ง **หลัง**รุ่นนี้ผ่านรีวิวขึ้นสโตร์แล้วเท่านั้น

---

## What's New — ภาษาไทย (App Store Connect: "รายการใหม่ในเวอร์ชันนี้")

ช่องนี้เป็นข้อความล้วน markdown ใด ๆ จะโผล่เป็นเครื่องหมายจริงในสโตร์ ก้อนข้างล่าง
จึงไม่มี syntax ปน วางได้ทั้งก้อน

```
โอนแล้วที่นั่งยืนยันเอง ไม่ต้องถ่ายสลิปอีกต่อไป
เดิมจ่ายเงินเสร็จยังต้องถ่ายรูปสลิป กรอกวันที่ กรอกเวลา แล้วนั่งรอทีมงานตรวจอีกหลายชั่วโมง ตอนนี้สแกน QR จ่ายจากแอปธนาคาร แล้วกลับเข้ามา ระบบรู้เองว่าเงินเข้าแล้วและยืนยันที่นั่งให้ภายในไม่กี่วินาที
ระหว่างรอ หน้าจอบอกตรง ๆ ว่ากำลังตรวจสอบอยู่ ไม่ใช่ค้างเป็นกล่องเปล่า และถ้าส่งสลิปเข้ามาแล้ว นาฬิกานับถอยหลังจะหยุด ไม่ขึ้นคำว่าหมดเวลาใส่คนที่โอนเงินมาแล้ว

เลือกได้เองว่าจะผ่อนกี่งวด
เดิมแอปยัดจำนวนงวดสูงสุดให้เสมอ ใครอยากผ่อนแค่ 2 งวดก็เลือกไม่ได้ ตอนนี้กดเลือกจำนวนงวดได้บนหน้าชำระเงิน และวันครบกำหนดแต่ละงวดอ่านมาจากระบบจริง ไม่ใช่ตัวเลขที่แอปคำนวณเดาเอง

ทริปต่างประเทศ
หน้าทริปที่บินออกนอกประเทศตอบให้ครบตั้งแต่ก่อนจอง ต้องขอวีซ่าไหม ใช้เงินสกุลอะไร ปลั๊กไฟแบบไหน เวลาต่างจากไทยกี่ชั่วโมง พร้อมรายละเอียดเที่ยวบินและสัมภาระ
ตอนจองจะมีช่องกรอกชื่อตามพาสปอร์ต เลขพาสปอร์ต และวันหมดอายุ แยกเป็นบล็อกของตัวเองเพราะพิมพ์ผิดตรงนี้แปลว่าขึ้นเครื่องไม่ได้ ส่วนรอบที่บินจะไม่ถามจุดขึ้นรถและไม่ต้องเลือกที่นั่งอีกต่อไป เพราะนัดพบกันที่สนามบิน

เลือกได้ว่าจะขึ้นรถคันไหน
บางรอบมีทั้งรถบัสและรถตู้ในราคาต่างกัน ตอนนี้เลือกได้เองตั้งแต่ขั้นตอนแรก บอกส่วนต่างต่อคนและที่ว่างที่เหลือของแต่ละคัน
ผังที่นั่งวาดทั้งคันให้พอดีจอแล้ว เดิมรถบัสที่นั่งห้าที่ต่อแถวจะล้นออกนอกจอจนต้องเลื่อนหาทีละที่ ที่นั่งที่มีคนจองแล้วเป็นสีแดง ที่ว่างเป็นสีเขียว คนอื่นกำลังถือไว้เป็นสีเหลือง และแตะที่นั่งที่จองไปแล้วจะบอกเหตุผล ไม่ใช่เงียบเฉย ๆ

ทริปถัดไปอยู่บนหน้าโฮม
เพิ่มวิดเจ็ตลงหน้าโฮมได้แล้วทั้ง iPhone และ Android นับถอยหลังทริปถัดไปพร้อมยอดที่ต้องจ่ายงวดหน้า ตัวเลขวันเดินถูกต้องเองแม้จะไม่ได้เปิดแอปมาหลายวัน

การ์ดนับถอยหลังสำหรับลงสตอรี่
เดิมหลายคนแคปหน้าจอการ์ดนับถอยหลังไปลงสตอรี่ แล้วโดนกรอบ 9:16 ครอบตัดจนตัวเลขหายไปครึ่ง ตอนนี้มีการ์ดที่ทำมาสำหรับสตอรี่โดยเฉพาะ รูปทริปเต็มกรอบ ตัวเลขนับถอยหลังตัวใหญ่ และ QR ลิงก์ชวนเพื่อนของคุณเอง กดแชร์ได้จากการ์ดบนหน้าแรกและจากชีตรายละเอียดการจอง

หน้าทริปอ่านง่ายขึ้น หาทริปเจอง่ายขึ้น
หน้ารายละเอียดทริปเรียงใหม่ให้รอบที่จะจองอยู่ต้น ๆ ไม่ใช่กองอยู่ใบที่สิบเท่ากับทุกอย่าง ส่วนหน้ารวมทริปกรองตามปลายทางได้แล้ว จะเที่ยวในไทยหรือออกนอกประเทศ แยกกันชัด และคำค้นที่เคยหาแล้วเจอทริปจริงจะขึ้นเป็นชิปให้กดซ้ำได้ ไม่ต้องพิมพ์ใหม่

ห้องแชทตอบคำถามที่ถามบ่อยให้เลย
แถบเหนือช่องพิมพ์มีกำหนดการของรอบนั้นแล้ว กดดูได้เลยไม่ต้องถาม และถ้าพิมพ์คำถามที่ห้องตอบได้อยู่แล้ว เช่น รถออกกี่โมง ขึ้นรถที่ไหน ทะเบียนรถอะไร คำตอบจะขึ้นมาให้เห็นตั้งแต่ยังพิมพ์ไม่จบ ไม่มีใครในห้องเห็นนอกจากคุณ
เบอร์โทรของทีมงานและคนขับที่ระบบโพสต์ในห้องกดโทรออกได้เลย ไม่ต้องจดออกมา

แนบเอกสารของทริปในแอป
ทริปที่ต้องใช้เอกสาร เช่น สำเนาบัตรหรือใบรับรองแพทย์ มีช่องแนบอยู่ในการ์ดผู้เดินทางแต่ละคนตอนจอง พร้อมข้อความบอกว่าเอกสารนั้นเอาไปใช้ทำอะไร ไม่ต้องส่งกันในแชทอีกต่อไป

ค้นหาการจองโดยไม่ต้องล็อกอิน
คนที่ไม่ได้เป็นคนจองเองก็เปิดดูได้ว่ารถออกกี่โมง ขึ้นที่ไหน จ่ายครบหรือยัง ค้นด้วยรหัสการจองจะเห็น QR เช็คอินและลิงก์ติดตามรถด้วย

ชวนเพื่อนมาอยู่ในใบจองเดียวกัน
เดิมทำได้อยู่แล้วแต่ซ่อนอยู่ท้ายชีต ตอนนี้เป็นการ์ดที่บอกออกมาตรง ๆ ว่าเชิญได้และเพื่อนจะได้อะไร ลิงก์ที่เคยส่งไปแล้วส่งซ้ำได้

บันทึกทริปที่ใช้รูปจริง
สรุปทริปหลังจบใช้รูปจากรีวิวของคนที่ไปทริปนั้นจริง พร้อมเครดิตชื่อเจ้าของรูป โดยเลือกรูปจากรอบเดียวกับคุณก่อน

และอีกหลายอย่างที่ซ่อมแล้ว
ปลดล็อกด้วยลายนิ้วมือหรือใบหน้าบน Android ใช้ได้แล้ว เดิมเปิดไว้แล้วเข้าแอปตัวเองไม่ได้เลย
แอปไม่ปิดตัวเองตอนจองสำเร็จบน iPhone อีกต่อไป
การแจ้งเตือนที่ตั้งเวลาไว้ไม่หายไปในเวอร์ชันที่ปล่อยจริงแล้ว
อัลบั้มรูปหลังทริปที่มีรูปเป็นร้อยเปิดได้โดยแอปไม่ดับ
การ์ดวันเดินทางบนหน้าจอล็อกกลับมาเองเมื่อ iPhone ปิดมันทิ้งกลางทริปสองวัน
หน้าเข้าสู่ระบบเรียบขึ้นและเป็นหน้าเดียวเหมือนหน้าสมัคร หน้าสมัครขอวันเกิดตั้งแต่แรก จะได้ไม่ต้องมาตามกรอกทีหลัง
รายการแจ้งเตือนไม่อ่านเป็นแถบสีรุ้งอีกต่อไป เรื่องด่วนกับเรื่องทั่วไปแยกกันออก
```

## Google Play — ก้อนสั้น (จำกัด 500 ตัวอักษร)

```
โอนแล้วที่นั่งยืนยันเอง — สแกน QR จ่ายจากแอปธนาคาร ระบบรู้เองว่าเงินเข้าแล้ว ไม่ต้องถ่ายสลิปและไม่ต้องรอตรวจอีกต่อไป

เพิ่มทริปต่างประเทศ ตอบเรื่องวีซ่า สกุลเงิน และเที่ยวบินตั้งแต่ก่อนจอง

เลือกได้เองว่าจะขึ้นรถบัสหรือรถตู้ ผังที่นั่งเห็นทั้งคันในจอเดียว และเลือกได้ว่าจะผ่อนกี่งวด

เพิ่มวิดเจ็ตทริปถัดไปลงหน้าโฮม และการ์ดนับถอยหลังสำหรับลงสตอรี่

แก้ปลดล็อกด้วยลายนิ้วมือที่เคยล็อกคนออกจากบัญชีตัวเอง และการแจ้งเตือนที่ตั้งเวลาไว้แล้วหาย
```

---

## App Review Notes — English (App Store Connect: "Notes for Review")

> **ช่องนี้จำกัด 4,000 ตัวอักษร** — เติมบัญชีทดสอบแล้ว **นับใหม่ก่อนวาง**:
>
> ```
> awk '/^## App Review Notes/,0' RELEASE_1.14.0.md \
>   | awk '/^```$/{n++; next} n==1' | python3 -c 'import sys; print(len(sys.stdin.read()))'
> ```

```
Luilaykhao books guided outdoor trips: customers reserve a seat on a dated departure,
then use the app on the travel day to find their pickup point and track the shuttle.
The interface is Thai. Previous store release: 1.13.0.

Demo account
- Phone / email: <TODO: fill in reviewer test account>
- Password: <TODO> (no OTP required)
It holds one upcoming and one completed booking, so booking detail, Travel Day, group
chat, Trip Recap and Passport are reachable without a purchase. The upcoming booking
departs within 18 hours, which is what makes the Live Activity appear.

Payments - no in-app purchase, by design
Everything sold is a real-world service consumed outside the app: a seat on a guided
trip leaving on a given date, transport, and optional physical equipment rental. Under
Guideline 3.1.3(e)/3.1.5 these are not eligible for in-app purchase, and no digital
content, subscription or unlockable feature is sold anywhere. Payment is by Thai bank
transfer / PromptPay QR. New here: where our server has the payment provider
configured, the QR it issues is confirmed by the bank directly and no slip is needed;
otherwise the app falls back to the previous flow, where the customer uploads a photo
of the transfer slip for staff to verify. The server decides which path a booking
takes.

New in this version
1. International departures. Trips leaving Thailand show visa, currency, socket and
time-difference facts, and the booking form asks for passport name, number and expiry
- required by the airline, stored like the existing ID-card field and never shared
with third parties. Domestic trips never show these fields.
2. Home screen widget (iOS and Android) showing the next trip's countdown and next
payment due. It never makes network requests: the app writes one snapshot into a
shared container and the widget draws it.
3. A shareable countdown image (1080x1920) for Instagram/Facebook stories, generated
on the device. It deliberately carries no booking reference.

Carried over from 1.13.0, unchanged and already reviewed
- Live Activity for the travel day (iOS 16.2+): a countdown before departure, then a
live ETA to that customer's own pickup point, ending after boarding. Updates are
pushed from our server over APNs. Sign in, open the confirmed booking, tap
"วันเดินทาง", then lock the device. Disable in Settings > Luilaykhao > Live
Activities.
- Opt-in live location sharing between travellers on the same departure. Off by
default, visible only to people booked on that departure plus its staff and driver,
only during the trip window, and turning it off deletes the record immediately. One
current position per person, never a track; foreground only.
- User-generated content controls (Guideline 1.2): a server-side word filter rejects
abusive text on submission across chat, reviews, posts and comments; every item has a
report action; anything reported by five people is hidden automatically pending staff
review; blocking sits in the same menus, is managed at Profile > Blocked users and
hides content both ways. Contact details are at Profile > Contact us, and
Profile > Chat with staff reaches our team.

Permissions
- Location (When In Use): sort pickup points by distance, place the customer beside
the van on the tracking map, and - opt-in only - the sharing above. The app never calls
requestAlwaysAuthorization; NSLocationAlwaysAndWhenInUseUsageDescription is present
only because the Geolocator plugin's compiled code references that selector and the
upload scanner rejects the build (ITMS-90683) without the key. No background location
mode is declared. Vehicle GPS comes from our separate driver app.
- Camera, Photo Library / Add, Calendar (write-only) and Face ID: QR check-in, trip
documents and profile images, saving trip photos, "Add to calendar", optional unlock.
- Notifications: departure and payment reminders, driver-arrival and SOS alerts, chat,
Live Activity updates.
```
