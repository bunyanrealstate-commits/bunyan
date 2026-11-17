package com.bunyan.offers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * أبديت الجروبات التلقائي:
 * 1) بيسمع إشعارات الواتساب → يعرف إن جروب شركة (من اللي اختارتهم) بعت صورة وإمتى
 * 2) بعد دقيقة يدوّر في «WhatsApp Images» على الصورة اللي نزلت في نفس الوقت
 * 3) يبعتها لـ Gemini يقرا الشقق والأسعار، ويحفظ النتيجة → التطبيق يطبقها على الفيلا لما يتفتح
 * صور الجروبات اللي مش مختارة والشاتات العادية مبتتبعتش لأي حتة.
 */
class WaListener : NotificationListenerService() {
    /** أول ما يتوصل: يقرا الإشعارات اللي موجودة دلوقتي علشان الجروبات تظهر علطول */
    override fun onListenerConnected() {
        super.onListenerConnected()
        try { activeNotifications?.forEach { onNotificationPosted(it) } } catch (_: Exception) {}
        Auto.updSoon(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != "com.whatsapp" && sbn.packageName != "com.whatsapp.w4b") return
        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val ex = n.extras ?: return
        val isGroup = ex.getBoolean("android.isGroupConversation", false)
        var g = ex.getCharSequence("android.conversationTitle")?.toString()
        if (g == null && !isGroup) { Auto.dm(this, sbn, ex); Auto.updSoon(applicationContext); return }
        if (g == null) g = ex.getCharSequence("android.title")?.toString() ?: return
        g = Auto.clean(g)
        if (g.isEmpty()) return
        val msgs = ArrayList<Pair<String, Long>>()
        try {
            ex.getParcelableArray("android.messages")?.forEach { b -> if (b is android.os.Bundle) msgs.add(Pair(b.getCharSequence("text")?.toString() ?: "", b.getLong("time"))) }
        } catch (_: Exception) {}
        if (msgs.isEmpty()) msgs.add(Pair(ex.getCharSequence("android.text")?.toString() ?: "", sbn.postTime))
        Auto.seen(this, g, msgs)
        Auto.updSoon(applicationContext)
    }
}

object Auto {
    private val h = Handler(Looper.getMainLooper())
    private var busy = false
    fun prefs(c: Context) = c.getSharedPreferences("auto", Context.MODE_PRIVATE)
    /** اسم الجروب من غير «(رسالتان)» / «(3 messages)» وعلامات الاتجاه والمسافات الزيادة — علشان الجروب ميتكررش */
    private val cnt = Regex("\\s*[(（][^()（）]*(\\d|[٠-٩]|رسال|message|new|جديد)[^()（）]*[)）]\\s*$", RegexOption.IGNORE_CASE)
    fun clean(s: String): String {
        var t = s.replace(Regex("[\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]"), "")
        while (cnt.containsMatchIn(t)) t = t.replace(cnt, "")
        return t.replace(Regex("\\s+"), " ").trim()
    }
    /** يدمج الأسماء المكررة اللي اتسجلت قبل التصليح */
    fun mergeSeen(c: Context): JSONObject {
        val old = obj(c, "seen"); val out = JSONObject()
        for (k in old.keys()) {
            val ck = clean(k); val a = old.getJSONObject(k); val b = out.optJSONObject(ck)
            if (b == null) out.put(ck, JSONObject().put("at", a.optLong("at")).put("img", a.optInt("img")))
            else { b.put("at", maxOf(b.optLong("at"), a.optLong("at"))); b.put("img", b.optInt("img") + a.optInt("img")) }
        }
        put(c, "seen", out)
        val last = obj(c, "last"); val l2 = JSONObject()
        for (k in last.keys()) { val ck = clean(k); l2.put(ck, maxOf(l2.optLong(ck, 0L), last.optLong(k))) }
        put(c, "last", l2)
        return out
    }
    fun obj(c: Context, k: String) = try { JSONObject(prefs(c).getString(k, "{}")!!) } catch (_: Exception) { JSONObject() }
    fun arr(c: Context, k: String) = try { JSONArray(prefs(c).getString(k, "[]")!!) } catch (_: Exception) { JSONArray() }
    fun put(c: Context, k: String, v: Any) = prefs(c).edit().putString(k, v.toString()).apply()
    fun cfg(c: Context) = obj(c, "cfg")
    /** الجروب متابَع؟ (مختار، أو «كل الجروبات» شغال وهو مش مستثنى) */
    fun follows(c: Context, g: String): Boolean {
        val k = g.trim().lowercase(); val cf = cfg(c)
        if (cf.optBoolean("all")) { val off = cf.optJSONArray("off") ?: JSONArray(); return (0 until off.length()).none { off.getString(it).trim().lowercase() == k } }
        return groups(c).contains(k)
    }
    fun groups(c: Context): Set<String> { val a = cfg(c).optJSONArray("groups") ?: return setOf(); return (0 until a.length()).map { a.getString(it).trim().lowercase() }.toSet() }

