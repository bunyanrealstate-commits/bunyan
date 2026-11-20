package com.bunyan.maktabati

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject

/** 🔎 البحث في «اكتشف» شغال في الخلفية — حتى لو قفلت التطبيق، ولما يخلص يبعتلك إشعار */
object Explore {
    var busy by mutableStateOf(false)
    var err by mutableStateOf("")
    fun state(): JSONObject = Lib.cfg.optJSONObject("exp") ?: JSONObject().also { Lib.cfg.put("exp", it) }
    fun results(): List<JSONObject> = state().optJSONArray("r")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it) } } ?: emptyList()

    fun start(ctx: Context, genres: List<String>, text: String, more: Boolean) {
        if (busy) return
        val i = Intent(ctx, ExploreService::class.java).putExtra("g", JSONArray(genres).toString()).putExtra("q", text).putExtra("more", more)
        if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
    }

    suspend fun run(genres: List<String>, text: String, more: Boolean): Int {
        val st = state()
        val old = if (more) results() else emptyList()
        val have = (Lib.books.map { it.optString("t") } + old.map { it.optString("t") }).filter { it.isNotBlank() }.take(150)
        val topic = buildList { addAll(genres.map { it.substringAfter(' ') }); if (text.isNotBlank()) add("«${text.trim()}»") }.joinToString(" + ")
        val flt = Lib.cfg.optString("expF", "islamic")
        val cond = when (flt) {
            "islamic" -> " شرط أساسي: كل الكتب لازم تكون من تأليف مؤلفين عرب أو مسلمين (علماء ودعاة ومفكرين ومؤلفين عرب) ومن منظور إسلامي، وممكن كتب تراث، وممنوع أي كتاب مترجم من مؤلف أجنبي غير مسلم."
            "arabic" -> " شرط أساسي: كل الكتب لازم تكون من تأليف مؤلفين عرب (مكتوبة بالعربي أصلاً)، وممنوع أي كتاب مترجم."
            else -> ""
        }
        val j = Net.askJson("زي قوائم Goodreads الأعلى تقييماً: رشّح 15 كتاب حقيقي ومشهور ومتقيّم عالي في: $topic." + cond +
            (if (genres.size + (if (text.isNotBlank()) 1 else 0) > 1) " (نوّع بينهم، ولو فيه كتب بتجمع أكتر من حاجة منهم قدّمها)" else "") +
            (if (flt == "all") " يفضّل عربي أو مترجم للعربي ومتاح،" else "") + " الأسهل الأول لواحد لسه بيتعوّد على القراية، ومتألّفش أي كتاب مش موجود." +
            (if (have.isNotEmpty()) " متكررش أي كتاب من دول: " + have.joinToString("، ") else "") +
            " رجّع JSON بس: {\"r\":[{\"t\":\"اسم الكتاب بالعربي\",\"a\":\"المؤلف\",\"pg\":عدد الصفحات التقريبي,\"cat\":\"التصنيف\",\"why\":\"بيتكلم عن إيه — سطر بالمصري\"}]}")
            ?: return -1
        val got = j.optJSONArray("r")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it) } } ?: emptyList()
        val seen = old.map { it.optString("t") }.toHashSet()
        val fresh = got.filter { it.optString("t").isNotBlank() && seen.add(it.optString("t")) }
        withContext(Dispatchers.Main) {
            st.put("g", JSONArray(genres)).put("q", text).put("at", System.currentTimeMillis()).put("r", JSONArray(old + fresh))
            Lib.save(); Lib.ver++
        }
        return fresh.size
    }
}

class ExploreService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    override fun onBind(i: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Lib.isInit()) Lib.init(applicationContext)
        chan()
        val n = build("🔎 بدوّر على كتب ليك…", "تقدر تقفل التطبيق — هبعتلك لما أخلص", true)
        if (Build.VERSION.SDK_INT >= 29) startForeground(79, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else startForeground(79, n)
        val g = try { JSONArray(intent?.getStringExtra("g") ?: "[]").let { a -> (0 until a.length()).map { a.getString(it) } } } catch (_: Exception) { emptyList() }
        val q = intent?.getStringExtra("q") ?: ""
        val more = intent?.getBooleanExtra("more", false) ?: false
        scope.launch {
            withContext(Dispatchers.Main) { Explore.busy = true; Explore.err = "" }
            var got = -1
            for (attempt in 1..3) { got = try { Explore.run(g, q, more) } catch (_: Exception) { -1 }; if (got >= 0) break; delay(4000L * attempt) }
            withContext(Dispatchers.Main) { Explore.busy = false; Explore.err = if (got < 0) "⚠️ مقدرتش أجيب نتايج — اتأكد من النت وجرّب تاني" else "" }
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
            getSystemService(NotificationManager::class.java).notify(80,
                if (got >= 0) build("✅ خلصت البحث", "لقيتلك $got كتاب — دوس تشوفهم", false) else build("⚠️ البحث موقف", "مقدرتش أوصل للنت — جرّب تاني", false))
            stopSelf()
        }
        return START_NOT_STICKY
    }
    private fun chan() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel("mk_exp") == null) nm.createNotificationChannel(NotificationChannel("mk_exp", "البحث عن كتب", NotificationManager.IMPORTANCE_DEFAULT))
    }
    private fun build(t: String, b: String, ongoing: Boolean): Notification {
        val open = PendingIntent.getActivity(this, 602, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("open", "explore"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "mk_exp") else @Suppress("DEPRECATION") Notification.Builder(this))
            .setSmallIcon(android.R.drawable.ic_menu_search).setContentTitle(t).setContentText(b).setOngoing(ongoing).setAutoCancel(!ongoing)
            .apply { if (ongoing) setProgress(0, 0, true) }.setContentIntent(open).build()
    }
    override fun onDestroy() { scope.cancel(); super.onDestroy() }
}
