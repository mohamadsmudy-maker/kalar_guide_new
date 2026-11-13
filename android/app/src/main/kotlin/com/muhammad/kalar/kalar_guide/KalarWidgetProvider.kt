package com.muhammad.kalar.kalar_guide

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * ویجێتی سەر شاشە: نوێژی داهاتوو + پلەی گەرما + نرخی دۆلار.
 * داتاکە لە Dart (HomeWidgetService) دەنێردرێت؛ «نوێژی داهاتوو» لێرە هەژمار
 * دەکرێت، بۆیە بێ ئینتەرنێت و بێ کردنەوەی ئەپ دروستە.
 */
class KalarWidgetProvider : HomeWidgetProvider() {

    private data class Slot(val id: String, val millis: Long)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val next = findNext(widgetData, now)
        val kurdishDigits = widgetData.getString("digits", "0") == "1"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kalar_widget)

            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("title", "ڕێبەری کەلار"),
            )
            views.setTextViewText(
                R.id.widget_next_label,
                widgetData.getString("next_label", ""),
            )

            if (next != null) {
                val name = widgetData.getString("name_${next.id}", "") ?: ""
                val cal = Calendar.getInstance().apply { timeInMillis = next.millis }
                val hhmm = "%02d:%02d".format(
                    cal.get(Calendar.HOUR_OF_DAY),
                    cal.get(Calendar.MINUTE),
                )
                views.setTextViewText(R.id.widget_prayer_name, name)
                views.setTextViewText(R.id.widget_prayer_time, digits(hhmm, kurdishDigits))
                views.setTextViewText(
                    R.id.widget_remaining,
                    remaining(widgetData, next.millis - now, kurdishDigits),
                )
            } else {
                views.setTextViewText(R.id.widget_prayer_name, "—")
                views.setTextViewText(R.id.widget_prayer_time, "")
                views.setTextViewText(R.id.widget_remaining, "")
            }

            setOrHide(views, R.id.widget_emoji, widgetData.getString("emoji", null))
            setOrHide(views, R.id.widget_temp, widgetData.getString("temp", null))
            setOrHide(views, R.id.widget_usd_label, widgetData.getString("usd_label", null))
            setOrHide(views, R.id.widget_usd_value, widgetData.getString("usd_value", null))
            views.setTextViewText(
                R.id.widget_updated,
                widgetData.getString("updated", "") ?: "",
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
        val ids = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
        var best: Slot? = null
        for (day in listOf("d0", "d1")) {
            val date = data.getString("${day}_date", null) ?: continue
            for (id in ids) {
                val hm = data.getString("${day}_$id", null) ?: continue
                val millis = toMillis(date, hm) ?: continue
                if (millis > now && (best == null || millis < best.millis)) {
                    best = Slot(id, millis)
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
        @Suppress("unused")
        fun component(context: Context) = ComponentName(context, KalarWidgetProvider::class.java)
    }
}
