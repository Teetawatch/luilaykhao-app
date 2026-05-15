# Firebase Setup Guide — luilaykhao-app

Step-by-step สำหรับ enable Crashlytics + Analytics + FCM push notification

---

## ✅ ตอนนี้คุณยังไม่มี Firebase project — เริ่มจากศูนย์

### Step 1 — สร้าง Firebase project

1. ไปที่ https://console.firebase.google.com
2. คลิก **Add project** → ตั้งชื่อ `Luilaykhao` (หรือชื่ออะไรก็ได้)
3. เปิด/ปิด Google Analytics ตามต้องการ (แนะนำเปิด — ใช้สำหรับ event tracking)
4. รอ provisioning ประมาณ 1 นาที

### Step 2 — Add Android app

1. ใน Firebase console → คลิก **Add app** → เลือก **Android**
2. กรอกข้อมูล:
   - **Android package name**: `com.luilaykhao.app`
     (verify จาก `android/app/build.gradle.kts` field `applicationId`)
   - **App nickname**: `Luilaykhao Customer`
   - **Debug signing certificate SHA-1** (optional แต่จำเป็นสำหรับ Google Sign-In/Phone auth)
     - Get ด้วย: `cd android && ./gradlew signingReport`
3. คลิก **Register app**

### Step 3 — Download google-services.json

1. Firebase จะให้ download `google-services.json`
2. **วางไฟล์ที่**: `c:/Project/luilaykhao/luilaykhao-app/android/app/google-services.json`
3. **ห้าม commit ไฟล์นี้ไป git** (เพิ่มใน `.gitignore` ถ้ายังไม่อยู่)

### Step 4 — Update Android build config

ตรวจ `c:/Project/luilaykhao/luilaykhao-app/android/build.gradle.kts` ว่ามี:

```kotlin
plugins {
    // ... existing
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
```

ถ้าไม่มี — เพิ่มเข้าไป

ตรวจ `android/app/build.gradle.kts` ว่ามี:

```kotlin
plugins {
    // ... existing
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}
```

### Step 5 — Run app to verify

```bash
cd c:/Project/luilaykhao/luilaykhao-app
flutter clean
flutter pub get
flutter run \
  --dart-define=FIREBASE_PROJECT_ID=luilaykhao-xxxxx \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:xxxxxxxxx:android:xxxxxxxxx \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=xxxxxxxxx
```

ค่าทั้ง 4 ค่าหาได้จาก:
- Firebase console → Project settings (เฟือง ⚙️) → General tab → Your apps section
- คลิก **google-services.json** หรือดู section "SDK setup and configuration"
- หรือเปิดไฟล์ `google-services.json` ที่ download มาแล้ว map:
  - `FIREBASE_PROJECT_ID` ← `project_info.project_id`
  - `FIREBASE_ANDROID_APP_ID` ← `client[0].client_info.mobilesdk_app_id`
  - `FIREBASE_API_KEY` ← `client[0].api_key[0].current_key`
  - `FIREBASE_MESSAGING_SENDER_ID` ← `project_info.project_number`

### Step 6 — Verify Crashlytics

1. Run app → trigger a crash:
   ```dart
   // เพิ่มปุ่ม debug ชั่วคราว
   ElevatedButton(
     onPressed: () => throw Exception('Test crash'),
     child: const Text('Crash test'),
   )
   ```
2. ปิด app ทั้งหมด → เปิดใหม่ → Crashlytics จะ upload ตอน app เริ่มใหม่
3. ใน Firebase console → Crashlytics → ภายใน 5 นาทีน่าจะเห็น crash report

### Step 7 — Verify FCM push notifications

1. Firebase console → Cloud Messaging → Send your first message
2. กรอก title + body → ในส่วน Target เลือก app `com.luilaykhao.app`
3. กด Send → device ที่ลง app + logged in อยู่ ควรได้ notification
4. ถ้าไม่ได้: ตรวจ device token ใน DB:
   ```sql
   SELECT * FROM push_tokens WHERE user_id = <your_user_id>;
   ```

### Step 8 — Production build

ใช้ dart-define-from-file สำหรับ production:

`.env.firebase` (สร้างใหม่ ไม่ commit):
```json
{
  "FIREBASE_PROJECT_ID": "luilaykhao-xxxxx",
  "FIREBASE_ANDROID_APP_ID": "1:xxx:android:yyy",
  "FIREBASE_API_KEY": "AIza...",
  "FIREBASE_MESSAGING_SENDER_ID": "xxx",
  "API_BASE_URL": "https://luilaykhao.com/api/v1",
  "REVERB_APP_KEY": "your-reverb-app-key",
  "REVERB_HOST": "luilaykhao.com",
  "REVERB_PORT": "443",
  "REVERB_SCHEME": "wss"
}
```

Build:
```bash
flutter build appbundle --release --dart-define-from-file=.env.firebase
```

---

## 🔐 Backend FCM credentials

Backend (Laravel) ต้อง send push notifications ก็ต้องการ Firebase Service Account JSON:

1. Firebase console → Project settings → **Service accounts** tab
2. คลิก **Generate new private key** → ได้ JSON file
3. วางที่ `c:/Project/luilaykhao/storage/app/firebase-service-account.json`
4. เพิ่มใน `.env`:
   ```env
   FIREBASE_CREDENTIALS=storage/app/firebase-service-account.json
   ```
5. ติดตั้ง package:
   ```bash
   composer require kreait/firebase-php
   ```

---

## 🧪 Troubleshooting

### "Default FirebaseApp is not initialized" error
- ตรวจ `google-services.json` ว่าอยู่ใน `android/app/` ไม่ใช่ `android/`
- รัน `flutter clean && flutter pub get` ใหม่
- ตรวจ `android/app/build.gradle.kts` ว่ามี `id("com.google.gms.google-services")`

### Crashlytics ไม่ขึ้น report
- ใน Flutter ผมตั้ง `setCrashlyticsCollectionEnabled(!kDebugMode)` แปลว่า debug build จะไม่ส่ง crash report
- ต้อง build release: `flutter run --release` หรือ build appbundle

### FCM token เป็น null
- ตรวจ Google Play Services ใน emulator (ต้องใช้ emulator with Google APIs)
- ตรวจว่า user login แล้ว (push_notification_service.dart ต้องการ Sanctum token ก่อน register)
- ดู logs: `flutter logs | grep -i fcm`
