package com.luilaykhao.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

/**
 * วิดเจ็ตหน้าโฮม "อีก 17 วันไปเขาช้างเผือก"
 *
 * ไม่ต่อเน็ตเอง อ่านแต่ snapshot ที่แอปเขียนไว้ (ดู [HomeWidgetStore]) ตรงข้ามกับ
 * การ์ดวันเดินทางบน Android ที่เป็น ongoing notification และรับข้อมูลทาง FCM
 *
 * ใช้ RemoteViews ธรรมดา ไม่ใช่ Glance โดยตั้งใจ — Glance ต้องลาก Compose เข้ามาทั้ง
 * ชุด (ทั้ง compiler plugin, ขนาด APK, และเวอร์ชัน Kotlin ที่ต้องล็อกให้ตรงกัน) เพื่อ
 * วาดข้อความสี่บรรทัดกับแถบเดียว RemoteViews ได้ผลลัพธ์เดียวกันโดยไม่เพิ่ม
 * dependency ใด ๆ และไม่มีอะไรให้พังตอนอัปเกรด Flutter
 *
 * ⚠️ ทุกอย่างในนี้ห่อ try/catch ไว้ — โค้ดที่โยน exception ใน onUpdate ทำให้โปรเซส
 * ของแอปตาย ผู้ใช้เห็นเป็น "แอปเด้ง" ทั้งที่ไม่ได้เปิดแอปอยู่เลย
 */
class TripCountdownWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it) }
    }

    /**
     * ผู้ใช้ย่อ/ขยายวิดเจ็ต — ต้องวาดใหม่เพราะคอลัมน์ยอดค้างแสดงเฉพาะตอนกว้างพอ
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId)
    }

    companion object {
        private const val TAG = "TripCountdownWidget"

        /** กว้างกว่านี้ (dp) จึงมีที่พอให้คอลัมน์ยอดค้าง — ประมาณ 4 ช่องขึ้นไป */
        private const val WIDE_MIN_WIDTH_DP = 250

        private const val COLOR_ACCENT = 0xFF10B981.toInt()
        private const val COLOR_WARNING = 0xFFFB7171.toInt()
        private const val COLOR_TEXT = 0xFFFFFFFF.toInt()
        private const val COLOR_MUTED = 0xB8FFFFFF.toInt()
        private const val COLOR_FAINT = 0x8CFFFFFF.toInt()

        /** วาดวิดเจ็ตทุกตัวใหม่ — เรียกจาก [HomeWidgetChannel] หลังแอปเขียนข้อมูลใหม่ */
        fun refresh(context: Context) {
            try {
                val manager = AppWidgetManager.getInstance(context) ?: return
                val ids = manager.getAppWidgetIds(
                    ComponentName(context.applicationContext, TripCountdownWidget::class.java)
                )
                ids.forEach { render(context, manager, it) }
            } catch (e: Throwable) {
                Log.w(TAG, "refresh failed", e)
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            try {
                val snapshot = HomeWidgetStore.read(context)
                val wide = isWide(manager, appWidgetId)
                manager.updateAppWidget(appWidgetId, build(context, snapshot, wide, appWidgetId))
            } catch (e: Throwable) {
                // วาดไม่ได้ก็ปล่อยของเดิมค้างไว้ ดีกว่าทำให้โปรเซสตาย
                Log.w(TAG, "render failed", e)
            }
        }

        private fun isWide(manager: AppWidgetManager, appWidgetId: Int): Boolean {
            val options = manager.getAppWidgetOptions(appWidgetId) ?: return false
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

            // 0 = ระบบยังไม่ได้บอกขนาด (เพิ่งวาง) — เดาว่ากว้าง เพราะขนาดตั้งต้นของ
            // วิดเจ็ตนี้คือ 4 ช่อง ตามที่ประกาศใน widget_trip_countdown_info.xml
            return minWidth == 0 || minWidth >= WIDE_MIN_WIDTH_DP
        }

        private fun build(
            context: Context,
            snapshot: HomeWidgetSnapshot?,
            wide: Boolean,
            appWidgetId: Int,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_trip_countdown)

            val today = HomeWidgetClock.today()
            val trip = snapshot?.trip?.takeUnless { HomeWidgetCopy.isExpired(it, today) }
            val payment = snapshot?.payment

            when {
                trip != null -> {
                    drawTrip(views, trip, today)
                    val showPayment = payment != null && wide
                    drawPaymentColumn(views, if (showPayment) payment else null, today)
                    views.setOnClickPendingIntent(
                        R.id.widget_root,
                        bookingIntent(context, trip.bookingRef, appWidgetId * 2)
                    )
                    if (showPayment && payment != null) {
                        views.setOnClickPendingIntent(
                            R.id.widget_payment_column,
                            bookingIntent(context, payment.bookingRef, appWidgetId * 2 + 1)
                        )
                    }
                }

                // ไม่มีทริปข้างหน้าแล้วแต่ยังมียอดค้าง (จ่ายไม่ครบหลังกลับจากทริป) —
                // เรื่องนี้ยังต้องบอก ไม่ใช่ปล่อยวิดเจ็ตว่าง
                payment != null -> {
                    drawPaymentAsPrimary(views, payment, today)
                    drawPaymentColumn(views, null, today)
                    views.setOnClickPendingIntent(
                        R.id.widget_root,
                        bookingIntent(context, payment.bookingRef, appWidgetId * 2)
                    )
                }

                else -> {
                    drawEmpty(views)
                    drawPaymentColumn(views, null, today)
                    // ไม่มีอะไรให้ไป — เปิดแอปเฉย ๆ
                    views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, appWidgetId * 2))
                }
            }

            return views
        }

        private fun drawTrip(views: RemoteViews, trip: HomeWidgetTrip, today: java.time.LocalDate) {
            views.setTextViewText(R.id.widget_title, trip.tripTitle)
            views.setImageViewResource(R.id.widget_icon, iconFor(trip.stage))

            when (val headline = HomeWidgetCopy.headline(trip, today)) {
                is HomeWidgetCopy.Headline.Days -> {
                    setBig(views, "${headline.days} ${HomeWidgetCopy.DAYS_UNIT}", 34f, COLOR_ACCENT)
                    setCaption(views, HomeWidgetCopy.DAYS_CAPTION)
                }

                is HomeWidgetCopy.Headline.Phrase -> {
                    setBig(views, headline.big, 26f, COLOR_ACCENT)
                    setCaption(views, headline.small)
                }

                is HomeWidgetCopy.Headline.Server -> {
                    setBig(views, headline.text, 18f, COLOR_TEXT)
                    setCaption(views, null)
                }
            }

            views.setTextViewText(R.id.widget_detail, trip.detail)
            views.setTextColor(R.id.widget_detail, COLOR_FAINT)
            views.setViewVisibility(
                R.id.widget_detail,
                if (trip.detail.isBlank()) View.GONE else View.VISIBLE
            )

            val showProgress = trip.isLive && trip.progress > 0
            views.setViewVisibility(
                R.id.widget_progress,
                if (showProgress) View.VISIBLE else View.GONE
            )
            if (showProgress) {
                views.setProgressBar(R.id.widget_progress, 100, (trip.progress * 100).toInt(), false)
            }
        }

        private fun drawPaymentAsPrimary(
            views: RemoteViews,
            payment: HomeWidgetPayment,
            today: java.time.LocalDate,
        ) {
            val overdue = HomeWidgetCopy.isOverdue(payment, today)

            views.setTextViewText(R.id.widget_title, payment.tripTitle)
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_wallet)
            setBig(views, payment.amountLabel, 26f, if (overdue) COLOR_WARNING else COLOR_TEXT)
            setCaption(views, payment.label)

            views.setTextViewText(R.id.widget_detail, HomeWidgetCopy.dueLine(payment, today))
            views.setTextColor(R.id.widget_detail, if (overdue) COLOR_WARNING else COLOR_FAINT)
            views.setViewVisibility(R.id.widget_detail, View.VISIBLE)
            views.setViewVisibility(R.id.widget_progress, View.GONE)
        }

        private fun drawEmpty(views: RemoteViews) {
            views.setTextViewText(R.id.widget_title, "ลุยเลเขา")
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_mountain)
            setBig(views, "ยังไม่มีทริปที่จะไป", 18f, COLOR_TEXT)
            setCaption(views, null)
            views.setTextViewText(R.id.widget_detail, "แตะเพื่อดูรอบที่เปิดรับ")
            views.setTextColor(R.id.widget_detail, COLOR_FAINT)
            views.setViewVisibility(R.id.widget_detail, View.VISIBLE)
            views.setViewVisibility(R.id.widget_progress, View.GONE)
        }

        private fun drawPaymentColumn(
            views: RemoteViews,
            payment: HomeWidgetPayment?,
            today: java.time.LocalDate,
        ) {
            if (payment == null) {
                views.setViewVisibility(R.id.widget_payment_column, View.GONE)
                views.setViewVisibility(R.id.widget_divider, View.GONE)
                return
            }

            val overdue = HomeWidgetCopy.isOverdue(payment, today)

            views.setViewVisibility(R.id.widget_payment_column, View.VISIBLE)
            views.setViewVisibility(R.id.widget_divider, View.VISIBLE)
            views.setTextViewText(R.id.widget_payment_label, payment.label)
            views.setTextViewText(R.id.widget_payment_amount, payment.amountLabel)
            views.setTextColor(
                R.id.widget_payment_amount,
                if (overdue) COLOR_WARNING else COLOR_TEXT
            )
            views.setTextViewText(R.id.widget_payment_due, HomeWidgetCopy.dueLine(payment, today))
            views.setTextColor(R.id.widget_payment_due, if (overdue) COLOR_WARNING else COLOR_FAINT)
        }

        private fun setBig(views: RemoteViews, text: String, sizeSp: Float, color: Int) {
            views.setTextViewText(R.id.widget_big, text)
            views.setTextViewTextSize(R.id.widget_big, TypedValue.COMPLEX_UNIT_SP, sizeSp)
            views.setTextColor(R.id.widget_big, color)
        }

        private fun setCaption(views: RemoteViews, text: String?) {
            if (text.isNullOrBlank()) {
                views.setViewVisibility(R.id.widget_caption, View.GONE)
                return
            }
            views.setViewVisibility(R.id.widget_caption, View.VISIBLE)
            views.setTextViewText(R.id.widget_caption, text)
            views.setTextColor(R.id.widget_caption, COLOR_MUTED)
        }

        /**
         * แตะแล้วเปิดหน้าการจองในแอป
         *
         * ตั้ง component ตรง ๆ (explicit intent) ไม่พึ่งให้ระบบหา activity จาก
         * intent-filter — วิดเจ็ตเป็นของแอปเดียวกัน ไม่มีเหตุให้ผ่านตัวเลือกของระบบ
         * ส่วน `data` ยังใส่ไว้เพราะปลั๊กอิน app_links ฝั่ง Dart อ่านจากที่นั่น
         *
         * requestCode ต้องไม่ซ้ำกันระหว่างปุ่ม ไม่งั้น PendingIntent ตัวหลังจะทับตัวแรก
         * แล้วแตะคอลัมน์ยอดค้างจะเด้งไปหน้าเดียวกับแตะทริป
         */
        private fun bookingIntent(context: Context, ref: String, requestCode: Int): PendingIntent {
            val intent = Intent(context.applicationContext, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("luilaykhao://booking/$ref")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

            return PendingIntent.getActivity(
                context.applicationContext,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun launchIntent(context: Context, requestCode: Int): PendingIntent {
            val intent = Intent(context.applicationContext, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            return PendingIntent.getActivity(
                context.applicationContext,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun iconFor(stage: String): Int = when (stage) {
            "arriving", "approaching", "enroute", "arrived" -> R.drawable.ic_widget_bus
            "onboard" -> R.drawable.ic_widget_check
            "preparing", "meetup", "boarding" -> R.drawable.ic_widget_backpack
            else -> R.drawable.ic_widget_mountain
        }
    }
}
