package com.bunyan.maktabati

import android.content.Context
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/** بيانات المكتبة: بتتقري من حساب بنيان (book.json) وتقدمك هنا بيتكتب في ملف لوحده (lib-app.json) وبنيان بيدمجه. */
object Lib {
    lateinit var dir: File
    var ver by mutableIntStateOf(0)
    var syncing by mutableStateOf(false)
    var msg by mutableStateOf("")
    val books = ArrayList<JSONObject>()
    var goal = 10
    var queue = ArrayList<String>()
    var link: JSONObject? = null           // {r,t,p,g}
    var app = JSONObject()                  // id -> {cur,maxp,sh,rd,sd,fd,pg,add:[{i,d,p}], nw?, o?}
    var pulledAt = 0L

    val session = UUID.randomUUID().toString().take(8)

    fun bump() { ver++ }
    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    fun ds(d: Date): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(d)

    fun init(ctx: Context) {
        dir = ctx.filesDir
        File(dir, "books").mkdirs(); File(dir, "tts").mkdirs(); File(dir, "covers").mkdirs()
        val f = File(dir, "lib.json")
        if (f.exists()) try {
            val j = JSONObject(f.readText())
            link = j.optJSONObject("link")
            app = j.optJSONObject("app") ?: JSONObject()
            goal = j.optInt("goal", 10)
            pulledAt = j.optLong("pulledAt", 0)
            queue = ArrayList(arr(j.optJSONArray("queue")).map { it.toString() })
            books.clear(); arr(j.optJSONArray("books")).forEach { if (it is JSONObject) books.add(it) }
        } catch (_: Exception) {}
        bump()
    }

    fun save() {
        val j = JSONObject()
        j.put("link", link); j.put("app", app); j.put("goal", goal); j.put("pulledAt", pulledAt)
        j.put("queue", JSONArray(queue)); j.put("books", JSONArray(books))
        val f = File(dir, "lib.json.tmp"); f.writeText(j.toString()); f.renameTo(File(dir, "lib.json"))
        bump()
    }

    fun arr(a: JSONArray?): List<Any> = if (a == null) emptyList() else (0 until a.length()).map { a.get(it) }
    fun book(id: String): JSONObject? = books.firstOrNull { it.optString("id") == id }
    fun gem(): JSONObject? = link?.optString("g")?.let { try { JSONObject(it) } catch (_: Exception) { null } }?.takeIf { it.optString("key").isNotEmpty() }

    /* ───── قراية ───── */
    fun appRec(id: String): JSONObject { var r = app.optJSONObject(id); if (r == null) { r = JSONObject(); app.put(id, r) }; return r }

    fun touch(b: JSONObject, vararg keys: String) {
        val r = appRec(b.optString("id"))
        b.put("rd", System.currentTimeMillis())
        for (k in keys + "rd") if (b.has(k)) r.put(k, b.get(k))
    }

    fun setCur(b: JSONObject, p: Int) { b.put("cur", p); touch(b, "cur"); save() }

    /** صفحة اتقرت فعلاً (قعد عليها 20 ثانية أو اتسمعت) */
    fun credit(b: JSONObject, p: Int): Boolean {
        if (p <= b.optInt("maxp", 0)) return false
        b.put("maxp", p)
        val d = today()
        val log = b.optJSONArray("log") ?: JSONArray().also { b.put("log", it) }
        var hit = false
        for (i in 0 until log.length()) { val l = log.getJSONObject(i); if (l.optString("d") == d) { l.put("p", l.optInt("p") + 1); hit = true } }
        if (!hit) log.put(JSONObject().put("d", d).put("p", 1))
        val r = appRec(b.optString("id"))
        val add = r.optJSONArray("add") ?: JSONArray().also { r.put("add", it) }
        val aid = session + "_" + d
        var found = false
        for (i in 0 until add.length()) { val a = add.getJSONObject(i); if (a.optString("i") == aid) { a.put("p", a.optInt("p") + 1); found = true } }
        if (!found) add.put(JSONObject().put("i", aid).put("d", d).put("p", 1))
        if (b.optString("sh") != "now" && b.optString("sh") != "done") { b.put("sh", "now"); if (!b.has("sd")) b.put("sd", d) }
        touch(b, "maxp", "sh", "sd")
        save(); return true
    }

