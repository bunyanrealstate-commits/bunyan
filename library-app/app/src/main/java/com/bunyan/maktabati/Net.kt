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
    suspend fun gemini(prompt: String, img: Bitmap? = null): String? = withContext(Dispatchers.IO) {
        val g = Lib.gem() ?: return@withContext null
        val models = ArrayList<String>()
        g.optJSONArray("models")?.let { a -> for (i in 0 until a.length()) models.add(a.getString(i)) }
        listOf("gemini-2.5-flash", "gemini-flash-latest", "gemini-2.0-flash").forEach { if (!models.contains(it)) models.add(it) }
        val parts = JSONArray().put(JSONObject().put("text", prompt))
        if (img != null) {
            val bo = ByteArrayOutputStream(); img.compress(Bitmap.CompressFormat.JPEG, 85, bo)
            parts.put(JSONObject().put("inline_data", JSONObject().put("mime_type", "image/jpeg").put("data", Base64.encodeToString(bo.toByteArray(), Base64.NO_WRAP))))
        }
        val body = JSONObject().put("contents", JSONArray().put(JSONObject().put("parts", parts)))
            .put("generationConfig", JSONObject().put("temperature", 0)).toString()
        for (m in models.take(4)) {
            try {
                val c = URL("https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent").openConnection() as HttpURLConnection
                c.requestMethod = "POST"; c.doOutput = true; c.connectTimeout = 20000; c.readTimeout = 90000
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
}
