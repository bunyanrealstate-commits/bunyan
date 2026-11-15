package com.bunyan.maktabati

import android.graphics.Bitmap
import android.util.Base64
import kotlinx.coroutines.*
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

object Net {
    private fun open(u: String): HttpURLConnection {
        var url = u; var n = 0
        while (true) {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 20000; c.readTimeout = 60000; c.instanceFollowRedirects = false
            c.setRequestProperty("User-Agent", "Maktabati/1.0 (Android)")
            val code = c.responseCode
            if (code in 300..399 && n < 6) { url = URL(URL(url), c.getHeaderField("Location")).toString(); c.disconnect(); n++; continue }
            return c
        }
    }

    suspend fun getText(u: String): String = withContext(Dispatchers.IO) { open(u).inputStream.bufferedReader().readText() }

    data class Hit(val id: String, val title: String, val author: String)

    suspend fun search(q: String): List<Hit> = withContext(Dispatchers.IO) {
        val qq = "(title:(" + q + ") OR creator:(" + q + ")) AND mediatype:texts"
        val u = "https://archive.org/advancedsearch.php?q=" + URLEncoder.encode(qq, "UTF-8") +
                "&fl[]=identifier&fl[]=title&fl[]=creator&rows=40&sort[]=downloads+desc&output=json"
        val docs = JSONObject(getText(u)).getJSONObject("response").getJSONArray("docs")
        (0 until docs.length()).map {
            val d = docs.getJSONObject(it)
            val cr = d.opt("creator").let { c -> if (c is JSONArray) (if (c.length() > 0) c.getString(0) else "") else (c?.toString() ?: "") }
            Hit(d.optString("identifier"), d.opt("title").let { t -> if (t is JSONArray) t.optString(0) else t?.toString() ?: "" }, cr)
        }
    }

    /** ملفات الـPDF بتاعة الكتاب (لو مقسوم أجزاء بترجع كلها بالترتيب) */
    suspend fun parts(b: JSONObject): List<String> = withContext(Dispatchers.IO) {
        val have = b.optJSONArray("iaff")
        if (have != null && have.length() > 0) return@withContext (0 until have.length()).map { have.getString(it) }
        val m = JSONObject(getText("https://archive.org/metadata/" + URLEncoder.encode(b.optString("ia"), "UTF-8")))
        val fs = m.optJSONArray("files") ?: JSONArray()
        val l = (0 until fs.length()).map { fs.getJSONObject(it) }
            .filter { val n = it.optString("name"); n.endsWith(".pdf", true) && !n.endsWith("_text.pdf", true) && (it.optString("size").toLongOrNull() ?: 0) < 180L * 1048576 }
            .map { it.optString("name") }
            .sortedWith { x, y -> natural(x, y) }.take(12)
        if (l.isEmpty() && b.optString("iaf").isNotEmpty()) return@withContext listOf(b.optString("iaf"))
        b.put("iaff", JSONArray(l)); b.put("iav", l.size)
        l
    }

    private fun natural(a: String, b: String): Int {
        val ra = Regex("\\d+|\\D+").findAll(a).map { it.value }.toList(); val rb = Regex("\\d+|\\D+").findAll(b).map { it.value }.toList()
        for (i in 0 until minOf(ra.size, rb.size)) {
            val x = ra[i]; val y = rb[i]
            val c = if (x[0].isDigit() && y[0].isDigit()) (x.toBigInteger().compareTo(y.toBigInteger())) else x.compareTo(y)
            if (c != 0) return c
        }
        return ra.size - rb.size
    }