    fun setShelf(b: JSONObject, sh: String) {
        b.put("sh", sh)
        if (sh == "now" && !b.has("sd")) b.put("sd", today())
        if (sh == "done") b.put("fd", today())
        touch(b, "sh", "sd", "fd"); save()
    }

    fun dayMap(): Map<String, Int> {
        val m = HashMap<String, Int>()
        books.forEach { b -> arr(b.optJSONArray("log")).forEach { l -> if (l is JSONObject) m[l.optString("d")] = (m[l.optString("d")] ?: 0) + l.optInt("p") } }
        return m
    }
    fun streak(): Int {
        val m = dayMap(); val c = java.util.Calendar.getInstance(); var n = 0
        if ((m[ds(c.time)] ?: 0) == 0) c.add(java.util.Calendar.DAY_OF_MONTH, -1)
        while ((m[ds(c.time)] ?: 0) > 0) { n++; c.add(java.util.Calendar.DAY_OF_MONTH, -1) }
        return n
    }
    fun todayPages(): Int = dayMap()[today()] ?: 0

    fun current(): JSONObject? {
        val now = books.filter { it.optString("sh") == "now" }
        return now.maxByOrNull { it.optLong("rd", 0) } ?: queue.mapNotNull { book(it) }.firstOrNull { it.optString("sh") == "want" }
            ?: books.firstOrNull { it.optString("sh") == "want" }
    }

    fun addLocal(t: String, a: String, extra: (JSONObject) -> Unit): JSONObject {
        val id = UUID.randomUUID().toString().replace("-", "").take(9)
        val b = JSONObject().put("id", id).put("t", t).put("a", a).put("sh", "want")
        extra(b)
        books.add(0, b)
        val r = appRec(id); r.put("nw", 1); r.put("o", JSONObject(b.toString()))
        touch(b, "sh"); save(); return b
    }

    fun files(b: JSONObject): List<File> {
        val id = b.optString("id")
        val out = ArrayList<File>()
        val f0 = File(dir, "books/$id.pdf"); if (f0.exists()) out.add(f0) else return out
        var k = 2
        while (true) { val f = File(dir, "books/$id#part$k.pdf"); if (f.exists()) { out.add(f); k++ } else break }
        return out
    }
    fun have(b: JSONObject): Boolean {
        val f = files(b); if (f.isEmpty()) return false
        val need = b.optJSONArray("iaff")?.length() ?: 1
        return f.size >= need
    }

    /* ───── مزامنة مع حساب بنيان ───── */
    private fun gh(path: String, method: String = "GET", body: String? = null, raw: Boolean = false): Pair<Int, String> {
        val l = link ?: return 0 to ""
        val c = URL("https://api.github.com/repos/${l.optString("r")}/contents/$path").openConnection() as HttpURLConnection
        c.requestMethod = method; c.connectTimeout = 20000; c.readTimeout = 60000
        c.setRequestProperty("Authorization", "Bearer " + l.optString("t"))
        c.setRequestProperty("Accept", if (raw) "application/vnd.github.raw" else "application/vnd.github+json")
        c.setRequestProperty("Cache-Control", "no-cache")
        if (body != null) { c.doOutput = true; c.setRequestProperty("Content-Type", "application/json"); c.outputStream.use { it.write(body.toByteArray()) } }
        val code = c.responseCode
        val txt = try { (if (code < 400) c.inputStream else c.errorStream)?.bufferedReader()?.readText() ?: "" } catch (_: Exception) { "" }
        return code to txt
    }

