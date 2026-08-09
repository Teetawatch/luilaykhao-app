# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# local_auth (Biometrics)
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }

# flutter_local_notifications
#
# ปลั๊กอินเก็บ NotificationDetails ลง SharedPreferences เป็น JSON ผ่าน Gson แล้ว
# อ่านกลับด้วย `TypeToken<ArrayList<NotificationDetails>>` (FlutterLocalNotificationsPlugin
# .loadScheduledNotifications) ซึ่งต้องพึ่ง generic signature ที่ R8 ตัดทิ้งโดย
# ปริยาย ถ้าไม่เก็บไว้ Gson จะคืน LinkedTreeMap แล้ว rescheduleNotifications()
# ที่ถูกเรียกจาก BOOT_COMPLETED receiver (อยู่นอก MethodChannel จึงไม่มีใครรับ
# exception ให้) จะพังทั้งตัว และปลั๊กอินไม่ได้แถม consumer rules มาให้
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# Gson
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-dontwarn sun.misc.**

# OkHttp / Guzzle (used internally by some plugins)
-dontwarn okhttp3.**
-dontwarn okio.**

# General Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
