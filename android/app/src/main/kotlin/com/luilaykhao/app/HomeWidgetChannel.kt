package com.luilaykhao.app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * สะพานระหว่าง Flutter กับวิดเจ็ตหน้าโฮม
 *
 * หน้าที่มีสองอย่าง: รับ JSON จากฝั่ง Dart ไปเก็บไว้ที่ที่วิดเจ็ตอ่านได้ แล้วสั่งให้
 * วิดเจ็ตวาดใหม่ ตรรกะการวาดทั้งหมดอยู่ที่ [TripCountdownWidget]
 *
 * ชื่อ channel และชื่อเมธอดต้องตรงกับฝั่ง iOS ([HomeWidgetChannel] ใน Swift) เพราะ
 * โค้ด Dart ชุดเดียวเรียกทั้งสองแพลตฟอร์ม
 */
object HomeWidgetChannel {
    private const val CHANNEL = "luilaykhao/home_widget"

    fun register(context: Context, engine: FlutterEngine) {
        // ยึด application context ไว้ ไม่ใช่ Activity — handler อยู่กับ engine ซึ่ง
        // อายุยืนกว่าหน้าจอ ถ้าถือ Activity ไว้จะรั่ว
        val appContext = context.applicationContext

        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val json = call.argument<String>("json")
                        if (json.isNullOrEmpty()) {
                            result.error("bad_args", "ไม่มี json ที่จะเขียน", null)
                        } else {
                            HomeWidgetStore.write(appContext, json)
                            TripCountdownWidget.refresh(appContext)
                            result.success(true)
                        }
                    }

                    "clear" -> {
                        HomeWidgetStore.clear(appContext)
                        TripCountdownWidget.refresh(appContext)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
