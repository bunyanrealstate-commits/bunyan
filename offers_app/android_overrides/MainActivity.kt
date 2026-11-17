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
    private var go: String? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        link = intent?.dataString
        go = intent?.getStringExtra("go")
        MethodChannel(engine.dartExecutor.binaryMessenger, "offers/native").setMethodCallHandler { call, res ->
            when (call.method) {
                "take" -> { val l = link; link = null; res.success(l) }
                "go" -> { val g = go; go = null; res.success(g) }
                "shareIg" -> { try {
                        val i = Intent(Intent.ACTION_SEND).apply { type = "video/*"; putExtra(Intent.EXTRA_STREAM, Uri.parse(call.argument<String>("uri") ?: "")); putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: ""); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK) }
                        if (has("com.instagram.android")) { i.setPackage("com.instagram.android"); startActivity(i); res.success("ig") } else { startActivity(Intent.createChooser(i, "انشر")); res.success("share") }
                    } catch (e: Exception) { res.success("fail") } }
                "findImg" -> { val b = call.argument<ByteArray>("bytes") ?: ByteArray(0); Thread { val r = try { Auto.findImg(applicationContext, b).toString() } catch (e: Exception) { "[]" }; runOnUiThread { res.success(r) } }.start() }
                "allFiles" -> res.success(Auto.allFiles())
                "needFiles" -> res.success(Auto.prefs(this).getString("needFiles", "") == "1" && !Auto.allFiles())
                "allFilesPerm" -> { try { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))) } catch (e: Exception) { try { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)) } catch (_: Exception) {} }; res.success(true) }
                "locTake" -> { val r = Auto.arr(this, "locs").toString(); Auto.put(this, "locs", "[]"); res.success(r) }
                "dmTake" -> { val r = Auto.arr(this, "dm").toString(); Auto.put(this, "dm", "[]"); res.success(r) }
                "dmOn" -> { val cf = Auto.cfg(this); cf.put("dm", call.argument<Boolean>("on") ?: false); Auto.put(this, "cfg", cf); res.success(true) }
                "sum" -> { Auto.put(this, "sum", call.argument<String>("json") ?: "{}"); Auto.scheduleMorning(applicationContext); res.success(true) }
                "alarm" -> { Auto.alarm(applicationContext, call.argument<Int>("id") ?: 0, (call.argument<Number>("at") ?: 0).toLong(), call.argument<String>("title") ?: "", call.argument<String>("text") ?: "", "view"); res.success(true) }
                "note" -> { Auto.note(applicationContext, call.argument<Int>("id") ?: 1, "req", call.argument<String>("title") ?: "", call.argument<String>("text") ?: "", call.argument<String>("go") ?: "reqs"); res.success(true) }
                "openChat" -> res.success(wa(call.argument<String>("phone") ?: "", call.argument<String>("text") ?: "", listOf()))
                "version" -> res.success(try { val pi = packageManager.getPackageInfo(packageName, 0); if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong() } catch (e: Exception) { 0L })
                "canInstall" -> res.success(if (Build.VERSION.SDK_INT >= 26) packageManager.canRequestPackageInstalls() else true)
                "installPerm" -> { try { startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))); res.success(true) } catch (e: Exception) { res.success(false) } }
                "install" -> { try { Auto.install(this, File(call.argument<String>("path")!!)); res.success(true) } catch (e: Exception) { res.success(false) } }
                "upd" -> Thread { val r = Auto.upd(applicationContext); runOnUiThread { res.success(r) } }.start()
                "contacts" -> contacts(res)
                "autoCfg" -> { Auto.put(this, "cfg", org.json.JSONObject().put("dm", call.argument<Boolean>("dm") ?: false).put("key", call.argument<String>("key") ?: "").put("prompt", call.argument<String>("prompt") ?: "").put("groups", org.json.JSONArray(call.argument<List<String>>("groups") ?: listOf<String>())).put("all", call.argument<Boolean>("all") ?: false).put("off", org.json.JSONArray(call.argument<List<String>>("off") ?: listOf<String>()))); res.success(true) }
                "autoRun" -> Thread { val n = Auto.run(applicationContext); runOnUiThread { res.success(n) } }.start()
                "autoToday" -> Thread { val n = Auto.run(applicationContext, true); runOnUiThread { res.success(n) } }.start()
                "autoProg" -> res.success(Auto.prog)
                "ocr" -> { val b = call.argument<ByteArray>("bytes") ?: ByteArray(0); Thread { val r = Auto.ocrEls(b)?.toString(); runOnUiThread { res.success(r) } }.start() }
                "play" -> { try { startActivity(Intent(Intent.ACTION_VIEW).apply { setDataAndType(Uri.parse(call.argument<String>("uri") ?: ""), "video/*"); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK) }); res.success(true) } catch (e: Exception) { res.success(false) } }
                "autoDbg" -> res.success(Auto.arr(this, "dbg").toString())
                "forget" -> { val h = Auto.obj(this, "hash"); val d = Auto.arr(this, "dbg"); Auto.put(this, "hash", "{}"); Auto.put(this, "done", "[]"); Auto.put(this, "doneF", "[]"); Auto.put(this, "sig", "{}"); res.success(h.length() + d.length()) }
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
            contentResolver.query(android.provider.ContactsContract.Data.CONTENT_URI, arrayOf(android.provider.ContactsContract.Data.DISPLAY_NAME, android.provider.ContactsContract.Data.DATA1, "contact_last_updated_timestamp"),
                android.provider.ContactsContract.Data.MIMETYPE + " IN (?,?)", arrayOf("vnd.android.cursor.item/vnd.com.whatsapp.profile", "vnd.android.cursor.item/vnd.com.whatsapp.w4b.profile"), null)?.use { c ->
                while (c.moveToNext()) { val n = c.getString(0) ?: ""; val j = (c.getString(1) ?: "").substringBefore("@"); if (j.isNotEmpty()) out.add(mapOf("n" to n, "p" to j, "wa" to "1", "u" to (try { c.getLong(2).toString() } catch (_: Exception) { "" }))) }
            }
        } catch (_: Exception) {}
        try {
            contentResolver.query(android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI, arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER, "contact_last_updated_timestamp"), null, null, null)?.use { c ->
                while (c.moveToNext()) { val n = c.getString(0) ?: ""; val p = c.getString(1) ?: ""; if (p.isNotEmpty()) out.add(mapOf("n" to n, "p" to p, "wa" to "", "u" to (try { c.getLong(2).toString() } catch (_: Exception) { "" }))) }
            }
        } catch (_: Exception) {}
        return out
    }

    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); if (intent.dataString != null) link = intent.dataString; intent.getStringExtra("go")?.let { go = it } }

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

}

class UpdRx : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999) == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION") val c = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            if (c != null) { Auto.askNotify(ctx, Intent(c)); c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); try { ctx.startActivity(c) } catch (_: Exception) {} }
        }
    }
}
