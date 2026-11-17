package com.bunyan.offers

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var link: String? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        link = intent?.dataString
        MethodChannel(engine.dartExecutor.binaryMessenger, "offers/native").setMethodCallHandler { call, res ->
            when (call.method) {
                "take" -> { val l = link; link = null; res.success(l) }
                "version" -> res.success(try { val pi = packageManager.getPackageInfo(packageName, 0); if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong() } catch (e: Exception) { 0L })
                "canInstall" -> res.success(if (Build.VERSION.SDK_INT >= 26) packageManager.canRequestPackageInstalls() else true)
                "installPerm" -> { try { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))); res.success(true) } catch (e: Exception) { res.success(false) } }
                "install" -> { try { install(File(call.argument<String>("path")!!)); res.success(true) } catch (e: Exception) { res.success(false) } }
                "contacts" -> contacts(res)
                "autoCfg" -> { Auto.put(this, "cfg", org.json.JSONObject().put("key", call.argument<String>("key") ?: "").put("prompt", call.argument<String>("prompt") ?: "").put("groups", org.json.JSONArray(call.argument<List<String>>("groups") ?: listOf<String>()))); res.success(true) }
                "autoRun" -> Thread { val n = Auto.run(applicationContext); runOnUiThread { res.success(n) } }.start()
                "autoTake" -> { val r = Auto.arr(this, "res").toString(); Auto.put(this, "res", "[]"); res.success(r) }
                "autoSeen" -> res.success(Auto.mergeSeen(this).toString())
                "notifOn" -> res.success((android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: "").contains(packageName))
                "notifPerm" -> res.success(notifPerm())
                "appInfo" -> { try { startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))); res.success(true) } catch (e: Exception) { res.success(false) } }
                "perms" -> { val l = ArrayList<String>(); if (Build.VERSION.SDK_INT >= 33) { l.add("android.permission.POST_NOTIFICATIONS"); l.add("android.permission.READ_MEDIA_IMAGES") } else l.add(android.Manifest.permission.READ_EXTERNAL_STORAGE)
                    val need = l.filter { checkSelfPermission(it) != android.content.pm.PackageManager.PERMISSION_GRANTED }; if (need.isNotEmpty() && Build.VERSION.SDK_INT >= 23) requestPermissions(need.toTypedArray(), 56); res.success(need.isEmpty()) }
                "wa" -> res.success(wa(call.argument<String>("phone") ?: "", call.argument<String>("text") ?: "", call.argument<List<String>>("uris") ?: listOf()))
                else -> res.notImplemented()
            }
        }
    }
    /** يفتح صفحة السماح بالإشعارات — بيجرب أكتر من طريقة علشان أجهزة هونر/هواوي */
    private fun notifPerm(): String {
        val cn = android.content.ComponentName(this, WaListener::class.java).flattenToString()
        val tries = ArrayList<Intent>()
        if (Build.VERSION.SDK_INT >= 30) tries.add(Intent("android.settings.NOTIFICATION_LISTENER_DETAIL_SETTINGS").putExtra("android.provider.extra.NOTIFICATION_LISTENER_COMPONENT_NAME", cn))
        tries.add(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
        tries.add(Intent("android.settings.NOTIFICATION_LISTENER_SETTINGS"))
        tries.add(Intent().setClassName("com.android.settings", "com.android.settings.Settings\$NotificationAccessSettingsActivity"))
        tries.add(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        for ((i, t) in tries.withIndex()) {
            try { t.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(t); return if (i == tries.size - 1) "app" else "ok" } catch (_: Exception) {}
        }
        return "fail"
    }

    private var pend: MethodChannel.Result? = null
    private fun contacts(res: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            pend = res; requestPermissions(arrayOf(android.Manifest.permission.READ_CONTACTS), 55); return
        }
        Thread { val l = readContacts(); runOnUiThread { res.success(l) } }.start()
    }
    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, perms, grants)
        if (code != 55) return
        val r = pend ?: return; pend = null
        if (grants.isNotEmpty() && grants[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) Thread { val l = readContacts(); runOnUiThread { r.success(l) } }.start() else r.success(listOf<Map<String, String>>())
    }
    /** جهات الاتصال: اللي عندها واتساب (عادي أو بيزنس) الأول، وبعدين باقي الأرقام */
    private fun readContacts(): List<Map<String, String>> {
        val out = ArrayList<Map<String, String>>()
        try {
            contentResolver.query(android.provider.ContactsContract.Data.CONTENT_URI, arrayOf(android.provider.ContactsContract.Data.DISPLAY_NAME, android.provider.ContactsContract.Data.DATA1),
                android.provider.ContactsContract.Data.MIMETYPE + " IN (?,?)", arrayOf("vnd.android.cursor.item/vnd.com.whatsapp.profile", "vnd.android.cursor.item/vnd.com.whatsapp.w4b.profile"), null)?.use { c ->
                while (c.moveToNext()) { val n = c.getString(0) ?: ""; val j = (c.getString(1) ?: "").substringBefore("@"); if (j.isNotEmpty()) out.add(mapOf("n" to n, "p" to j, "wa" to "1")) }
            }
        } catch (_: Exception) {}
        try {
            contentResolver.query(android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI, arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { c ->
                while (c.moveToNext()) { val n = c.getString(0) ?: ""; val p = c.getString(1) ?: ""; if (p.isNotEmpty()) out.add(mapOf("n" to n, "p" to p, "wa" to "")) }
            }
        } catch (_: Exception) {}
        return out
    }

    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); if (intent.dataString != null) link = intent.dataString }

    private fun has(p: String) = try { packageManager.getPackageInfo(p, 0); true } catch (e: Exception) { false }

    /** واتساب بيزنس أو العادي: يفتح شات الرقم ومعاه الفيديوهات + الرسالة */
    private fun wa(phone: String, text: String, uris: List<String>): String {
        val pkg = if (has("com.whatsapp.w4b")) "com.whatsapp.w4b" else if (has("com.whatsapp")) "com.whatsapp" else null
        val list = ArrayList(uris.map { Uri.parse(it) })
        val i: Intent
        if (list.isEmpty()) {
            i = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }
        } else if (list.size == 1) {
            i = Intent(Intent.ACTION_SEND).apply { type = "video/*"; putExtra(Intent.EXTRA_STREAM, list[0]) }
        } else {
            i = Intent(Intent.ACTION_SEND_MULTIPLE).apply { type = "video/*"; putParcelableArrayListExtra(Intent.EXTRA_STREAM, list) }
        }
        i.putExtra(Intent.EXTRA_TEXT, text)
        if (phone.isNotEmpty()) i.putExtra("jid", "$phone@s.whatsapp.net")
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            if (pkg != null) { i.setPackage(pkg); startActivity(i); "wa" } else { startActivity(Intent.createChooser(i, "ابعت للعميل")); "share" }
        } catch (e: Exception) { try { i.setPackage(null); startActivity(Intent.createChooser(i, "ابعت للعميل")); "share" } catch (e2: Exception) { "fail" } }
    }

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
        if (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999) == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION") val c = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            if (c != null) { c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); try { ctx.startActivity(c) } catch (_: Exception) {} }
        }
    }
}