    suspend fun sync(): String = withContext(Dispatchers.IO) {
        if (link == null) return@withContext "مش مربوط بحساب بنيان"
        syncing = true
        try {
            push()
            val (code, txt) = gh(link!!.optString("p", "book.json"), raw = true)
            if (code != 200) return@withContext "مقدرتش أجيب البيانات ($code)"
            val d = JSONObject(txt)
            val done = HashSet(arr(d.optJSONArray("bkAppDone")).map { it.toString() })
            val remote = arr(d.optJSONArray("books")).filterIsInstance<JSONObject>()
            val out = ArrayList<JSONObject>()
            val seen = HashSet<String>()
            for (rb in remote) {
                val id = rb.optString("id"); seen.add(id)
                val loc = book(id)
                val cv = rb.optString("cv")
                if (cv.startsWith("data:image")) { val cf = File(dir, "covers/$id.jpg"); if (!cf.exists()) try { cf.writeBytes(Base64.decode(cv.substringAfter(","), Base64.DEFAULT)) } catch (_: Exception) {} }
                rb.remove("cv")
                if (loc != null && loc.has("spd")) rb.put("spd", loc.optInt("spd"))
                val r = app.optJSONObject(id)
                if (r != null && r.optLong("rd") > rb.optLong("rd", 0)) {
                    for (k in listOf("cur", "maxp", "sh", "sd", "fd", "pg", "rd")) if (r.has(k)) rb.put(k, r.get(k))
                }
                if (loc != null && loc.optInt("maxp") > rb.optInt("maxp")) rb.put("maxp", loc.optInt("maxp"))
                // صفحات اتقرت هنا ولسه بنيان مضافهاش
                val adds = r?.optJSONArray("add")
                if (adds != null) {
                    val log = rb.optJSONArray("log") ?: JSONArray().also { rb.put("log", it) }
                    for (i in 0 until adds.length()) {
                        val a = adds.getJSONObject(i); if (done.contains(a.optString("i"))) continue
                        var hit = false
                        for (j in 0 until log.length()) { val x = log.getJSONObject(j); if (x.optString("d") == a.optString("d")) { x.put("p", x.optInt("p") + a.optInt("p")); hit = true } }
                        if (!hit) log.put(JSONObject().put("d", a.optString("d")).put("p", a.optInt("p")))
                    }
                    // اللي بنيان ضافه خلاص نشيله من هنا
                    val keep = JSONArray(); for (i in 0 until adds.length()) { val a = adds.getJSONObject(i); if (!done.contains(a.optString("i"))) keep.put(a) }
                    r.put("add", keep)
                }
                out.add(rb)
            }
            books.filter { !seen.contains(it.optString("id")) && app.optJSONObject(it.optString("id"))?.has("nw") == true }.forEach { out.add(0, it) }
            books.clear(); books.addAll(out)
            goal = d.optInt("bdg", goal)
            queue = ArrayList(arr(d.optJSONArray("bq")).map { it.toString() })
            pulledAt = System.currentTimeMillis()
            withContext(Dispatchers.Main) { save() }
            "تمام ✅"
        } catch (e: Exception) { "مفيش نت؟ (${e.message?.take(40)})" } finally { syncing = false }
    }

    private fun push() {
        if (app.length() == 0) return
        val (c0, t0) = gh("lib-app.json")
        val sha = if (c0 == 200) JSONObject(t0).optString("sha") else null
        val payload = JSONObject().put("at", System.currentTimeMillis()).put("books", app)
        val body = JSONObject().put("message", "مكتبتي: تقدم القراية من تطبيق الموبايل")
            .put("content", Base64.encodeToString(payload.toString().toByteArray(), Base64.NO_WRAP))
        if (sha != null) body.put("sha", sha)
        gh("lib-app.json", "PUT", body.toString())
    }

    fun parseLink(code: String): JSONObject? {
        var s = code.trim().substringAfter("BNYLINK-", "")
        if (s.isEmpty()) return null
        s = s.replace("-", "+").replace("_", "/"); while (s.length % 4 != 0) s += "="
        return try { val o = JSONObject(String(Base64.decode(s, Base64.DEFAULT))); if (o.optString("t").isEmpty()) null else o } catch (_: Exception) { null }
    }
}
