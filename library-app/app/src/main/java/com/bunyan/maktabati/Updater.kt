package com.bunyan.maktabati

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** تحديث تلقائي: بيشوف لو فيه نسخة أجدد على GitHub وينزّلها ويسطّبها لوحده.
 *  أول مرة بس أندرويد بيطلب موافقة، وبعد كده التحديثات بتتسطّب من غير ما تعمل حاجة (أندرويد 12+). */
object Updater {
    private const val BASE = "https://raw.githubusercontent.com/bunyanrealstate-commits/bunyan/apk-library/"

    fun myVersion(ctx: Context): Long = try {
        val pi = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong()
    } catch (_: Exception) { 0 }

    private fun get(u: String): HttpURLConnection {
        val c = URL(u + (if (u.contains("?")) "&" else "?") + "t=" + System.currentTimeMillis()).openConnection() as HttpURLConnection
        c.connectTimeout = 20000; c.readTimeout = 120000; c.setRequestProperty("Cache-Control", "no-cache"); return c
    }

    /** بيرجع رسالة لو حصل تحديث، أو null */
    suspend fun check(ctx: Context, force: Boolean = false): String? = withContext(Dispatchers.IO) {
        val sp = ctx.getSharedPreferences("upd", Context.MODE_PRIVATE)
        if (!force && System.currentTimeMillis() - sp.getLong("at", 0) < 30 * 60 * 1000) return@withContext null
        sp.edit().putLong("at", System.currentTimeMillis()).apply()
        try {
            val v = JSONObject(get(BASE + "version.json").inputStream.bufferedReader().readText())
            val code = v.optLong("code")
            if (code <= myVersion(ctx)) return@withContext if (force) "✅ عندك آخر نسخة" else null
            if (sp.getLong("tried", 0) == code && !force && System.currentTimeMillis() - sp.getLong("triedAt", 0) < 6 * 3600 * 1000) return@withContext null
            sp.edit().putLong("tried", code).putLong("triedAt", System.currentTimeMillis()).apply()
            val f = File(ctx.cacheDir, "upd.apk")
            get(BASE + "Maktabati.apk").inputStream.use { i -> f.outputStream().use { i.copyTo(it, 256 * 1024) } }
            install(ctx, f)
            "⬆️ بنزّل نسخة جديدة من التطبيق…"
        } catch (e: Exception) { if (force) "⚠️ مقدرتش أشوف التحديث — اتأكد من النت" else null }
    }

    private fun install(ctx: Context, f: File) {
        val pi = ctx.packageManager.packageInstaller
        val p = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        p.setAppPackageName(ctx.packageName)
        if (Build.VERSION.SDK_INT >= 31) p.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        if (Build.VERSION.SDK_INT >= 34) try { p.setRequestUpdateOwnership(true) } catch (_: Throwable) {}
        val id = pi.createSession(p)
        pi.openSession(id).use { s ->
            s.openWrite("app.apk", 0, f.length()).use { out -> f.inputStream().use { it.copyTo(out) }; s.fsync(out) }
            val i = Intent(ctx, UpdRx::class.java)
            val pend = PendingIntent.getBroadcast(ctx, 77, i, PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
            s.commit(pend.intentSender)
        }
    }
}

class UpdRx : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION") val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm != null) { confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); try { ctx.startActivity(confirm) } catch (_: Exception) {} }
            }
            else -> {}
        }
    }
}
