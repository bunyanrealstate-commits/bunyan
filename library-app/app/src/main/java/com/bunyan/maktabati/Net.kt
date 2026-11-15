package com.bunyan.maktabati

import android.graphics.Bitmap
import android.util.Base64
import kotlinx.coroutines.Dispatchers
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

    suspend fun download(u: String, to: File, prog: (Long, Long) -> Unit) = withContext(Dispatchers.IO) {
        val c = open(u)
        if (c.responseCode >= 400) throw Exception("HTTP " + c.responseCode)
        val total = c.contentLengthLong
        val tmp = File(to.path + ".dl")
        c.inputStream.use { inp ->
            tmp.outputStream().use { out ->
                val buf = ByteArray(256 * 1024); var got = 0L; var last = 0L
                while (true) {
                    val n = inp.read(buf); if (n < 0) break
                    out.write(buf, 0, n); got += n
                    if (got - last > 512 * 1024) { last = got; withContext(Dispatchers.Main) { prog(got, total) } }
                }
            }
        }
        tmp.renameTo(to)
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
}
