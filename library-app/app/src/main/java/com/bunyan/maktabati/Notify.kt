package com.bunyan.maktabati

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/** تذكير بالليل لو لسه مكملتش هدف اليوم + فقرة من كتابك كل يوم */
object Notify {
    const val CH = "mk_read"

    fun ensure(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CH) == null) nm.createNotificationChannel(NotificationChannel(CH, "تذكير القراية", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    fun read(ctx: Context): JSONObject = try { JSONObject(File(ctx.filesDir, "lib.json").readText()) } catch (_: Exception) { JSONObject() }

    private fun pi(ctx: Context, k: String): PendingIntent =
        PendingIntent.getBroadcast(ctx, k.hashCode(), Intent(ctx, AlarmRx::class.java).putExtra("k", k), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun schedule(ctx: Context) {
        val cfg = read(ctx).optJSONObject("cfg") ?: JSONObject()
        val am = ctx.getSystemService(AlarmManager::class.java)
        for ((k, def) in listOf("eve" to "21:30", "para" to "13:00")) {
            val p = pi(ctx, k); am.cancel(p)
            if (!cfg.optBoolean(k, true)) continue
            val tm = cfg.optString(k + "T", def).split(":")
            val c = Calendar.getInstance()
            c.set(Calendar.HOUR_OF_DAY, tm.getOrNull(0)?.toIntOrNull() ?: 21); c.set(Calendar.MINUTE, tm.getOrNull(1)?.toIntOrNull() ?: 0); c.set(Calendar.SECOND, 0)
            if (c.timeInMillis <= System.currentTimeMillis() + 30000) c.add(Calendar.DAY_OF_MONTH, 1)
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, c.timeInMillis, p)
        }
    }

    fun post(ctx: Context, id: Int, title: String, body: String, open: String?) {
        ensure(ctx)
        val i = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (open != null) i.putExtra("open", open)
        val pi = PendingIntent.getActivity(ctx, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(ctx, CH).setSmallIcon(android.R.drawable.ic_menu_agenda).setContentTitle(title).setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true).setContentIntent(pi).setPriority(NotificationCompat.PRIORITY_HIGH).build()
        try { NotificationManagerCompat.from(ctx).notify(id, n) } catch (_: SecurityException) {}
    }
}

class AlarmRx : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val k = intent.getStringExtra("k") ?: return
        val j = Notify.read(ctx)
        val books = j.optJSONArray("books")
        val goal = j.optInt("goal", 10)
        val today = Lib.ds(java.util.Date())
        var pages = 0; var cur: JSONObject? = null
        if (books != null) for (i in 0 until books.length()) {
            val b = books.getJSONObject(i)
            val log = b.optJSONArray("log"); if (log != null) for (x in 0 until log.length()) { val l = log.getJSONObject(x); if (l.optString("d") == today) pages += l.optInt("p") }
            if (b.optString("sh") == "now" && (cur == null || b.optLong("rd") > cur.optLong("rd"))) cur = b
        }
        if (k == "eve" && pages < goal && cur != null) {
            val left = goal - pages
            Notify.post(ctx, 9201, "📖 " + cur.optString("t"),
                if (pages > 0) "فاضلك $left صفحات بس علشان تخلّص هدف النهارده 💪" else "لسه مقرتش النهارده — ولو 5 صفحات علشان الشمعة متطفيش 🔥", cur.optString("id"))
        }
        if (k == "para" && cur != null) {
            val nx = cur.optJSONObject("nx")
            if (nx != null && nx.optString("t").length > 30) Notify.post(ctx, 9202, "⚡ 5 دقايق من «${cur.optString("t")}»", nx.optString("t") + "…\n\nدوس وكمّل من صفحة " + nx.optInt("p"), cur.optString("id"))
            else Notify.post(ctx, 9202, "⚡ 5 دقايق بس؟", "كمّل «${cur.optString("t")}» من صفحة ${cur.optInt("cur", 1)} — 5 دقايق بس 📖", cur.optString("id"))
        }
        Notify.schedule(ctx)
    }
}

class BootRx : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) { Notify.schedule(ctx) }
}
