package com.bunyan.maktabati

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.widget.Toast
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File

/** التحميل بيكمّل في الخلفية حتى لو قفلت التطبيق، ومعاه إشعار بالنسبة */
object Dl {
    val prog = mutableStateMapOf<String, Float>()
    var done by mutableStateOf<String?>(null)        // آخر كتاب خلص تحميله
    var quiet = HashSet<String>()                    // تحميل في السكوت (الكتاب الجاي على الواي فاي)

    fun fetch(ctx: Context, b: JSONObject, silent: Boolean = false) {
        val id = b.optString("id")
        if (prog.containsKey(id) || Lib.have(b)) { if (Lib.have(b)) done = id; return }
        prog[id] = 0f
        if (silent) quiet.add(id) else quiet.remove(id)
        val app = ctx.applicationContext
        try { val i = Intent(app, DownloadService::class.java); if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(i) else app.startService(i) } catch (_: Exception) {}
        fun toast(s: String) { if (!silent) Toast.makeText(app, s, Toast.LENGTH_LONG).show() }
        Lib.bg.launch {
            try {
                if (b.optString("ia").isEmpty()) {
                    toast("🔎 بدوّر على «${b.optString("t")}» في أرشيف الإنترنت…")
                    if (!Net.findIA(b)) { prog.remove(id); toast("ملقتش «${b.optString("t")}» على الأرشيف — نزّله بـ «🔎 نزّل كتاب» أو «📄 من موبايلي»"); return@launch }
                    Lib.touch(b, "ia", "iaf", "iaff", "iav"); Lib.save()
                }
                val parts = Net.parts(b)
                if (parts.isEmpty()) throw Exception("مفيش PDF")
                val pr = FloatArray(parts.size)
                coroutineScope {
                    parts.mapIndexed { i, f ->
                        async {
                            val to = File(Lib.dir, "books/" + (if (i == 0) "$id.pdf" else "$id#part${i + 1}.pdf"))
                            if (!to.exists()) Net.download(Net.iaUrl(b.optString("ia"), f), to) { got, tot ->
                                pr[i] = if (tot > 0) (got.toFloat() / tot).coerceIn(0f, 1f) else 0f
                                prog[id] = (pr.sum() / parts.size).coerceIn(0f, 0.999f)
                            } else pr[i] = 1f
                        }
                    }.awaitAll()
                }
                cover(b); Lib.save(); prog.remove(id); done = id
                if (silent) Notify.post(app, 9301, "📚 الكتاب الجاي جاهز", "«${b.optString("t")}» اتنزّل ومستنيك لما تخلّص اللي في إيدك", null)
            } catch (e: Exception) { prog.remove(id); toast("⚠️ التحميل وقف — جرّب تاني (${e.message?.take(30)})") }
            finally { quiet.remove(id) }
        }
    }

    fun unmetered(ctx: Context): Boolean = try {
        val cm = ctx.getSystemService(ConnectivityManager::class.java)
        val c = cm.getNetworkCapabilities(cm.activeNetwork)
        c != null && c.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) && c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    } catch (_: Exception) { false }

    /** الكتاب الجاي في الطابور يتنزّل لوحده على الواي فاي */
    fun prefetchNext(ctx: Context) {
        if (!Lib.cfg.optBoolean("prefetch", true) || !unmetered(ctx) || prog.isNotEmpty()) return
        val now = Lib.books.filter { it.optString("sh") == "now" }
        val next = (Lib.queue.mapNotNull { Lib.book(it) } + Lib.books).firstOrNull { it.optString("sh", "want") == "want" && !Lib.have(it) }
        val first = now.firstOrNull { !Lib.have(it) } ?: next ?: return
        fetch(ctx, first, silent = true)
    }
}

class DownloadService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    override fun onBind(i: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        post()
        scope.coroutineContext.cancelChildren()
        scope.launch {
            delay(800)
            while (Dl.prog.isNotEmpty()) { post(); delay(1000) }
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
            stopSelf()
        }
        return START_NOT_STICKY
    }
    private fun post() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel("mk_dl") == null) nm.createNotificationChannel(NotificationChannel("mk_dl", "تحميل الكتب", NotificationManager.IMPORTANCE_LOW))
        val ids = Dl.prog.keys.toList()
        val names = ids.mapNotNull { Lib.book(it)?.optString("t") }
        val p = if (ids.isEmpty()) 100 else (Dl.prog.values.sum() / ids.size * 100).toInt()
        val open = PendingIntent.getActivity(this, 601, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_IMMUTABLE)
        val n = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "mk_dl") else @Suppress("DEPRECATION") Notification.Builder(this))
            .setSmallIcon(android.R.drawable.stat_sys_download).setContentTitle("⬇️ بنزّل " + (names.firstOrNull()?.let { "«$it»" } ?: "كتاب") + (if (names.size > 1) " و${names.size - 1} كمان" else ""))
            .setContentText("$p%").setProgress(100, p, ids.isEmpty()).setOngoing(true).setContentIntent(open).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(78, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else startForeground(78, n)
    }
    override fun onDestroy() { scope.cancel(); super.onDestroy() }
}