    @Synchronized fun seen(c: Context, g: String, msgs: List<Pair<String, Long>>) {
        val seen = obj(c, "seen"); val last = obj(c, "last")
        val s = seen.optJSONObject(g) ?: JSONObject()
        s.put("at", System.currentTimeMillis())
        var lt = last.optLong(g, 0L); var got = false
        val ev = arr(c, "ev")
        for ((t, time) in msgs) {
            if (time <= lt) continue
            lt = maxOf(lt, time)
            if (t.contains("📷") || t.contains("🖼")) { s.put("img", s.optInt("img") + 1); ev.put(JSONObject().put("g", g).put("t", time)); got = true }
        }
        last.put(g, lt); seen.put(g, s)
        put(c, "seen", seen); put(c, "last", last)
        // نحتفظ بصور كل الجروبات 3 أيام — لو اخترت جروب بعدين يقرا صوره اللي فاتت
        val keep = JSONArray(); val old = System.currentTimeMillis() - 3 * 86400000L
        for (i in 0 until ev.length()) { val e = ev.getJSONObject(i); if (e.getLong("t") > old) keep.put(e) }
        while (keep.length() > 3000) keep.remove(0)
        put(c, "ev", keep)
        if (got && follows(c, g)) {
            val app = c.applicationContext
            h.postDelayed({ Thread { run(app) }.start() }, 60000)
            h.postDelayed({ Thread { run(app) }.start() }, 300000)
        }
    }

