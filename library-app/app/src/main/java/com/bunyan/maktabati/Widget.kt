package com.bunyan.maktabati

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** ويدجت الشاشة الرئيسية: الكتاب اللي بتقراه + الشمعة + كمّل القراية */
class ReadWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) { if (!Lib.isInit()) Lib.init(ctx.applicationContext); draw(ctx, m, ids) }

    companion object {
        private var last = 0L
        fun refresh(ctx: Context) {
            val now = System.currentTimeMillis(); if (now - last < 3000) return; last = now
            val m = AppWidgetManager.getInstance(ctx)
            val ids = m.getAppWidgetIds(ComponentName(ctx, ReadWidget::class.java))
            if (ids.isNotEmpty()) draw(ctx, m, ids)
        }
        fun draw(ctx: Context, m: AppWidgetManager, ids: IntArray) {
            val b = Lib.current()
            val v = RemoteViews(ctx.packageName, R.layout.widget)
            val st = Lib.streak(); val today = Lib.todayPages(); val goal = Lib.goal
            v.setTextViewText(R.id.w_streak, (if (st > 0) "🔥 " else "🕯 ") + st)
            if (b != null) {
                val pg = b.optInt("pg"); val c = b.optInt("cur")
                v.setTextViewText(R.id.w_kicker, if (b.optString("sh") == "now") "📖 بتقرأ دلوقتي" else "📌 الكتاب الجاي")
                v.setTextViewText(R.id.w_title, b.optString("t"))
                v.setProgressBar(R.id.w_prog, 100, if (pg > 0) c * 100 / pg else 0, false)
                v.setTextViewText(R.id.w_sub, (if (pg > 0) "صفحة $c من $pg • " else "") + if (today >= goal) "🎉 خلّصت هدف النهارده" else "النهارده $today من $goal صفحات")
                v.setTextViewText(R.id.w_btn, if (c > 1) "📖 كمّل من صفحة $c" else "📖 ابدأ القراية")
            }
            val i = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (b != null) i.putExtra("open", b.optString("id"))
            val pi = PendingIntent.getActivity(ctx, 701, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            v.setOnClickPendingIntent(R.id.w_root, pi); v.setOnClickPendingIntent(R.id.w_btn, pi)
            m.updateAppWidget(ids, v)
        }
    }
}
