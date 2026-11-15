package com.bunyan.maktabati

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.os.Process
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar

/** حاجات بتشجّع على القراية: حلقات، طُعم، بدل الاسكرول، صدقة الشمعة، رفيق، طبّقها، حصالة، اقتباس كصورة */
object Boost {

    /* ───── 📸 اقتباس كصورة ───── */
    fun quoteImage(ctx: Context, text: String, b: JSONObject?): File {
        val w = 1080; val h = 1350
        val bm = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bm)
        val bg = Paint().apply { shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), intArrayOf(0xFF1F7A55.toInt(), 0xFF14513A.toInt()), null, Shader.TileMode.CLAMP) }
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bg)
        val frame = Paint().apply { color = 0x33FFE7C2; style = Paint.Style.STROKE; strokeWidth = 4f; isAntiAlias = true }
        c.drawRoundRect(50f, 50f, w - 50f, h - 50f, 40f, 40f, frame)
        val qm = Paint().apply { color = 0xFFF0A04B.toInt(); textSize = 260f; typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD); isAntiAlias = true; textAlign = Paint.Align.CENTER }
        c.drawText("”", w / 2f, 330f, qm)
        var size = 66f
        var lay: StaticLayout
        while (true) {
            val tp = TextPaint().apply { color = 0xFFFFFFFF.toInt(); textSize = size; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            lay = StaticLayout.Builder.obtain(text, 0, text.length, tp, w - 220).setAlignment(Layout.Alignment.ALIGN_CENTER).setLineSpacing(0f, 1.35f).build()
            if (lay.height < 700 || size < 34f) break
            size -= 4f
        }
        c.save(); c.translate(110f, 380f + (700 - lay.height).coerceAtLeast(0) / 2f); lay.draw(c); c.restore()
        val foot = TextPaint().apply { color = 0xFFFFE7C2.toInt(); textSize = 40f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true; textAlign = Paint.Align.CENTER }
        if (b != null) {
            c.drawText("— «" + b.optString("t") + "»", w / 2f, h - 210f, foot)
            if (b.optString("a").isNotEmpty()) c.drawText(b.optString("a"), w / 2f, h - 155f, foot.apply { textSize = 34f; color = 0xCCFFE7C2.toInt() })
        }
        c.drawText("📚 مكتبتي", w / 2f, h - 90f, TextPaint().apply { color = 0x99FFFFFF.toInt(); textSize = 30f; isAntiAlias = true; textAlign = Paint.Align.CENTER })
        val dir = File(ctx.cacheDir, "share"); dir.mkdirs()
        val f = File(dir, "quote_${System.currentTimeMillis()}.jpg")
        f.outputStream().use { bm.compress(Bitmap.CompressFormat.JPEG, 92, it) }
        return f
    }
    fun shareQuote(ctx: Context, text: String, b: JSONObject?) {
        val f = quoteImage(ctx, text, b)
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
        val i = Intent(Intent.ACTION_SEND).setType("image/jpeg").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        ctx.startActivity(Intent.createChooser(i, "شارك الاقتباس").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /* ───── 📺 الكتاب مسلسل ───── */
    fun epLen(b: JSONObject): Int { val spd = b.optInt("spd", 0); return if (spd > 0) (300 / spd).coerceIn(2, 8) else 4 }
    fun eps(b: JSONObject): List<JSONObject> = Lib.arr(b.optJSONArray("eps")).filterIsInstance<JSONObject>()
    fun epAt(b: JSONObject, p: Int): Pair<Int, JSONObject>? = eps(b).withIndex().firstOrNull { p >= it.value.optInt("f") && p <= it.value.optInt("t") }?.let { it.index to it.value }
    fun plainEps(b: JSONObject): JSONArray {
        val n = b.optInt("pg", 0); val L = epLen(b); val a = JSONArray(); var f = 1; var k = 1
        while (n > 0 && f <= n) { val t = minOf(n, f + L - 1); a.put(JSONObject().put("f", f).put("t", t).put("n", "الحلقة $k")); f = t + 1; k++ }
        return a
    }
    suspend fun genEpisodes(b: JSONObject, prog: (String) -> Unit): Boolean {
        val n = b.optInt("pg", 0); if (n <= 0) return false
        val L = epLen(b)
        if (!Net.hasGem()) { b.put("eps", plainEps(b)); Lib.save(); return true }
        val uris = ArrayList<String>()
        for (f in Lib.files(b)) { val u = Net.upload(f, prog) ?: break; uris.add(u) }
        prog("📺 بقسّم الكتاب لحلقات…")
        val j = if (uris.size == Lib.files(b).size && uris.isNotEmpty()) Net.askJson(
            "ده كتاب «${b.optString("t")}» ($n صفحة" + (if (uris.size > 1) "، مقسوم على كذا ملف بالترتيب" else "") + "). قسّمه لحلقات قصيرة زي المسلسل، كل حلقة حوالي $L صفحات (ممكن تزيد أو تقل شوية علشان الحلقة تخلص عند نهاية فكرة). " +
            "لكل حلقة اكتب عنوان قصير مشوّق بالمصري يخلّي القارئ عايز يعرف (زي: «السر اللي محدش قالهولك»)، من غير ما تحرق الفكرة. غطّي الكتاب كله من صفحة 1 لـ $n من غير فراغات. رجّع JSON بس: {\"e\":[{\"f\":1,\"t\":4,\"n\":\"العنوان\"}]}", fileUris = uris) else null
        val a = j?.optJSONArray("e")
        if (a != null && a.length() > 1) {
            val out = JSONArray(); var last = 0
            for (i in 0 until a.length()) { val e = a.optJSONObject(i) ?: continue; val f = maxOf(last + 1, e.optInt("f")); val t = minOf(n, maxOf(f, e.optInt("t"))); if (f > n) break
                out.put(JSONObject().put("f", f).put("t", t).put("n", e.optString("n").ifEmpty { "الحلقة ${out.length() + 1}" })); last = t }
            if (last < n) out.put(JSONObject().put("f", last + 1).put("t", n).put("n", "الحلقة الأخيرة"))
            b.put("eps", out)
        } else b.put("eps", plainEps(b))
        Lib.save(); return true
    }

    /* ───── 🪝 طُعم قبل ما تبدأ ───── */
    suspend fun hook(doc: Doc, b: JSONObject, p: Int): String? {
        val h = b.optJSONObject("hook"); if (h != null && h.optInt("p") == p && h.optString("t").isNotEmpty()) return h.optString("t")
        if (!Net.hasGem()) return null
        val ims = (p..minOf(doc.count, p + 2)).map { doc.render(it, 900) }
        val t = Net.ask("دي الصفحات الجاية من كتاب «${b.optString("t")}» واللي هيقراها واحد كسلان في القراية. اكتب جملة واحدة بس بالمصري (أقل من 25 كلمة) تفتح نفسه يقرا وتشغّل فضوله، تبدأ بـ «في الصفحات الجاية هتعرف…» أو حاجة شبهها، من غير ما تحرق الفكرة. الجملة بس من غير أي حاجة تانية.", ims)?.trim()?.trim('"', '«', '»')
        if (!t.isNullOrEmpty()) { b.put("hook", JSONObject().put("p", p).put("t", t)); Lib.save() }
        return t
    }

    /* ───── 📱 بدل الاسكرول ───── */
    val SOCIAL = mapOf("com.instagram.android" to "انستجرام", "com.zhiliaoapp.musically" to "تيك توك", "com.ss.android.ugc.trill" to "تيك توك",
        "com.facebook.katana" to "فيسبوك", "com.snapchat.android" to "سناب", "com.google.android.youtube" to "يوتيوب", "com.twitter.android" to "X", "com.facebook.lite" to "فيسبوك")
    fun usageOk(ctx: Context): Boolean = try {
        val ao = ctx.getSystemService(AppOpsManager::class.java)
        val m = if (Build.VERSION.SDK_INT >= 29) ao.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
                else @Suppress("DEPRECATION") ao.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        m == AppOpsManager.MODE_ALLOWED
    } catch (_: Exception) { false }
    /** كام دقيقة اسكرول في آخر [mins] دقيقة، وفين */
    fun scrollMinutes(ctx: Context, mins: Int): Pair<Int, String> {
        if (!usageOk(ctx)) return 0 to ""
        val um = ctx.getSystemService(UsageStatsManager::class.java)
        val end = System.currentTimeMillis(); val start = end - mins * 60000L
        val ev = um.queryEvents(start - 3600000L, end); val e = UsageEvents.Event()
        val openAt = HashMap<String, Long>(); val tot = HashMap<String, Long>()
        while (ev.hasNextEvent()) {
            ev.getNextEvent(e); val pk = e.packageName ?: continue; if (!SOCIAL.containsKey(pk)) continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> openAt[pk] = e.timeStamp
                UsageEvents.Event.ACTIVITY_PAUSED -> { val s = openAt.remove(pk); if (s != null) tot[pk] = (tot[pk] ?: 0) + (e.timeStamp - maxOf(s, start)).coerceAtLeast(0) }
            }
        }
        openAt.forEach { (pk, s) -> tot[pk] = (tot[pk] ?: 0) + (end - maxOf(s, start)).coerceAtLeast(0) }
        val top = tot.maxByOrNull { it.value } ?: return 0 to ""
        return (tot.values.sum() / 60000).toInt() to (SOCIAL[top.key] ?: "")
    }

    /* ───── 🤲 صدقة الشمعة ───── */
    /** لو الشمعة طفت امبارح (امبارح صفر صفحات وقبلها كنت شغال) */
    fun candleBroke(): Boolean {
        val m = Lib.dayMap(); val c = Calendar.getInstance()
        c.add(Calendar.DAY_OF_MONTH, -1); val y = Lib.ds(c.time)
        if ((m[y] ?: 0) > 0) return false
        c.add(Calendar.DAY_OF_MONTH, -1); return (m[Lib.ds(c.time)] ?: 0) > 0
    }
    fun sadaqaDue(): Boolean {
        val amt = Lib.cfg.optInt("sadaqa", 0); if (amt <= 0 || !candleBroke()) return false
        val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, -1)
        return Lib.cfg.optJSONObject("sadLog")?.has(Lib.ds(c.time)) != true
    }
    fun sadaqaDone(paid: Boolean) {
        val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, -1)
        val l = Lib.cfg.optJSONObject("sadLog") ?: JSONObject().also { Lib.cfg.put("sadLog", it) }
        l.put(Lib.ds(c.time), if (paid) Lib.cfg.optInt("sadaqa", 0) else 0); Lib.save()
    }
    fun sadaqaTotal(): Int { val l = Lib.cfg.optJSONObject("sadLog") ?: return 0; var s = 0; l.keys().forEach { s += l.optInt(it) }; return s }

    /* ───── 🎁 الحصالة: كل صفحة = درهم ───── */
    fun jar(): JSONObject? = Lib.cfg.optJSONObject("jar")?.takeIf { it.optString("n").isNotEmpty() && it.optInt("price") > 0 }
    fun jarPages(): Int { val j = jar() ?: return 0; val from = j.optString("from"); return Lib.dayMap().filter { it.key >= from }.values.sum() }

    /* ───── 🛠 طبّقها ───── */
    suspend fun genChallenge(b: JSONObject): Boolean {
        val q = Lib.arr(b.optJSONArray("q")).take(8).joinToString(" | ") { Lib.quoteText(it) }
        val s = Lib.arr(b.optJSONArray("sums")).filterIsInstance<JSONObject>().takeLast(5).joinToString(" | ") { it.optString("t") }
        val j = Net.askJson("القارئ خلّص (أو قرّب يخلّص) كتاب «${b.optString("t")}»" + (if (b.optString("a").isNotEmpty()) " لـ${b.optString("a")}" else "") +
            ". اقتباساته: $q. ملخصاته: $s. هو بيشتغل في تأجير غرف واستديوهات مفروشة في أبوظبي ومعاه شريك، وبيحاول يتعوّد على القراية. " +
            "اقترح عليه تحدي واحد بس عملي يطبقه الأسبوع ده من أهم فكرة في الكتاب ده (في حياته أو شغله). رجّع JSON بس: {\"t\":\"التحدي في جملة قصيرة\",\"how\":\"يعمل إيه بالظبط — سطرين بالمصري\",\"why\":\"الفكرة من الكتاب في سطر\"}") ?: return false
        if (j.optString("t").isEmpty()) return false
        val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, 7)
        b.put("ch", JSONObject().put("t", j.optString("t")).put("how", j.optString("how")).put("why", j.optString("why")).put("due", Lib.ds(c.time)).put("ok", false))
        Lib.save(); return true
    }

    /* ───── 💬 رفيق القراية ───── */
    fun buddyContext(): String {
        val cur = Lib.current()
        val done = Lib.books.filter { it.optString("sh") == "done" }.joinToString("، ") { "«" + it.optString("t") + "»" }
        val qs = Lib.books.flatMap { b -> Lib.arr(b.optJSONArray("q")).takeLast(3).map { "«" + Lib.quoteText(it) + "» من " + b.optString("t") } }.takeLast(6).joinToString(" | ")
        val sums = Lib.books.flatMap { b -> Lib.arr(b.optJSONArray("sums")).filterIsInstance<JSONObject>().map { it.optString("d") + " (" + b.optString("t") + "): " + it.optString("t") } }.sortedDescending().take(5).joinToString(" | ")
        return "انت «رفيق»، صاحب أسامه في القراية. بتتكلم مصري، خفيف ودمك خفيف، قصير (2-4 سطور)، ومهتم بيه بجد. أسامه بيقول إنه كسلان في القراية وانت بتشجعه من غير ما تحسسه بذنب. " +
            "اسأله سؤال واحد بس كل مرة عن اللي قراه ورأيه فيه، واربط بين الكتب والأفكار وحياته وشغله (تأجير غرف واستديوهات مفروشة في أبوظبي). " +
            "متعملش نفسك فاهم حاجة مش مكتوبة هنا.\n" +
            "دلوقتي بيقرا: " + (cur?.let { "«${it.optString("t")}» صفحة ${it.optInt("cur")} من ${it.optInt("pg")}" } ?: "مفيش") +
            ". الشمعة: ${Lib.streak()} يوم. النهارده قرا ${Lib.todayPages()} صفحة من هدف ${Lib.goal}. خلّص: ${done.ifEmpty { "لسه ولا كتاب" }}. آخر اقتباسات: $qs. آخر ملخصات قعدات: $sums."
    }
    suspend fun buddyReply(hist: List<Pair<String, String>>): String? = withContext(Dispatchers.IO) {
        val g = Lib.gem() ?: return@withContext null
        val contents = JSONArray()
        hist.takeLast(20).forEach { (role, t) -> contents.put(JSONObject().put("role", if (role == "me") "user" else "model").put("parts", JSONArray().put(JSONObject().put("text", t)))) }
        if (contents.length() == 0 || hist.last().first != "me") contents.put(JSONObject().put("role", "user").put("parts", JSONArray().put(JSONObject().put("text", "ابدأ انت الكلام وسلّم عليا واسألني سؤال عن قرايتي"))))
        val body = JSONObject().put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", buddyContext()))))
            .put("contents", contents).put("generationConfig", JSONObject().put("temperature", 0.9)).toString()
        for (m in listOf("gemini-2.5-flash", "gemini-flash-latest", "gemini-2.0-flash")) try {
            val c = URL("https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent").openConnection() as HttpURLConnection
            c.requestMethod = "POST"; c.doOutput = true; c.connectTimeout = 20000; c.readTimeout = 90000
            c.setRequestProperty("Content-Type", "application/json"); c.setRequestProperty("x-goog-api-key", g.optString("key"))
            c.outputStream.use { it.write(body.toByteArray()) }
            if (c.responseCode != 200) continue
            val ps = JSONObject(c.inputStream.bufferedReader().readText()).optJSONArray("candidates")?.optJSONObject(0)?.optJSONObject("content")?.optJSONArray("parts") ?: continue
            val t = (0 until ps.length()).joinToString(" ") { ps.getJSONObject(it).optString("text") }.trim()
            if (t.isNotEmpty()) return@withContext t
        } catch (_: Exception) {}
        null
    }
}
