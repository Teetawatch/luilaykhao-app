package com.luilaykhao.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * ต้องเป็น FlutterFragmentActivity ไม่ใช่ FlutterActivity
 *
 * androidx.biometric.BiometricPrompt ที่ local_auth ใช้ ต้องได้ FragmentActivity
 * เท่านั้น ถ้าเป็น FlutterActivity ธรรมดา ปลั๊กอินจะตอบ NOT_FRAGMENT_ACTIVITY
 * กลับมาทุกครั้งโดยไม่เคยแสดงหน้าต่างสแกนนิ้วเลย — ผลคือคนที่เปิด "ล็อกด้วย
 * ไบโอเมตริก" ไว้ จะค้างอยู่ที่หน้าปลดล็อกและเข้าแอปไม่ได้อีกเลย
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HomeWidgetChannel.register(this, flutterEngine)
    }
}