    /** تحميل سريع: بيقسم الملف لـ 8 حتت ويحمّلهم في نفس الوقت من السيرفر المباشر (زي برامج التحميل) */
    suspend fun download(u: String, to: File, prog: (Long, Long) -> Unit) = withContext(Dispatchers.IO) {
        // 1) نوصل للسيرفر الحقيقي ونعرف الحجم ولو بيدعم التقسيم
        var url = u; var total = -1L; var ranges = false
        run {
            var n = 0
            while (true) {
                val c = URL(url).openConnection() as HttpURLConnection
                c.connectTimeout = 20000; c.readTimeout = 30000; c.instanceFollowRedirects = false
                c.setRequestProperty("User-Agent", "Maktabati/1.0 (Android)"); c.setRequestProperty("Range", "bytes=0-0")
                val code = c.responseCode
                if (code in 300..399 && n < 8) { url = URL(URL(url), c.getHeaderField("Location")).toString(); c.disconnect(); n++; continue }
                if (code >= 400) { c.disconnect(); throw Exception("HTTP $code") }
                val cr = c.getHeaderField("Content-Range")
                if (code == 206 && cr != null) { ranges = true; total = cr.substringAfter("/").trim().toLongOrNull() ?: -1 } else total = c.contentLengthLong
                c.disconnect(); break
            }
        }
        val tmp = File(to.path + ".dl")
        val got = java.util.concurrent.atomic.AtomicLong(0)
        val tick = launch { while (isActive) { kotlinx.coroutines.delay(300); val g = got.get(); withContext(Dispatchers.Main) { prog(g, total) } } }
        try {
            if (ranges && total > 3L * 1048576) {
                java.io.RandomAccessFile(tmp, "rw").use { it.setLength(total) }
                val k = if (total > 40L * 1048576) 10 else if (total > 12L * 1048576) 8 else 4
                val sz = (total + k - 1) / k
                coroutineScope {
                    (0 until k).map { i ->
                        async(Dispatchers.IO) {
                            val a = i * sz; val e = minOf(total - 1, a + sz - 1); var pos = a; var tries = 0
                            while (pos <= e) {
                                try {
                                    val c = URL(url).openConnection() as HttpURLConnection
                                    c.connectTimeout = 20000; c.readTimeout = 45000
                                    c.setRequestProperty("User-Agent", "Maktabati/1.0 (Android)"); c.setRequestProperty("Range", "bytes=$pos-$e")
                                    if (c.responseCode != 206) throw Exception("HTTP " + c.responseCode)
                                    java.io.RandomAccessFile(tmp, "rw").use { raf ->
                                        raf.seek(pos)
                                        c.inputStream.use { inp ->
                                            val buf = ByteArray(128 * 1024)
                                            while (pos <= e) { val n = inp.read(buf); if (n < 0) break; raf.write(buf, 0, n); pos += n; got.addAndGet(n.toLong()) }
                                        }
                                    }
                                } catch (x: Exception) { if (++tries > 6) throw x; kotlinx.coroutines.delay(800L * tries) }
                            }
                        }
                    }.awaitAll()
                }
            } else {
                val c = open(url)
                if (c.responseCode >= 400) throw Exception("HTTP " + c.responseCode)
                if (total <= 0) total = c.contentLengthLong
                c.inputStream.use { inp -> tmp.outputStream().use { out ->
                    val buf = ByteArray(256 * 1024)
                    while (true) { val n = inp.read(buf); if (n < 0) break; out.write(buf, 0, n); got.addAndGet(n.toLong()) }
                } }
            }
        } finally { tick.cancel() }
        if (!tmp.renameTo(to)) { tmp.copyTo(to, true); tmp.delete() }
    }

    fun iaUrl(id: String, f: String) = "https://archive.org/download/" + URLEncoder.encode(id, "UTF-8") + "/" + f.split("/").joinToString("/") { URLEncoder.encode(it, "UTF-8").replace("+", "%20") }

    /* ───── Gemini (المفتاح المجاني من حساب بنيان) ───── */
    suspend fun gemini(prompt: String, img: Bitmap? = null): String? = ask(prompt, if (img == null) emptyList() else listOf(img))

    fun hasGem() = Lib.gem() != null

    suspend fun ask(prompt: String, imgs: List<Bitmap> = emptyList(), fileUris: List<String> = emptyList(), json: Boolean = false): String? = withContext(Dispatchers.IO) {
        val g = Lib.gem() ?: return@withContext null
        val models = ArrayList<String>()
        g.optJSONArray("models")?.let { a -> for (i in 0 until a.length()) models.add(a.getString(i)) }
        listOf("gemini-2.5-flash", "gemini-flash-latest", "gemini-2.0-flash").forEach { if (!models.contains(it)) models.add(it) }
        val parts = JSONArray()
        fileUris.forEach { parts.put(JSONObject().put("file_data", JSONObject().put("mime_type", "application/pdf").put("file_uri", it))) }
        imgs.forEach { img ->
            val bo = ByteArrayOutputStream(); img.compress(Bitmap.CompressFormat.JPEG, 82, bo)
            parts.put(JSONObject().put("inline_data", JSONObject().put("mime_type", "image/jpeg").put("data", Base64.encodeToString(bo.toByteArray(), Base64.NO_WRAP))))
        }
        parts.put(JSONObject().put("text", prompt))
        val gc = JSONObject().put("temperature", if (json) 0.4 else 0)
        if (json) gc.put("responseMimeType", "application/json")
        val body = JSONObject().put("contents", JSONArray().put(JSONObject().put("parts", parts))).put("generationConfig", gc).toString()
        for (m in models.take(4)) {
            try {
                val c = URL("https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent").openConnection() as HttpURLConnection
                c.requestMethod = "POST"; c.doOutput = true; c.connectTimeout = 20000; c.readTimeout = 180000
                c.setRequestProperty("Content-Type", "application/json"); c.setRequestProperty("x-goog-api-key", g.optString("key"))
                c.outputStream.use { it.write(body.toByteArray()) }
                if (c.responseCode != 200) continue
                val j = JSONObject(c.inputStream.bufferedReader().readText())
                val ps = j.optJSONArray("candidates")?.optJSONObject(0)?.optJSONObject("content")?.optJSONArray("parts") ?: continue
                val t = (0 until ps.length()).joinToString(" ") { ps.getJSONObject(it).optString("text") }.trim()
                if (t.isNotEmpty()) return@withContext t
            } catch (_: Exception) {}
        }
        null
    }