    /** يطابق الصور اللي نزلت مع إشعارات الجروبات ويقراها بـ Gemini */
    fun run(c: Context): Int {
        synchronized(this) { if (busy) return 0; busy = true }
        var n = 0
        try {
            val ev0 = arr(c, "ev"); val ev = JSONArray()
            for (i in 0 until ev0.length()) { val e = ev0.getJSONObject(i); if (follows(c, e.getString("g"))) ev.put(e) }
            if (ev.length() == 0) return 0
            val key = cfg(c).optString("key"); val prompt = cfg(c).optString("prompt")
            if (key.isEmpty() || prompt.isEmpty()) return 0
            var minT = Long.MAX_VALUE
            for (i in 0 until ev.length()) minT = minOf(minT, ev.getJSONObject(i).getLong("t"))
            val done = arr(c, "done"); val doneSet = (0 until done.length()).map { done.getLong(it) }.toMutableSet()
            val res = arr(c, "res")
            val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val cur = c.contentResolver.query(uri, arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DATE_ADDED, MediaStore.Images.Media.BUCKET_DISPLAY_NAME),
                MediaStore.Images.Media.DATE_ADDED + " >= ?", arrayOf(((minT / 1000) - 120).toString()), MediaStore.Images.Media.DATE_ADDED + " ASC") ?: return 0
            val todo = ArrayList<Triple<Long, Long, String>>()
            cur.use { k ->
                while (k.moveToNext()) {
                    val id = k.getLong(0); val t = k.getLong(1) * 1000; val b = k.getString(2) ?: ""
                    if (id in doneSet || !b.contains("WhatsApp", true) || b.contains("Sent", true)) continue
                    var best: String? = null; var bd = Long.MAX_VALUE
                    for (i in 0 until ev.length()) { val e = ev.getJSONObject(i); val d = t - e.getLong("t"); if (d > -120000 && d < 900000 && Math.abs(d) < bd) { bd = Math.abs(d); best = e.getString("g") } }
                    if (best != null) todo.add(Triple(id, t, best))
                }
            }
            for ((id, t, g) in todo) {
                val bytes = try { c.contentResolver.openInputStream(ContentUris.withAppendedId(uri, id))?.use { it.readBytes() } } catch (_: Exception) { null } ?: continue
                // نفس الصورة اتبعتت تاني (أو في جروب تاني) → منقراهاش تاني ومنستهلكش Gemini
                val hash = md5(bytes); val hashes = obj(c, "hash")
                if (hashes.has(hash)) { doneSet.add(id); done.put(id); continue }
                val txt = gemini(key, prompt, bytes) ?: break  // Gemini مش متاح دلوقتي → نحاول تاني بعدين
                doneSet.add(id); done.put(id)
                hashes.put(hash, t); trim(hashes, 400); put(c, "hash", hashes)
                val rows = try { JSONArray(txt.substring(txt.indexOf('['), txt.lastIndexOf(']') + 1)) } catch (_: Exception) { JSONArray() }
                if (rows.length() == 0) continue
                // نفس الأبديت بنفس الشقق والأسعار (الشركات بتعيد بعته كذا مرة في اليوم) → متتعاملش كأبديت جديد
                val sig = sig(rows); val vk = g.lowercase() + "|" + (rows.optJSONObject(0)?.optString("villa") ?: "").uppercase().replace(Regex("[^A-Z0-9]"), "")
                val sigs = obj(c, "sig")
                if (sigs.optString(vk) == sig) { res.put(JSONObject().put("g", g).put("t", t).put("id", id).put("txt", txt).put("same", true)); continue }
                sigs.put(vk, sig); trim(sigs, 600); put(c, "sig", sigs)
                res.put(JSONObject().put("g", g).put("t", t).put("id", id).put("txt", txt)); n++
                notify(c, g, rows.length())

            }
            while (done.length() > 600) done.remove(0)
            put(c, "done", done); put(c, "res", res)
        } catch (_: Exception) {
        } finally { synchronized(this) { busy = false } }
        return n
    }

    // ===== طلبات العملاء من الشات الخاص =====
    private val reqRx = Regex("studio|ستو?ديو|استو?ديو|bhk|b/r|bed ?room|\\broom\\b|flat|apartment|غرف[ةه]|اوض[ةه]|أوض[ةه]|غرفتين|اوضتين|شق[ةه]|سكن|ايجار|إيجار|rent|budget|ميزاني[ةه]", RegexOption.IGNORE_CASE)
    /** رسالة خاصة من عميل: نحفظها، ولو شكلها طلب شقة نبلّغك (من غير ما نرد على حد) */
    @Synchronized fun dm(c: Context, sbn: StatusBarNotification, ex: android.os.Bundle) {
        if (!cfg(c).optBoolean("dm")) return
        val name = ex.getCharSequence("android.title")?.toString()?.let { clean(it) } ?: return
        var phone = (sbn.notification.shortcutId ?: "").substringBefore("@").filter { it.isDigit() }
        if (phone.length < 8) {
            try { @Suppress("DEPRECATION") ex.getParcelableArrayList<android.os.Parcelable>("android.people.list")?.forEach { p ->
                if (Build.VERSION.SDK_INT >= 28 && p is android.app.Person) { val u = p.uri ?: ""; if (u.startsWith("tel:")) phone = u.removePrefix("tel:").filter { it.isDigit() } } } } catch (_: Exception) {}
        }
        val key = if (phone.length >= 8) phone else name
        val msgs = ArrayList<Pair<String, Long>>()
        try { ex.getParcelableArray("android.messages")?.forEach { b -> if (b is android.os.Bundle) msgs.add(Pair(b.getCharSequence("text")?.toString() ?: "", b.getLong("time"))) } } catch (_: Exception) {}
        if (msgs.isEmpty()) msgs.add(Pair(ex.getCharSequence("android.text")?.toString() ?: "", sbn.postTime))
        val last = obj(c, "dmLast"); var lt = last.optLong(key, 0L)
        val dms = arr(c, "dm"); var hit = false
        for ((t, time) in msgs) {
            if (time <= lt || t.isBlank()) continue
            lt = maxOf(lt, time)
            dms.put(JSONObject().put("n", name).put("p", phone).put("txt", t.take(500)).put("t", time))
            if (reqRx.containsMatchIn(t)) hit = true
        }
        last.put(key, lt); trim(last, 800); put(c, "dmLast", last)
        while (dms.length() > 400) dms.remove(0)
        put(c, "dm", dms)
        if (hit) note(c, key.hashCode(), "req", "📩 $name بيدوّر على شقة", "دوس تشوف الشقق المناسبة وتبعتله", "reqs")
    }

    /** إشعار يفتح التطبيق على صفحة معينة */
    fun note(c: Context, id: Int, ch: String, title: String, text: String, go: String) {
        try {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(ch, mapOf("req" to "طلبات العملاء", "view" to "المعاينات", "sum" to "ملخص الصبح").getOrElse(ch) { "تنبيهات" }, NotificationManager.IMPORTANCE_HIGH))
            val open = c.packageManager.getLaunchIntentForPackage(c.packageName)?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP); putExtra("go", go) }
            val pi = PendingIntent.getActivity(c, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, ch) else @Suppress("DEPRECATION") Notification.Builder(c)
            nm.notify(id, b.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setContentIntent(pi).setAutoCancel(true).build())
        } catch (_: Exception) {}
    }

    /** تذكير في ميعاد (معاينة / ملخص الصبح) */
    fun alarm(c: Context, id: Int, at: Long, title: String, text: String, ch: String) {
        try {
            val am = c.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val i = Intent(c, AlarmRx::class.java).putExtra("id", id).putExtra("title", title).putExtra("text", text).putExtra("ch", ch)
            val pi = PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            if (at <= 0) { am.cancel(pi); return }
            if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, at, pi) else am.set(android.app.AlarmManager.RTC_WAKEUP, at, pi)
        } catch (_: Exception) {}
    }

    /** ملخص الصبح: الأبديت اللي وصل بالليل + المتابعات والمعاينات النهارده (من آخر مرة التطبيق اتفتح) */
    fun morning(c: Context): String {
        val res = arr(c, "res"); var nw = 0; val gs = HashSet<String>()
        for (i in 0 until res.length()) { val o = res.getJSONObject(i); if (!o.optBoolean("same")) { nw++; gs.add(o.optString("g")) } }
        val sum = obj(c, "sum"); val o = ArrayList<String>()
        if (nw > 0) o.add("📥 $nw أبديت جديد من ${gs.size} جروب")
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
        val fl = sum.optJSONArray("follow") ?: JSONArray(); var f = 0
        for (i in 0 until fl.length()) if (fl.getJSONObject(i).optString("at") <= today + "T99") f++
        if (f > 0) o.add("🔔 $f عميل محتاج متابعة")
        val vs = sum.optJSONArray("views") ?: JSONArray(); val vt = ArrayList<String>()
        for (i in 0 until vs.length()) { val v = vs.getJSONObject(i); if (v.optString("at").startsWith(today)) vt.add(v.optString("at").substring(11, 16) + " " + v.optString("n")) }
        if (vt.isNotEmpty()) o.add("📅 معاينات النهارده: " + vt.joinToString("، "))
        val nr = sum.optInt("newReq"); if (nr > 0) o.add("📩 $nr طلب عميل لسه مردتش عليه")
        return o.joinToString("\n")
    }
    fun scheduleMorning(c: Context) {
        val cal = java.util.Calendar.getInstance(); cal.set(java.util.Calendar.HOUR_OF_DAY, 9); cal.set(java.util.Calendar.MINUTE, 0); cal.set(java.util.Calendar.SECOND, 0)
        if (cal.timeInMillis <= System.currentTimeMillis() + 60000) cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
        alarm(c, 900, cal.timeInMillis, "☀️ ملخص الصبح", "", "sum")
    }

    // ===== التحديث التلقائي للتطبيق في الخلفية (من غير ما تفتحه) =====
    private const val BASE = "https://raw.githubusercontent.com/bunyanrealstate-commits/bunyan/apk-offers/"
    @Volatile private var lastChk = 0L
    @Volatile private var updBusy = false
    /** بيتنده مع أي إشعار واتساب — بيشيك كل 15 دقيقة بالكتير */
    fun updSoon(c: Context) { if (System.currentTimeMillis() - lastChk < 15 * 60000L || updBusy) return; lastChk = System.currentTimeMillis(); Thread { try { upd(c) } catch (_: Exception) {} }.start() }

    fun myVer(c: Context): Long = try { val pi = c.packageManager.getPackageInfo(c.packageName, 0); if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong() } catch (_: Exception) { 0L }

    /** بيرجع: "same" مفيش جديد • "inst" نزّل وبدأ يسطّب • "fail" */
    fun upd(c: Context): String {
        if (updBusy) return "busy"; updBusy = true
        try {
            val cn = URL(BASE + "version.json?t=" + System.currentTimeMillis()).openConnection() as HttpURLConnection
            cn.connectTimeout = 15000; cn.readTimeout = 15000; cn.useCaches = false
            if (cn.responseCode != 200) return "fail"
            val code = JSONObject(cn.inputStream.bufferedReader().readText()).optLong("code")
            if (code <= myVer(c)) return "same"
            val f = java.io.File(c.cacheDir, "upd-$code.apk")
            if (!f.exists() || f.length() < 1000000) {
                val tmp = java.io.File(c.cacheDir, "upd.part")
                val dn = URL(BASE + "Offers.apk?t=" + System.currentTimeMillis()).openConnection() as HttpURLConnection
                dn.connectTimeout = 20000; dn.readTimeout = 60000; dn.useCaches = false
                if (dn.responseCode != 200) return "fail"
                dn.inputStream.use { i -> tmp.outputStream().use { o -> i.copyTo(o, 64 * 1024) } }
                if (tmp.length() < 1000000) return "fail"
                c.cacheDir.listFiles()?.filter { it.name.startsWith("upd-") }?.forEach { it.delete() }
                tmp.renameTo(f)
            }
            install(c, f); return "inst"
        } catch (_: Exception) { return "fail" } finally { updBusy = false }
    }

    fun install(c: Context, f: java.io.File) {
        val pi = c.packageManager.packageInstaller
        val p = android.content.pm.PackageInstaller.SessionParams(android.content.pm.PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        p.setAppPackageName(c.packageName)
        if (Build.VERSION.SDK_INT >= 31) p.setRequireUserAction(android.content.pm.PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        val id = pi.createSession(p)
        pi.openSession(id).use { s ->
            s.openWrite("app.apk", 0, f.length()).use { out -> f.inputStream().use { it.copyTo(out, 64 * 1024) }; s.fsync(out) }
            val i = Intent(c, UpdRx::class.java)
            val pend = PendingIntent.getBroadcast(c, 77, i, PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
            s.commit(pend.intentSender)
        }
    }

    /** لو أندرويد طلب موافقة وإحنا في الخلفية: إشعار «دوس علشان تحدّث» */
    fun askNotify(c: Context, confirm: Intent) {
        try {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("app", "تحديث التطبيق", NotificationManager.IMPORTANCE_HIGH))
            confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val pi = PendingIntent.getActivity(c, 9, confirm, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "app") else @Suppress("DEPRECATION") Notification.Builder(c)
            nm.notify(4242, b.setSmallIcon(android.R.drawable.stat_sys_download_done).setContentTitle("⬆️ نسخة جديدة من عروض الشقق").setContentText("دوس علشان تتحدث").setContentIntent(pi).setAutoCancel(true).build())
        } catch (_: Exception) {}
    }

    fun md5(b: ByteArray) = java.security.MessageDigest.getInstance("MD5").digest(b).joinToString("") { "%02x".format(it) }
    /** بصمة الأبديت: رقم كل شقة + أسعارها + محجوزة ولا لأ (مترتبة) */
    fun sig(a: JSONArray): String {
        val l = ArrayList<String>()
        for (i in 0 until a.length()) { val o = a.optJSONObject(i) ?: continue
            l.add(o.optString("no").uppercase().replace(Regex("[^A-Z0-9]"), "") + "|" + o.optDouble("p1", 0.0).toLong() + "|" + o.optDouble("p3", 0.0).toLong() + "|" + o.optDouble("mo", 0.0).toLong() + "|" + o.optBoolean("booked")) }
        return l.sorted().joinToString(";")
    }
    fun trim(o: JSONObject, max: Int) { if (o.length() <= max) return; val ks = o.keys().asSequence().toList(); ks.take(o.length() - max).forEach { o.remove(it) } }

    private var models: List<String>? = null
    private fun list(key: String): List<String> {
        models?.let { return it }
        val fall = listOf("gemini-flash-latest", "gemini-2.5-flash", "gemini-flash-lite-latest", "gemini-2.5-flash-lite")
        try {
            val cn = URL("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200").openConnection() as HttpURLConnection
            cn.setRequestProperty("x-goog-api-key", key); cn.connectTimeout = 20000; cn.readTimeout = 20000
            if (cn.responseCode == 200) {
                val a = JSONObject(cn.inputStream.bufferedReader().readText()).optJSONArray("models") ?: JSONArray()
                val ok = ArrayList<String>()
                for (i in 0 until a.length()) {
                    val m = a.getJSONObject(i); val nm = m.optString("name").removePrefix("models/")
                    val meth = m.optJSONArray("supportedGenerationMethods")?.toString() ?: ""
                    if (meth.contains("generateContent") && nm.contains("flash") && !Regex("image|tts|audio|live|embed|exp|8b|thinking|robotics|computer").containsMatchIn(nm)) ok.add(nm)
                }
                fun rank(s: String) = (if (s.contains("lite")) 4 else 0) + (if (s.contains("preview")) 2 else 0) + (if (s.contains("latest")) 0 else 1)
                val srt = ok.sortedWith(compareBy<String>({ rank(it) }, { -(Regex("(\\d+(?:\\.\\d+)?)").find(it)?.value?.toDoubleOrNull() ?: 0.0) }))
                if (srt.isNotEmpty()) { models = (srt.take(5) + fall.filter { it !in srt }).take(7); return models!! }
            }
        } catch (_: Exception) {}
        return fall
    }

    fun gemini(key: String, prompt: String, img: ByteArray): String? {
        val body = JSONObject()
            .put("contents", JSONArray().put(JSONObject().put("role", "user").put("parts", JSONArray()
                .put(JSONObject().put("text", prompt))
                .put(JSONObject().put("inline_data", JSONObject().put("mime_type", "image/jpeg").put("data", Base64.encodeToString(img, Base64.NO_WRAP)))))))
            .put("generationConfig", JSONObject().put("temperature", 0).put("responseMimeType", "application/json")).toString()
        for (m in list(key)) {
            try {
                val cn = URL("https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent").openConnection() as HttpURLConnection
                cn.requestMethod = "POST"; cn.doOutput = true; cn.connectTimeout = 20000; cn.readTimeout = 90000
                cn.setRequestProperty("Content-Type", "application/json"); cn.setRequestProperty("x-goog-api-key", key)
                cn.outputStream.use { it.write(body.toByteArray()) }
                val code = cn.responseCode
                if (code == 200) {
                    val o = JSONObject(cn.inputStream.bufferedReader().readText())
                    val parts = o.optJSONArray("candidates")?.optJSONObject(0)?.optJSONObject("content")?.optJSONArray("parts") ?: continue
                    val sb = StringBuilder(); for (i in 0 until parts.length()) { val p = parts.getJSONObject(i); if (!p.optBoolean("thought")) sb.append(p.optString("text")) }
                    if (sb.isNotBlank()) return sb.toString()
                }
                if (code == 401 || code == 403) return null
                if (code == 404) models = null
            } catch (_: Exception) {}
        }
        return null
    }

    private fun notify(c: Context, g: String, units: Int) {
        try {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("upd", "أبديت الشركات", NotificationManager.IMPORTANCE_DEFAULT))
            val open = c.packageManager.getLaunchIntentForPackage(c.packageName)?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            val pi = PendingIntent.getActivity(c, 5, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "upd") else @Suppress("DEPRECATION") Notification.Builder(c)
            nm.notify(g.hashCode(), b.setSmallIcon(android.R.drawable.stat_sys_download_done).setContentTitle("📥 أبديت جديد: $g").setContentText("$units شقة — افتح التطبيق يتحدث").setContentIntent(pi).setAutoCancel(true).build())
        } catch (_: Exception) {}
    }
}

/** المنبه: معاينة أو ملخص الصبح */
class AlarmRx : android.content.BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        val id = i.getIntExtra("id", 0); val ch = i.getStringExtra("ch") ?: "view"
        if (ch == "sum") {
            val t = Auto.morning(c)
            if (t.isNotEmpty()) Auto.note(c, 900, "sum", "☀️ ملخص الصبح", t, "reqs")
            Auto.scheduleMorning(c)
        } else Auto.note(c, id, ch, i.getStringExtra("title") ?: "", i.getStringExtra("text") ?: "", "reqs")
    }
}
