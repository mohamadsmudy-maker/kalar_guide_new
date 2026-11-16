package com.muhammad.kalar.kalar_guide

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Locale

/**
 * ویجێتی سەر شاشە: نوێژی داهاتوو (بە کاتژمێری زیندوو) + هەر شەش کاتەکە +
 * پلەی گەرما + نرخی دۆلار. ڕەنگی پاشبنەما بەپێی کاتی ڕۆژ دەگۆڕێت.
 * داتاکە لە Dart (HomeWidgetService) دەنێردرێت؛ «نوێژی داهاتوو» لێرە هەژمار
 * دەکرێت، بۆیە بێ ئینتەرنێت و بێ کردنەوەی ئەپ دروستە.
 */
class KalarWidgetProvider : HomeWidgetProvider() {

    private data class Slot(val id: String, val millis: Long, val day: String)

    private class Cell(val id: String, val box: Int, val name: Int, val time: Int)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val next = findNext(widgetData, now)
        val kurdishDigits = widgetData.getString("digits", "0") == "1"
        val lang = widgetData.getString("lang", "ku") ?: "ku"
        val rtl = lang != "en"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kalar_widget)
            val heightDp = appWidgetManager.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

            views.setInt(
                R.id.widget_root,
                "setLayoutDirection",
                if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
            )
            views.setInt(R.id.widget_root, "setBackgroundResource", background(next?.id))

            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("title", "ڕێبەری کەلار"),
            )
            views.setTextViewText(
                R.id.widget_next_label,
                widgetData.getString("next_label", ""),
            )

            // بەرواری ئەمڕۆ (ئەگەر داتاکە کۆن بوو، بەتاڵ دەمێنێت)
            val today = todayKey()
            val dayOfToday = when (today) {
                widgetData.getString("d0_date", null) -> "d0"
                widgetData.getString("d1_date", null) -> "d1"
                else -> null
            }
            views.setTextViewText(
                R.id.widget_date,
                dayOfToday?.let { widgetData.getString("${it}_label", "") } ?: "",
            )

            if (next != null) {
                val name = widgetData.getString("name_${next.id}", "") ?: ""
                views.setTextViewText(R.id.widget_prayer_name, name)
                views.setTextViewText(
                    R.id.widget_prayer_time,
                    digits(hhmm(next.millis), kurdishDigits),
                )
                val diff = next.millis - now
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // کاتژمێری زیندوو: بێ نوێکردنەوە خۆی دادەبەزێت
                    views.setChronometer(
                        R.id.widget_countdown,
                        SystemClock.elapsedRealtime() + diff,
                        "⏳ %s",
                        true,
                    )
                    views.setChronometerCountDown(R.id.widget_countdown, true)
                    views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_remaining, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_countdown, View.GONE)
                    views.setViewVisibility(R.id.widget_remaining, View.VISIBLE)
                    views.setTextViewText(
                        R.id.widget_remaining,
                        "⏳ " + remaining(widgetData, diff, kurdishDigits),
                    )
                }
                views.setProgressBar(
                    R.id.widget_progress,
                    100,
                    progress(widgetData, next, now),
                    false,
                )
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.widget_prayer_name, "—")
                views.setTextViewText(R.id.widget_prayer_time, "")
                views.setViewVisibility(R.id.widget_countdown, View.GONE)
                views.setViewVisibility(R.id.widget_remaining, View.VISIBLE)
                views.setTextViewText(R.id.widget_remaining, "")
                views.setViewVisibility(R.id.widget_progress, View.INVISIBLE)
            }

            // کەشوهەوا
            val temp = widgetData.getString("temp", null)
            if (temp.isNullOrBlank()) {
                views.setViewVisibility(R.id.widget_weather_box, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_weather_box, View.VISIBLE)
                views.setTextViewText(R.id.widget_temp, temp)
                setOrHide(views, R.id.widget_emoji, widgetData.getString("emoji", null))
            }

            // دۆلار
            val usd = widgetData.getString("usd_value", null)
            if (usd.isNullOrBlank()) {
                views.setViewVisibility(R.id.widget_usd_box, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_usd_box, View.VISIBLE)
                views.setTextViewText(R.id.widget_usd_value, usd)
                views.setTextViewText(
                    R.id.widget_usd_label,
                    "💵 " + (widgetData.getString("usd_label", "") ?: ""),
                )
            }

            // ڕیزی شەش کاتەکە: تەنها کاتێک ویجێتەکە بەرز بێت
            val showRow = heightDp == 0 || heightDp >= ROW_MIN_HEIGHT_DP
            views.setViewVisibility(
                R.id.widget_prayer_row,
                if (showRow) View.VISIBLE else View.GONE,
            )
            if (showRow) bindRow(views, widgetData, next, kurdishDigits)

            // ویجێتی گەورە = دەقی گەورەتر
            val big = heightDp >= BIG_MIN_HEIGHT_DP
            views.setTextViewTextSize(
                R.id.widget_prayer_name, TypedValue.COMPLEX_UNIT_SP, if (big) 26f else 20f,
            )
            views.setTextViewTextSize(
                R.id.widget_prayer_time, TypedValue.COMPLEX_UNIT_SP, if (big) 40f else 30f,
            )
            views.setTextViewTextSize(
                R.id.widget_countdown, TypedValue.COMPLEX_UNIT_SP, if (big) 14f else 12f,
            )

            // کلیک = کردنەوەی ئەپ
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // دوای گەیشتنی کاتی نوێژەکە ویجێتەکە خۆی نوێ بکاتەوە
        if (next != null) scheduleRefresh(context, appWidgetIds, next.millis + 30_000L)
    }

    /** گۆڕینی قەبارە ← دووبارە کێشانەوە (ڕیزی کاتەکان دەردەکەوێت یان دەشاردرێتەوە) */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    /** ڕەنگی پاشبنەما بەپێی کاتی ڕۆژ (بەپێی نوێژی داهاتوو) */
    private fun background(nextId: String?): Int = when (nextId) {
        "sunrise" -> R.drawable.widget_bg_dawn
        "dhuhr", "asr" -> R.drawable.widget_bg_day
        "maghrib" -> R.drawable.widget_bg_sunset
        "isha" -> R.drawable.widget_bg_dusk
        else -> R.drawable.widget_bg
    }

    private fun bindRow(
        views: RemoteViews,
        data: SharedPreferences,
        next: Slot?,
        kurdish: Boolean,
    ) {
        // دوای عیشا، کاتەکانی سبەینێ پیشان دەدرێن
        val day = next?.day ?: "d0"
        for (cell in CELLS) {
            views.setTextViewText(cell.name, data.getString("name_${cell.id}", "") ?: "")
            views.setTextViewText(
                cell.time,
                digits(data.getString("${day}_${cell.id}", "") ?: "", kurdish),
            )
            val active = next?.id == cell.id
            views.setInt(
                cell.box,
                "setBackgroundResource",
                if (active) R.drawable.widget_chip_active else 0,
            )
            views.setTextColor(cell.name, if (active) DARK else SOFT)
            views.setTextColor(cell.time, if (active) DARK else Color.WHITE)
        }
    }

    /** لە نوێژی پێشووەوە تا داهاتوو چەند لەسەدی تێپەڕیوە */
    private fun progress(data: SharedPreferences, next: Slot, now: Long): Int {
        var prev = 0L
        for (day in listOf("d0", "d1")) {
            val date = data.getString("${day}_date", null) ?: continue
            for (id in IDS) {
                val hm = data.getString("${day}_$id", null) ?: continue
                val millis = toMillis(date, hm) ?: continue
                if (millis <= now && millis > prev) prev = millis
            }
        }
        // پێش بەیانی: نوێژی پێشوو عیشای دوێنێیە (نزیکەی هەمان کاتی ئەمشەو)
        if (prev == 0L) {
            val date = data.getString("d0_date", null)
            val isha = data.getString("d0_isha", null)
            val t = if (date != null && isha != null) toMillis(date, isha) else null
            prev = (t ?: return 0) - 86_400_000L
        }
        val span = next.millis - prev
        if (span <= 0L) return 0
        return (((now - prev) * 100L) / span).toInt().coerceIn(0, 100)
    }

    private fun hhmm(millis: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return "%02d:%02d".format(
            Locale.US,
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE),
        )
    }

    private fun todayKey(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d-%02d".format(
            Locale.US,
            c.get(Calendar.YEAR),
            c.get(Calendar.MONTH) + 1,
            c.get(Calendar.DAY_OF_MONTH),
        )
    }

    private fun setOrHide(views: RemoteViews, viewId: Int, value: String?) {
        if (value.isNullOrBlank()) {
            views.setViewVisibility(viewId, View.GONE)
        } else {
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setTextViewText(viewId, value)
        }
    }

    /** یەکەم نوێژی دوای ئێستا، لە نێوان ئەمڕۆ و بەیانی */
    private fun findNext(data: SharedPreferences, now: Long): Slot? {
        var best: Slot? = null
        for (day in listOf("d0", "d1")) {
            val date = data.getString("${day}_date", null) ?: continue
            for (id in IDS) {
                val hm = data.getString("${day}_$id", null) ?: continue
                val millis = toMillis(date, hm) ?: continue
                if (millis > now && (best == null || millis < best.millis)) {
                    best = Slot(id, millis, day)
                }
            }
        }
        return best
    }

    /** "2026-11-13" + "05:12" بە کاتی ئامێرەکە (عێراق) */
    private fun toMillis(date: String, hm: String): Long? {
        return try {
            val d = date.split("-")
            val t = hm.split(":")
            Calendar.getInstance().apply {
                set(d[0].toInt(), d[1].toInt() - 1, d[2].toInt(), t[0].toInt(), t[1].toInt(), 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        } catch (e: Exception) {
            null
        }
    }

    private fun remaining(data: SharedPreferences, diffMs: Long, kurdish: Boolean): String {
        val totalMin = ((diffMs + 59_999L) / 60_000L).toInt().coerceAtLeast(1)
        val h = totalMin / 60
        val m = totalMin % 60
        return if (h > 0) {
            val tpl = data.getString("tpl_hm", "{0}:{1}") ?: "{0}:{1}"
            digits(tpl.replace("{0}", h.toString()).replace("{1}", m.toString()), kurdish)
        } else {
            val tpl = data.getString("tpl_min", "{0}") ?: "{0}"
            digits(tpl.replace("{0}", m.toString()), kurdish)
        }
    }

    private fun digits(s: String, kurdish: Boolean): String {
        if (!kurdish) return s
        val ku = "٠١٢٣٤٥٦٧٨٩"
        val sb = StringBuilder()
        for (ch in s) sb.append(if (ch in '0'..'9') ku[ch - '0'] else ch)
        return sb.toString()
    }

    /** بێ مۆڵەتی تایبەت (inexact) — لەوانەیە چەند خولەکێک دوا بکەوێت */
    private fun scheduleRefresh(context: Context, ids: IntArray, atMillis: Long) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, KalarWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getBroadcast(context, 7311, intent, flags)
        try {
            alarm.set(AlarmManager.RTC, atMillis, pi)
        } catch (e: SecurityException) {
            // ئەگەر ڕێگەپێدان نەبوو، نوێبوونەوەی ٣٠ خولەکی سیستەم بەکاردێت
        }
    }

    companion object {
        private const val ROW_MIN_HEIGHT_DP = 150
        private const val BIG_MIN_HEIGHT_DP = 230
        private val DARK = Color.parseColor("#0F172A")
        private val SOFT = Color.parseColor("#B3FFFFFF")
        private val IDS = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
        private val CELLS = listOf(
            Cell("fajr", R.id.widget_p_fajr, R.id.widget_p_fajr_name, R.id.widget_p_fajr_time),
            Cell("sunrise", R.id.widget_p_sunrise, R.id.widget_p_sunrise_name, R.id.widget_p_sunrise_time),
            Cell("dhuhr", R.id.widget_p_dhuhr, R.id.widget_p_dhuhr_name, R.id.widget_p_dhuhr_time),
            Cell("asr", R.id.widget_p_asr, R.id.widget_p_asr_name, R.id.widget_p_asr_time),
            Cell("maghrib", R.id.widget_p_maghrib, R.id.widget_p_maghrib_name, R.id.widget_p_maghrib_time),
            Cell("isha", R.id.widget_p_isha, R.id.widget_p_isha_name, R.id.widget_p_isha_time),
        )

        @Suppress("unused")
        fun component(context: Context) = ComponentName(context, KalarWidgetProvider::class.java)
    }
}