    suspend fun askJson(prompt: String, imgs: List<Bitmap> = emptyList(), fileUris: List<String> = emptyList()): JSONObject? {
        val t = ask(prompt, imgs, fileUris, true) ?: return null
        val m = Regex("\\{[\\s\\S]*\\}").find(t) ?: return null
        return try { JSONObject(m.value) } catch (_: Exception) { null }
    }

    /** يرفع ملف الكتاب لـGemini مرة واحدة (بيفضل هناك يومين) علشان «اسأل الكتاب» يقرا الكتاب كله */
    suspend fun upload(f: File, prog: (String) -> Unit): String? = withContext(Dispatchers.IO) {
        val g = Lib.gem() ?: return@withContext null
        val gf = Lib.cfg.optJSONObject("gf") ?: JSONObject().also { Lib.cfg.put("gf", it) }
        val key = f.name + ":" + f.length()
        gf.optJSONObject(key)?.let { if (it.optLong("e") > System.currentTimeMillis()) return@withContext it.optString("u") }
        try {
            val k = g.optString("key")
            val c = URL("https://generativelanguage.googleapis.com/upload/v1beta/files").openConnection() as HttpURLConnection
            c.requestMethod = "POST"; c.doOutput = true
            c.setRequestProperty("x-goog-api-key", k)
            c.setRequestProperty("X-Goog-Upload-Protocol", "resumable"); c.setRequestProperty("X-Goog-Upload-Command", "start")
            c.setRequestProperty("X-Goog-Upload-Header-Content-Length", f.length().toString()); c.setRequestProperty("X-Goog-Upload-Header-Content-Type", "application/pdf")
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(JSONObject().put("file", JSONObject().put("display_name", "book")).toString().toByteArray()) }
            if (c.responseCode != 200) return@withContext null
            val up = c.getHeaderField("X-Goog-Upload-URL") ?: return@withContext null
            val u = URL(up).openConnection() as HttpURLConnection
            u.requestMethod = "POST"; u.doOutput = true; u.setFixedLengthStreamingMode(f.length()); u.readTimeout = 300000
            u.setRequestProperty("X-Goog-Upload-Offset", "0"); u.setRequestProperty("X-Goog-Upload-Command", "upload, finalize")
            val total = f.length()
            u.outputStream.use { out -> f.inputStream().use { inp ->
                val buf = ByteArray(256 * 1024); var sent = 0L; var last = 0L
                while (true) { val n = inp.read(buf); if (n < 0) break; out.write(buf, 0, n); sent += n
                    if (sent - last > 1048576) { last = sent; val pc = (sent * 100 / total).toInt(); withContext(Dispatchers.Main) { prog("⬆️ برفع الكتاب لـGemini أول مرة… $pc%") } } }
            } }
            if (u.responseCode != 200) return@withContext null
            val fo = JSONObject(u.inputStream.bufferedReader().readText()).getJSONObject("file")
            var state = fo.optString("state"); val name = fo.optString("name"); val uri = fo.optString("uri")
            var tries = 0
            while (state == "PROCESSING" && tries < 60) {
                withContext(Dispatchers.Main) { prog("⏳ Gemini بيجهّز الكتاب…") }
                Thread.sleep(3000); tries++
                val s = URL("https://generativelanguage.googleapis.com/v1beta/$name").openConnection() as HttpURLConnection
                s.setRequestProperty("x-goog-api-key", k)
                state = JSONObject(s.inputStream.bufferedReader().readText()).optString("state")
            }
            if (state != "ACTIVE") return@withContext null
            gf.put(key, JSONObject().put("u", uri).put("e", System.currentTimeMillis() + 44L * 3600 * 1000))
            withContext(Dispatchers.Main) { Lib.save() }
            uri
        } catch (_: Exception) { null }
    }

    /* لاقي الكتاب على أرشيف الإنترنت لوحده بالاسم والمؤلف (زي بنيان بالظبط) */
    private fun norm(t: String) = t.replace(Regex("[\u064B-\u0652\u0640]"), "").replace(Regex("[أإآ]"), "ا").replace("ة", "ه").replace("ى", "ي")
        .replace(Regex("[^\u0600-\u06FFa-zA-Z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim().lowercase()
    private fun auth(b: JSONObject) = b.optString("a").replace(Regex("^(ترجمة|تحرير)\\s*"), "").split(Regex("[،,(]"))[0].trim()
    private fun score(d: JSONObject, b: JSONObject): Double {
        val tt = d.opt("title").let { if (it is JSONArray) it.optString(0) else it?.toString() ?: "" }
        val cr = d.opt("creator").let { if (it is JSONArray) (0 until it.length()).joinToString(" ") { k -> it.optString(k) } else it?.toString() ?: "" }
        val t = norm(tt); val bt = norm(b.optString("t").replace(Regex("\\(.*\\)"), "")).trim(); val c = norm(cr); val a = norm(auth(b))
        var s = 0.0
        if (t == bt) s += 60 else if (t.contains(bt) || (bt.contains(t) && t.length > 3)) s += 35 else {
            val w = bt.split(" ").filter { it.length > 2 }; val h = w.count { t.contains(it) }; if (w.isNotEmpty()) s += Math.round(25.0 * h / w.size)
        }
        if (a.isNotEmpty()) { val aw = a.split(" ").filter { it.length > 2 }; val ah = aw.count { c.contains(it) || t.contains(it) }; if (aw.isNotEmpty()) s += Math.round(25.0 * ah / aw.size) }
        s += minOf(15.0, Math.log10(d.optDouble("downloads", 0.0) + 1) * 4)
        return s
    }
    suspend fun findIA(b: JSONObject): Boolean = withContext(Dispatchers.IO) {
        val bt = b.optString("t").replace(Regex("\\(.*\\)"), "").trim(); val au = auth(b)
        val qs = listOf("title:($bt) AND creator:($au)", "title:($bt)", "($bt $au)")
        val seen = HashSet<String>(); val docs = ArrayList<JSONObject>()
        val res = coroutineScope { qs.map { q -> async(Dispatchers.IO) { try {
            val u = "https://archive.org/advancedsearch.php?q=" + URLEncoder.encode("$q AND mediatype:texts", "UTF-8") + "&fl[]=identifier&fl[]=title&fl[]=creator&fl[]=downloads&rows=12&sort[]=downloads+desc&output=json"
            JSONObject(getText(u)).getJSONObject("response").getJSONArray("docs")
        } catch (_: Exception) { null } } }.awaitAll() }
        for (a in res) if (a != null) for (k in 0 until a.length()) { val d = a.getJSONObject(k); if (seen.add(d.optString("identifier"))) docs.add(d) }
        val best = docs.map { it to score(it, b) }.filter { it.second >= 40 }.sortedByDescending { it.second }.take(4)
        val metas = coroutineScope { best.map { (d, _) -> async(Dispatchers.IO) { try { JSONObject(getText("https://archive.org/metadata/" + URLEncoder.encode(d.optString("identifier"), "UTF-8"))) } catch (_: Exception) { null } } }.awaitAll() }
        for ((idx, pr) in best.withIndex()) try {
            val d = pr.first
            val m = metas[idx] ?: continue
            val fs = m.optJSONArray("files") ?: continue
            val l = (0 until fs.length()).map { fs.getJSONObject(it) }
                .filter { val n = it.optString("name"); n.endsWith(".pdf", true) && !n.endsWith("_text.pdf", true) && (it.optString("size").toLongOrNull() ?: 0) < 180L * 1048576 }
                .map { it.optString("name") }.sortedWith { x, y -> natural(x, y) }.take(12)
            if (l.isEmpty()) continue
            b.put("ia", d.optString("identifier")); b.put("iaf", l[0]); b.put("iaff", JSONArray(l)); b.put("iav", l.size)
            return@withContext true
        } catch (_: Exception) {}
        false
    }
}
