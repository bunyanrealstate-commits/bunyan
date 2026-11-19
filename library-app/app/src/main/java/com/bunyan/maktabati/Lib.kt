package com.bunyan.maktabati

import android.content.Context
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
    /** إعدادات وحاجات محلية: eve/eveT/para/paraT/badges/rev/wk/gf/mode */
    var cfg = JSONObject()
    /** تذكيرات اتعملت من التطبيق ورايحة لتذكيراتي في بنيان */
    var rems = JSONArray()
    val bg = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    val session = UUID.randomUUID().toString().take(8)

    fun bump() { ver++ }
    fun isInit() = ::dir.isInitialized
    var appCtx: Context? = null
    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    fun ds(d: Date): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(d)

    fun init(ctx: Context) {
        dir = ctx.filesDir; appCtx = ctx.applicationContext
        File(dir, "books").mkdirs(); File(dir, "tts").mkdirs(); File(dir, "covers").mkdirs()
        val f = File(dir, "lib.json")
        if (f.exists()) try {
            val j = JSONObject(f.readText())
            link = j.optJSONObject("link")
            app = j.optJSONObject("app") ?: JSONObject()
            goal = j.optInt("goal", 10)
            pulledAt = j.optLong("pulledAt", 0)
            cfg = j.optJSONObject("cfg") ?: JSONObject()
            rems = j.optJSONArray("rems") ?: JSONArray()
            queue = ArrayList(arr(j.optJSONArray("queue")).map { it.toString() })
            books.clear(); arr(j.optJSONArray("books")).forEach { if (it is JSONObject) books.add(it) }
        } catch (_: Exception) {}
        // أول مرة: قايمة كتبك اللي في بنيان (من الرابط اللي بعته) جاهزة جوه التطبيق
        if (books.none { !(app.optJSONObject(it.optString("id"))?.has("nw") ?: false) }) try {
            val sd = JSONObject(ctx.assets.open("seed.json").bufferedReader().readText())
            val have = books.map { it.optString("id") }.toHashSet()
            arr(sd.optJSONArray("books")).forEach { if (it is JSONObject && !have.contains(it.optString("id"))) books.add(it) }
            if (!f.exists()) goal = sd.optInt("bdg", 10)
            if (queue.isEmpty()) queue = ArrayList(arr(sd.optJSONArray("bq")).map { it.toString() })
            (ctx.assets.list("covers") ?: emptyArray()).forEach { n -> val o = File(dir, "covers/$n"); if (!o.exists()) ctx.assets.open("covers/$n").use { i -> o.outputStream().use { i.copyTo(it) } } }
            save()
        } catch (_: Exception) {}
        bump()
    }

    fun save() {
        val j = JSONObject()
        j.put("link", link); j.put("app", app); j.put("goal", goal); j.put("pulledAt", pulledAt); j.put("cfg", cfg); j.put("rems", rems)
        j.put("queue", JSONArray(queue)); j.put("books", JSONArray(books))
        val f = File(dir, "lib.json.tmp"); f.writeText(j.toString()); f.renameTo(File(dir, "lib.json"))
        bump()
        appCtx?.let { c -> try { ReadWidget.refresh(c) } catch (_: Exception) {} }
    }

    fun arr(a: JSONArray?): List<Any> = if (a == null) emptyList() else (0 until a.length()).map { a.get(it) }
    fun book(id: String): JSONObject? = books.firstOrNull { it.optString("id") == id }
    fun gem(): JSONObject? = link?.optString("g")?.let { try { JSONObject(it) } catch (_: Exception) { null } }?.takeIf { it.optString("key").isNotEmpty() }

    /* ───── قراية ───── */
    fun appRec(id: String): JSONObject { var r = app.optJSONObject(id); if (r == null) { r = JSONObject(); app.put(id, r) }; return r }

    fun touch(b: JSONObject, vararg keys: String) {
        val r = appRec(b.optString("id"))
        b.put("rd", System.currentTimeMillis())
        for (k in keys.toList() + "rd") if (b.has(k)) r.put(k, b.get(k))
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

    fun addQuote(b: JSONObject, t: String, p: Int) {
        val q = JSONObject().put("t", t.trim()).put("p", p).put("d", today())
        (b.optJSONArray("q") ?: JSONArray().also { b.put("q", it) }).put(q)
        val r = appRec(b.optString("id")); (r.optJSONArray("q") ?: JSONArray().also { r.put("q", it) }).put(JSONObject(q.toString()))
        touch(b); save()
    }
    fun addSum(b: JSONObject, sm: JSONObject) {
        (b.optJSONArray("sums") ?: JSONArray().also { b.put("sums", it) }).put(sm)
        val r = appRec(b.optString("id")); (r.optJSONArray("sums") ?: JSONArray().also { r.put("sums", it) }).put(JSONObject(sm.toString()))
        touch(b); save()
    }
    fun addRem(t: String, n: String, d: String, tm: String) {
        rems.put(JSONObject().put("i", "rm_" + UUID.randomUUID().toString().take(10)).put("t", t).put("n", n).put("d", d).put("tm", tm)); save()
    }
    fun quoteText(q: Any?): String = when (q) { is JSONObject -> q.optString("t"); null -> ""; else -> q.toString() }

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

    /** 🔒 الكتب مستخبية لحد ما تعمل الحركة السرية وتكتب الرقم السري */
    var revealed by mutableStateOf(false)
    var pickAt = 0L
    fun hasPin() = cfg.optString("pin").isNotEmpty()
    private fun hp(p: String): String = java.security.MessageDigest.getInstance("SHA-256").digest(("mktb:" + p).toByteArray()).joinToString("") { "%02x".format(it) }
    fun checkPin(p: String) = hasPin() && cfg.optString("pin") == hp(p)
    fun setPin(p: String) { cfg.put("pin", hp(p)); save() }

    /** ⏱ «دقيقتين بس»: الكتاب الجاي يتفتح بعدّاد دقيقتين */
    var sprint by mutableStateOf(false)

    /** أيام من آخر مرة قريت فيها (999 لو عمرك ما قريت) */
    fun idleDays(): Int {
        val last = dayMap().filter { it.value > 0 }.keys.maxOrNull() ?: return 999
        val d = try { SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(last)!!.time } catch (_: Exception) { return 999 }
        val t = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(today())!!.time
        return ((t - d) / 86400000L).toInt()
    }

    /** 🔁 رجوع سهل: لو بقالك 3 أيام مش بتقرا الهدف ينزل لصفحة واحدة، ولما تقرا 3 أيام ورا بعض يرجع لوحده */
    fun comeback(): String? {
        if (!cfg.has("goalOld") && goal > 1 && idleDays() >= 3) {
            cfg.put("goalOld", goal); goal = 1; save()
            return "🔁 نزّلتلك الهدف لصفحة واحدة بس لحد ما ترجع — ولا يهمك 💚"
        }
        if (cfg.has("goalOld") && streak() >= 3) {
            goal = cfg.optInt("goalOld", 10); cfg.remove("goalOld"); save()
            return "🔥 3 أيام ورا بعض! رجّعتلك هدفك $goal صفحات"
        }
        return null
    }

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

    /** 🔓 مكتبتي بقت لوحدها: مفيش مزامنة مع بنيان — بس نسخة احتياطية في ملف خاص بيها (maktabati.json) */
    fun solo() = cfg.optBoolean("solo", false)
    private const val BK = "maktabati.json"

    suspend fun sync(): String = withContext(Dispatchers.IO) {
        if (link == null) return@withContext "مش مربوط"
        if (solo()) return@withContext backup()
        // آخر مرة: ناخد آخر حاجة من بنيان علشان مفيش حاجة تضيع، وبعدها ننفصل
        val r = pullFromBunyan()
        if (r.startsWith("تمام")) { withContext(Dispatchers.Main) { cfg.put("solo", true); cfg.put("soloAt", today()); save() }; return@withContext backup().let { "🔓 مكتبتي بقت لوحدها — " + it } }
        r
    }

    private fun snapshot(): JSONObject = JSONObject().put("v", 1).put("at", System.currentTimeMillis()).put("app", app).put("goal", goal).put("cfg", cfg)
        .put("rems", rems).put("queue", JSONArray(queue)).put("books", JSONArray(books))
        .also { s -> try { val c = File(dir, "crash.txt"); if (c.exists()) s.put("crash", c.readText()) } catch (_: Exception) {} }

    private suspend fun backup(): String {
        syncing = true
        try {
            val (c0, t0) = gh(BK)
            if (c0 == 401 || c0 == 403) return "مفتاح النسخة الاحتياطية مش شغال ($c0)"
            val sha = if (c0 == 200) JSONObject(t0).optString("sha") else null
            // موبايل جديد / التطبيق اتمسح: رجّع كتبك من النسخة الاحتياطية
            if (books.isEmpty() && sha != null) {
                val (c1, t1) = gh(BK, raw = true)
                if (c1 == 200) {
                    val j = JSONObject(t1)
                    withContext(Dispatchers.Main) {
                        app = j.optJSONObject("app") ?: JSONObject(); goal = j.optInt("goal", goal)
                        cfg = (j.optJSONObject("cfg") ?: JSONObject()).put("solo", true); rems = j.optJSONArray("rems") ?: JSONArray()
                        queue = ArrayList(arr(j.optJSONArray("queue")).map { it.toString() })
                        books.clear(); arr(j.optJSONArray("books")).forEach { if (it is JSONObject) books.add(it) }
                        save()
                    }
                    return "تمام ✅ رجّعت ${books.size} كتاب من النسخة الاحتياطية"
                }
            }
            val body = JSONObject().put("message", "مكتبتي: نسخة احتياطية")
                .put("content", Base64.encodeToString(snapshot().toString().toByteArray(), Base64.NO_WRAP))
            if (sha != null) body.put("sha", sha)
            val (c2, _) = gh(BK, "PUT", body.toString())
            pulledAt = System.currentTimeMillis()
            if (c2 == 200 || c2 == 201) try { File(dir, "crash.txt").delete() } catch (_: Exception) {}
            return if (c2 == 200 || c2 == 201) "تمام ✅ (${books.size} كتاب) — محفوظين احتياطي" else "مقدرتش أحفظ النسخة الاحتياطية ($c2)"
        } catch (e: Exception) { return "مفيش نت؟" } finally { syncing = false }
    }

    private suspend fun pullFromBunyan(): String = withContext(Dispatchers.IO) {
        syncing = true
        try {
            try { push() } catch (_: Exception) {}
            val (code, txt) = gh(link!!.optString("p", "book.json"), raw = true)
            if (code == 401 || code == 403) return@withContext "مفتاح الربط مش شغال ($code)"
            if (code == 404) return@withContext "ملف بياناتك مش لاقيه (404)"
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
                if (loc != null) for (k in listOf("spd", "nx", "eps", "hook", "ch", "hl", "paper", "r", "rv")) if (loc.has(k)) rb.put(k, loc.get(k))
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
                if (r != null) {
                    for (k in listOf("q", "sums")) {
                        val mine = r.optJSONArray(k) ?: continue
                        val there = rb.optJSONArray(k) ?: JSONArray().also { rb.put(k, it) }
                        val have = HashSet((0 until there.length()).map { quoteText(there.get(it)) })
                        val keep = JSONArray()
                        for (i in 0 until mine.length()) { val x = mine.getJSONObject(i); if (!have.contains(x.optString("t"))) { there.put(x); keep.put(x) } }
                        r.put(k, keep)
                    }
                }
                out.add(rb)
            }
            run { val keep = JSONArray(); for (i in 0 until rems.length()) { val x = rems.getJSONObject(i); if (!done.contains(x.optString("i"))) keep.put(x) }; rems = keep }
            books.filter { !seen.contains(it.optString("id")) && app.optJSONObject(it.optString("id"))?.has("nw") == true }.forEach { out.add(0, it) }
            books.clear(); books.addAll(out)
            if (cfg.has("goalOld")) cfg.put("goalOld", d.optInt("bdg", cfg.optInt("goalOld"))) else goal = d.optInt("bdg", goal)
            queue = ArrayList(arr(d.optJSONArray("bq")).map { it.toString() })
            pulledAt = System.currentTimeMillis()
            withContext(Dispatchers.Main) { save() }
            "تمام ✅ (${books.size} كتاب)"
        } catch (e: Exception) { "مفيش نت؟ (${e.message?.take(40)})" } finally { syncing = false }
    }

    private fun push() {
        if (app.length() == 0 && rems.length() == 0) return
        val (c0, t0) = gh("lib-app.json")
        val sha = if (c0 == 200) JSONObject(t0).optString("sha") else null
        val payload = JSONObject().put("at", System.currentTimeMillis()).put("books", app).put("rems", rems)
        val body = JSONObject().put("message", "مكتبتي: تقدم القراية من تطبيق الموبايل")
            .put("content", Base64.encodeToString(payload.toString().toByteArray(), Base64.NO_WRAP))
        if (sha != null) body.put("sha", sha)
        gh("lib-app.json", "PUT", body.toString())
    }

    fun parseLink(code: String): JSONObject? {
        var s = Regex("BNYLINK-([A-Za-z0-9_-]+)").find(code.replace(Regex("\\s+"), ""))?.groupValues?.get(1) ?: ""
        if (s.isEmpty()) return null
        s = s.replace("-", "+").replace("_", "/"); while (s.length % 4 != 0) s += "="
        return try { val o = JSONObject(String(Base64.decode(s, Base64.DEFAULT))); if (o.optString("t").isEmpty()) null else o } catch (_: Exception) { null }
    }
}
