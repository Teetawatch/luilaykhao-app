package com.luilaykhao.app

import android.content.Context
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * สัญญาข้อมูลของวิดเจ็ตหน้าโฮม ฝั่ง Android
 *
 * แอปเป็นฝ่ายเขียน (ผ่าน [HomeWidgetChannel]) วิดเจ็ตเป็นฝ่ายอ่าน ([TripCountdownWidget])
 * ทั้งคู่อยู่โปรเซสเดียวกัน จึงใช้ SharedPreferences ธรรมดาได้ ไม่ต้องมี App Group
 * เหมือนฝั่ง iOS
 *
 * ⚠️ ชื่อคีย์ต้องตรงกับที่ `HomeWidgetService` ฝั่ง Laravel ส่งมาและที่ฝั่ง Dart
 * ประกอบไว้ (snake_case) — ตั้งใจไม่แปลงเป็น camelCase เพื่อให้มีคำศัพท์ชุดเดียว
 * ตลอดสาย
 */
object HomeWidgetStore {
    private const val PREFS = "luilaykhao_home_widget"
    private const val KEY_SNAPSHOT = "home_widget_snapshot"

    /**
     * ต้องตรงกับ `HomeWidgetService::SNAPSHOT_VERSION` ฝั่ง Laravel และ
     * `HomeWidgetSnapshot.contractVersion` ฝั่ง Dart
     */
    private const val CONTRACT_VERSION = 1

    fun write(context: Context, json: String) {
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT, json)
            .apply()
    }

    fun clear(context: Context) {
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT)
            .apply()
    }

    /**
     * snapshot ล่าสุดที่แอปเขียนไว้ — null เมื่อยังไม่มี, อ่านไม่ได้, หรือคนละเวอร์ชัน
     *
     * เวอร์ชันที่บิลด์นี้ไม่รู้จัก = วาดไปก็เสี่ยงแปลผิด ยอมขึ้นสถานะว่างดีกว่า
     */
    fun read(context: Context): HomeWidgetSnapshot? {
        val raw = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT, null)
            ?: return null

        return try {
            val json = JSONObject(raw)
            if (json.optInt("version", -1) != CONTRACT_VERSION) return null

            HomeWidgetSnapshot(
                trip = json.optJSONObject("trip")?.let { trip(it) },
                payment = json.optJSONObject("payment")?.let { payment(it) },
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun trip(json: JSONObject): HomeWidgetTrip? {
        // ไม่มีเลขการจองก็ไม่มีที่ให้แตะไป และแปลว่าก้อนนี้เพี้ยน — ทิ้งทั้งบล็อก
        val ref = json.string("booking_ref") ?: return null

        return HomeWidgetTrip(
            bookingRef = ref,
            tripTitle = json.string("trip_title") ?: "ทริปของคุณ",
            departureDate = json.string("departure_date"),
            validUntil = json.string("valid_until"),
            dateLabel = json.string("date_label") ?: "",
            departTime = json.string("depart_time"),
            countdownDays = json.optInt("countdown_days", 0),
            headline = json.string("headline") ?: "ทริปของคุณ",
            detail = json.string("detail") ?: "",
            stage = json.string("stage") ?: "countdown",
            progress = json.optDouble("progress", 0.0).coerceIn(0.0, 1.0),
            isLive = json.optBoolean("is_live", false),
        )
    }

    private fun payment(json: JSONObject): HomeWidgetPayment? {
        val ref = json.string("booking_ref") ?: return null

        return HomeWidgetPayment(
            bookingRef = ref,
            tripTitle = json.string("trip_title") ?: "ทริปของคุณ",
            label = json.string("label") ?: "ยอดค้างชำระ",
            amountLabel = json.string("amount_label") ?: "",
            dueDate = json.string("due_date"),
            dueLabel = json.string("due_label") ?: "",
            overdue = json.optBoolean("overdue", false),
            slipPending = json.optBoolean("slip_pending", false),
        )
    }

    /** `optString` คืน "null" เป็นสตริงเมื่อค่าเป็น JSON null — ต้องกันเอง */
    private fun JSONObject.string(key: String): String? {
        if (!has(key) || isNull(key)) return null
        return optString(key).takeIf { it.isNotBlank() }
    }
}

data class HomeWidgetSnapshot(
    val trip: HomeWidgetTrip?,
    val payment: HomeWidgetPayment?,
)

data class HomeWidgetTrip(
    val bookingRef: String,
    val tripTitle: String,
    /** "2026-09-05" — วิดเจ็ตนับ "อีกกี่วัน" ใหม่จากค่านี้ทุกครั้งที่วาด */
    val departureDate: String?,
    /** วันกลับ — เลยวันนี้ไปแล้วถือว่าก้อนนี้หมดอายุ */
    val validUntil: String?,
    val dateLabel: String,
    val departTime: String?,
    val countdownDays: Int,
    val headline: String,
    val detail: String,
    val stage: String,
    val progress: Double,
    /** true = การ์ดวันเดินทางกำลังทำงาน ใช้ [headline] ที่เซิร์ฟเวอร์เขียนมาทั้งดุ้น */
    val isLive: Boolean,
)

data class HomeWidgetPayment(
    val bookingRef: String,
    val tripTitle: String,
    val label: String,
    val amountLabel: String,
    val dueDate: String?,
    val dueLabel: String,
    val overdue: Boolean,
    val slipPending: Boolean,
)

/**
 * การนับวันของฝั่งวิดเจ็ต
 *
 * นี่คือที่เดียวที่ยอมให้ฝั่ง native คิดเลขเอง เพราะวิดเจ็ตต้องนับถอยหลังถูกต้อง
 * ข้ามคืนโดยไม่มีเน็ตและไม่มีใครเปิดแอป
 *
 * ใช้ `java.time` ซึ่งใช้ปฏิทินและรูปแบบ ISO ตายตัว ไม่ผูกกับ locale ของเครื่อง —
 * ถ้าใช้ `SimpleDateFormat` เครื่องที่ตั้งภาษาไทยจะตีความปีเป็น พ.ศ. แล้วนับถอยหลัง
 * ผิดไปห้าร้อยกว่าปี (desugaring เปิดไว้แล้วใน build.gradle.kts จึงใช้ได้ถึง API 24)
 */
object HomeWidgetClock {
    private val BANGKOK: ZoneId = ZoneId.of("Asia/Bangkok")

    fun today(): LocalDate = LocalDate.now(BANGKOK)

    private fun parse(date: String?): LocalDate? {
        if (date.isNullOrBlank()) return null
        return try {
            LocalDate.parse(date)
        } catch (_: Throwable) {
            null
        }
    }

    /** จำนวนวันเต็มจาก "วันนี้ที่กรุงเทพ" ถึงวันเป้าหมาย (ติดลบ = ผ่านไปแล้ว) */
    fun daysUntil(date: String?, today: LocalDate = today()): Int? {
        val target = parse(date) ?: return null
        return ChronoUnit.DAYS.between(today, target).toInt()
    }
}
