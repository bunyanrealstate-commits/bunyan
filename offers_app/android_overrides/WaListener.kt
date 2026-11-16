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
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != "com.whatsapp" && sbn.packageName != "com.whatsapp.w4b") return
        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val ex = n.extras ?: return
        val isGroup = ex.getBoolean("android.isGroupConversation", false)
        var g = ex.getCharSequence("android.conversationTitle")?.toString()
        if (g == null && !isGroup) return
        if (g == null) g = ex.getCharSequence("android.title")?.toString() ?: return
        g = Auto.clean(g)
        if (g.isEmpty()) return
        val msgs = ArrayList<Pair<String, Long>>()
        try {
            ex.getParcelableArray("android.messages")?.forEach { b -> if (b is android.os.Bundle) msgs.add(Pair(b.getCharSequence("text")?.toString() ?: "", b.getLong("time"))) }
        } catch (_: Exception) {}
        if (msgs.isEmpty()) msgs.add(Pair(ex.getCharSequence("android.text")?.toString() ?: "", sbn.postTime))
        Auto.seen(this, g, msgs)
    }
}

object Auto {
    private val h = Handler(Looper.getMainLooper())
    private var busy = false
    fun prefs(c: Context) = c.getSharedPreferences("auto", Context.MODE_PRIVATE)
    fun clean(s: String) = s.replace(Regex("\\s*\\(\\d+[^)]*\\)\\s*$"), "").replace(Regex("^\\s*\\d+\\s+"), "").trim()
    fun obj(c: Context, k: String) = try { JSONObject(prefs(c).getString(k, "{}")!!) } catch (_: Exception) { JSONObject() }
    fun arr(c: Context, k: String) = try { JSONArray(prefs(c).getString(k, "[]")!!) } catch (_: Exception) { JSONArray() }
    fun put(c: Context, k: String, v: Any) = prefs(c).edit().putString(k, v.toString()).apply()
    fun cfg(c: Context) = obj(c, "cfg")
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
        if (got && groups(c).contains(g.lowercase())) {
            val keep = JSONArray(); val old = System.currentTimeMillis() - 86400000L
            for (i in 0 until ev.length()) { val e = ev.getJSONObject(i); if (e.getLong("t") > old && groups(c).contains(e.getString("g").lowercase())) keep.put(e) }
            put(c, "ev", keep)
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
            val ev = arr(c, "ev"); if (ev.length() == 0) return 0
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
                val txt = gemini(key, prompt, bytes) ?: break  // Gemini مش متاح دلوقتي → نحاول تاني بعدين
                doneSet.add(id); done.put(id)
                val units = try { JSONArray(txt.substring(txt.indexOf('['), txt.lastIndexOf(']') + 1)).length() } catch (_: Exception) { 0 }
                if (units > 0) { res.put(JSONObject().put("g", g).put("t", t).put("id", id).put("txt", txt)); n++; notify(c, g, units) }
            }
            while (done.length() > 600) done.remove(0)
            put(c, "done", done); put(c, "res", res)
        } catch (_: Exception) {
        } finally { synchronized(this) { busy = false } }
        return n
    }

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
