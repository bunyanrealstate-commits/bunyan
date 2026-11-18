package com.bunyan.bunyan

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** بيستقبل كود الربط اللي بنيان القديم بيبعته لوحده (bnyapp://link?c=...) */
class MainActivity : FlutterFragmentActivity() {
    private var link: String? = null
    private var ch: MethodChannel? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        link = intent?.dataString
        ch = MethodChannel(engine.dartExecutor.binaryMessenger, "bny/link")
        ch!!.setMethodCallHandler { call, res ->
            when (call.method) {
                "take" -> { val l = link; link = null; res.success(l) }
                "openOld" -> { val i = packageManager.getLaunchIntentForPackage("com.bunyan.furnished"); if (i != null) { startActivity(i); res.success(true) } else res.success(false) }
                "openUrl" -> { try { startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(call.argument<String>("u")!!)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); res.success(true) } catch (e: Exception) { res.success(false) } }
                "hasOld" -> res.success(packageManager.getLaunchIntentForPackage("com.bunyan.furnished") != null)
                "version" -> res.success(try { val pi = packageManager.getPackageInfo(packageName, 0); if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong() } catch (e: Exception) { 0L })
                "canInstall" -> res.success(if (Build.VERSION.SDK_INT >= 26) packageManager.canRequestPackageInstalls() else true)
                "installPerm" -> { try { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, android.net.Uri.parse("package:$packageName"))); res.success(true) } catch (e: Exception) { res.success(false) } }
                "updStatus" -> { val sp = getSharedPreferences("bny_upd", MODE_PRIVATE); res.success(sp.getString("st", "")) }
                "install" -> { try { install(File(call.argument<String>("path")!!)); res.success(true) } catch (e: Exception) { res.success(false) } }
                else -> res.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val d = intent.dataString
        if (d != null) { link = d; ch?.invokeMethod("ping", null) }
    }

    /** تحديث لوحده: أول مرة أندرويد بيسأل، وبعد كده بيتسطّب من غير ما تعمل حاجة */
    private fun install(f: File) {
        val pi = packageManager.packageInstaller
        val p = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        p.setAppPackageName(packageName)
        if (Build.VERSION.SDK_INT >= 31) p.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        val id = pi.createSession(p)
        pi.openSession(id).use { s ->
            s.openWrite("app.apk", 0, f.length()).use { out -> f.inputStream().use { it.copyTo(out) }; s.fsync(out) }
            val i = Intent(this, UpdRx::class.java)
            val pend = PendingIntent.getBroadcast(this, 77, i, PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
            s.commit(pend.intentSender)
        }
    }
}

class UpdRx : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val st = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)
        ctx.getSharedPreferences("bny_upd", Context.MODE_PRIVATE).edit().putString("st", "$st ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""}").apply()
        if (st == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION") val c = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            if (c != null) { c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); try { ctx.startActivity(c) } catch (_: Exception) {} }
        }
    }
}
