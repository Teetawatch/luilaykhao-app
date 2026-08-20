package com.luilaykhao.app

import java.time.LocalDate

/**
 * ข้อความบนวิดเจ็ตหน้าโฮมที่ฝั่ง native เป็นคนประกอบ
 *
 * ข้อความไทยเกือบทุกบรรทัดมาจาก `HomeWidgetService` ฝั่ง Laravel — ที่นี่มีเฉพาะ
 * ส่วนที่ต้องคิดใหม่ทุกครั้งที่วาด เพราะมันเก่าได้ในหนึ่งคืนและวิดเจ็ตต้องถูกต้อง
 * โดยไม่มีใครเปิดแอป
 *
 * ⚠️ ถ้อยคำในไฟล์นี้ต้องตรงกับสามที่: `HomeWidgetService` (PHP),
 * `TripCountdownCopy` / `HomeWidgetCopy` (Swift) และที่นี่ ถ้าไม่ตรง iOS กับ Android
 * จะนับวันเหมือนกันแต่พูดไม่เหมือนกัน ซึ่งดูเหมือนแอปพัง
 */
object HomeWidgetCopy {

    /** สิ่งที่บรรทัดใหญ่ควรขึ้น ณ เวลาที่วาด */
    sealed class Headline {
        /** นับถอยหลังเป็นวัน — ตัวเลขใหญ่ + "วัน" แล้วมีคำอธิบายใต้ตัวเลข */
        data class Days(val days: Int) : Headline()

        /** วันนี้ / พรุ่งนี้ — ไม่ต้องมีตัวเลข */
        data class Phrase(val big: String, val small: String) : Headline()

        /** ข้อความจากเซิร์ฟเวอร์ทั้งดุ้น (วันเดินทาง — มันรู้เรื่องรถซึ่งวิดเจ็ตไม่รู้) */
        data class Server(val text: String) : Headline()
    }

    const val DAYS_UNIT = "วัน"
    const val DAYS_CAPTION = "ก่อนออกเดินทาง"

    fun headline(trip: HomeWidgetTrip, today: LocalDate = HomeWidgetClock.today()): Headline {
        if (trip.isLive) return Headline.Server(trip.headline)

        // นับใหม่จากวันที่เสมอ ถ้าอ่านไม่ได้จึงถอยไปใช้เลขที่เซิร์ฟเวอร์ส่งมา
        val days = HomeWidgetClock.daysUntil(trip.departureDate, today) ?: trip.countdownDays

        return when {
            days < 0 -> Headline.Server(trip.headline)
            days == 0 -> Headline.Phrase("วันนี้", "ออกเดินทาง")
            days == 1 -> Headline.Phrase("พรุ่งนี้", "ออกเดินทาง")
            else -> Headline.Days(days)
        }
    }

    /** ทริปที่จบไปแล้วต้องหายจากหน้าโฮมเองโดยไม่ต้องรอให้ใครเปิดแอป */
    fun isExpired(trip: HomeWidgetTrip, today: LocalDate = HomeWidgetClock.today()): Boolean {
        val days = HomeWidgetClock.daysUntil(trip.validUntil ?: trip.departureDate, today)
            ?: return false

        return days < 0
    }

    /**
     * บรรทัดสถานะของยอดค้าง
     *
     * สามวลีที่อ้างอิง "วันนี้/พรุ่งนี้/เกินกำหนด" นับใหม่ที่นี่ ส่วนวันที่แบบมีเดือนไทย
     * (`ครบกำหนด 25 ส.ค. 2569`) ใช้ของเซิร์ฟเวอร์ตรง ๆ — ชื่อเดือนไทยกับปี พ.ศ.
     * ไม่ควรมีสูตรอยู่ในวิดเจ็ต
     */
    fun dueLine(payment: HomeWidgetPayment, today: LocalDate = HomeWidgetClock.today()): String {
        // แนบสลิปแล้วมาก่อนทุกอย่าง คนที่โอนเมื่อคืนแล้วเห็นวิดเจ็ตทวงว่าเกินกำหนด
        // จะเข้าใจว่าเงินหาย
        if (payment.slipPending) return payment.dueLabel

        val days = HomeWidgetClock.daysUntil(payment.dueDate, today) ?: return payment.dueLabel

        return when {
            days < 0 -> "เกินกำหนด ${-days} วัน"
            days == 0 -> "ครบกำหนดวันนี้"
            days == 1 -> "ครบกำหนดพรุ่งนี้"
            else -> payment.dueLabel
        }
    }

    /** สีแดงเตือนต้องเดินตามวันที่นับใหม่ ไม่ใช่ธงที่เซิร์ฟเวอร์ส่งมาเมื่อสามวันก่อน */
    fun isOverdue(payment: HomeWidgetPayment, today: LocalDate = HomeWidgetClock.today()): Boolean {
        if (payment.slipPending) return false
        val days = HomeWidgetClock.daysUntil(payment.dueDate, today) ?: return payment.overdue

        return days < 0
    }
}
