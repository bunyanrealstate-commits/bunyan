package com.bunyan.maktabati

import android.graphics.Bitmap
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Sheet(title: String, onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Paper, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(bottom = 30.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink)
            content()
        }
    }
}

@Composable
fun Busy(t: String) { Row(verticalAlignment = Alignment.CenterVertically) { CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = Green); Spacer(Modifier.width(10.dp)); Text(t, color = Muted) } }

@Composable
fun Bubble(t: String, mine: Boolean = false) {
    Surface(shape = RoundedCornerShape(16.dp), color = if (mine) Green else Card, modifier = Modifier.fillMaxWidth()) {
        SelectionContainer { Text(t, Modifier.padding(12.dp), color = if (mine) Color.White else Ink, fontSize = 15.sp, lineHeight = 26.sp, fontWeight = if (mine) FontWeight.Bold else FontWeight.Normal) }
    }
}

fun tomorrow(): String { val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, 1); return Lib.ds(c.time) }

private val PAGE_RE = Regex("\\(ص\\.? ?(\\d+)\\)")

/** أدوات Gemini جوه الكتاب: اشرحلي / كلمة / اسأل الكتاب / أفكار لشغلي / احفظ اقتباس */
@Composable
fun AiSheet(kind: String, b: JSONObject, doc: Doc, cur: Int, onGo: (Int) -> Unit, onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf("") }
    var out by remember { mutableStateOf<String?>(null) }
    var q by remember { mutableStateOf("") }
    val chat = remember { mutableStateListOf<Pair<String, String>>() }
    var ideas by remember { mutableStateOf<List<JSONObject>?>(null) }
    var sents by remember { mutableStateOf<List<String>?>(null) }
    val saved = remember { mutableStateListOf<String>() }
    var uris by remember { mutableStateOf<List<String>?>(null) }
    val title = mapOf("explain" to "💡 اشرحلي الصفحة", "word" to "🔤 كلمة أو جملة مش فاهمها", "ask" to "💬 اسأل الكتاب", "ideas" to "💼 أفكار من الكتاب لشغلك", "quote" to "💬 احفظ اقتباس", "find" to "🔎 دوّر جوه الكتاب")[kind] ?: ""
    var found by remember { mutableStateOf<List<JSONObject>?>(null) }
    suspend fun img(p: Int, w: Int = 1300): Bitmap = doc.render(p, w)

    LaunchedEffect(kind) {
        when (kind) {
            "explain" -> { busy = "⏳ بقرا الصفحة…"; out = Net.ask("دي صفحة من كتاب «${b.optString("t")}». اشرحها لواحد بيتعلم يقرا وكسلان شوية: الفكرة الأساسية في سطرين، وبعدين أهم 3 نقط بالمصري البسيط، ولو فيه كلمات صعبة اشرحها في الآخر. من غير مقدمات.", listOf(img(cur))) ?: "⚠️ مقدرتش أشرح دلوقتي — اتأكد من النت"; busy = "" }
            "ideas" -> {
                busy = "⏳ بقرا آخر صفحات وبطلّع منها أفكار…"
                val ims = (maxOf(1, cur - 2)..cur).map { img(it, 1100) }
                val j = Net.askJson("دي صفحات من كتاب «${b.optString("t")}». القارئ عنده شغل: بيأجر غرف واستديوهات وشقق فاضية من شركات في أبوظبي، يفرشها ويأجرها شهري، وبيسوّق على انستجرام، ومعاه شريك. طلّع من الصفحات 3 أفكار عملية يقدر يطبقها في شغله ده الأسبوع ده (لو الكلام مالوش علاقة بالشغل طلّع أفكار تنفعه في حياته وتنظيم وقته). رجّع JSON بس: {\"ideas\":[{\"t\":\"عنوان في 6 كلمات\",\"how\":\"يعمل إيه بالظبط — سطر بالمصري\"}]}", ims)
                ideas = j?.optJSONArray("ideas")?.let { a -> (0 until a.length()).map { a.getJSONObject(it) } } ?: emptyList(); busy = ""
            }
            "quote" -> {
                busy = "⏳ بدوّر على أحلى جمل في الصفحة…"
                val j = Net.askJson("دي صفحة من كتاب. اكتب أحلى وأهم 6 جمل فيها (حكم أو أفكار مؤثرة) بالظبط زي ما هي مكتوبة، كل جملة كاملة لوحدها. رجّع JSON بس: {\"s\":[\"جملة\",\"جملة\"]}", listOf(img(cur)))
                sents = j?.optJSONArray("s")?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList(); busy = ""
            }
        }
    }

    Sheet(title, onDismiss) {
        if (!Net.hasGem()) { Text("⚠️ محتاج Gemini — اربط التطبيق بحساب بنيان الأول", color = Color(0xFFB3261E)); return@Sheet }
        when (kind) {
            "explain" -> out?.let { Bubble(it) }
            "word" -> {
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("اكتب الكلمة أو الجملة") }, shape = RoundedCornerShape(14.dp))
                Button({ if (q.isNotBlank() && busy.isEmpty()) scope.launch { busy = "⏳ بشرح…"; out = Net.ask("في الصفحة دي من كتاب «${b.optString("t")}»، اشرح «${q.trim()}» بالمصري البسيط: معناها وقصد الكاتب بيها هنا، في سطور قليلة.", listOf(img(cur))) ?: "⚠️ مقدرتش دلوقتي"; busy = "" } },
                    Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("اشرحلي") }
                out?.let { Bubble(it) }
            }
            "ask" -> {
                if (chat.isEmpty()) Text("اسأل أي حاجة عن «${b.optString("t")}» — هجاوبك من الكتاب نفسه وأقولك في صفحة كام.", color = Muted, fontSize = 13.sp)
                chat.forEach { (qq, aa) ->
                    Bubble(qq, true); Bubble(aa)
                    val pages = PAGE_RE.findAll(aa).map { it.groupValues[1].toInt() }.distinct().take(6).toList()
                    if (pages.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { pages.forEach { p -> Chip("ص $p", false) { onGo(p); onDismiss() } } }
                }
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("مثلاً: الكاتب قال إيه عن الصبر؟") }, shape = RoundedCornerShape(14.dp))
                Button({
                    val question = q.trim(); if (question.isEmpty() || busy.isNotEmpty()) return@Button
                    q = ""
                    scope.launch {
                        if (uris == null) {
                            val l = ArrayList<String>()
                            for (f in Lib.files(b)) { val u = Net.upload(f) { busy = it }; if (u == null) { l.clear(); break }; l.add(u) }
                            uris = l
                        }
                        busy = "⏳ بدوّر في الكتاب…"
                        val hist = chat.joinToString(" | ") { it.first }
                        val pr = "انت مساعد قراية. ده كتاب «${b.optString("t")}»" + (if ((uris ?: emptyList()).isEmpty()) " (دي صور آخر صفحات قراها بس، أرقامها من ${maxOf(1, cur - 5)} لـ $cur)" else if ((uris?.size ?: 0) > 1) " (مقسوم على كذا ملف بالترتيب، ورقم الصفحة = ترتيبها في الملفات كلها ورا بعض)" else "") +
                                ".\nجاوب على السؤال من الكتاب ده بس، بالعربي السهل القريب من المصري، في سطور قليلة، واذكر أرقام الصفحات كده (ص 12). لو الإجابة مش في الكتاب قول كده بصراحة.\n" + (if (hist.isNotEmpty()) "الأسئلة اللي فاتت: $hist\n" else "") + "السؤال: $question"
                        val a = if ((uris ?: emptyList()).isNotEmpty()) Net.ask(pr, fileUris = uris!!) else Net.ask(pr, (maxOf(1, cur - 5)..cur).map { img(it, 1000) })
                        chat.add(question to (a ?: "⚠️ مقدرتش أجاوب دلوقتي — اتأكد من النت")); busy = ""
                    }
                }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("اسأل") }
            }
            "ideas" -> ideas?.let { l ->
                if (l.isEmpty()) Text("⚠️ مقدرتش أطلّع أفكار دلوقتي", color = Muted)
                l.forEachIndexed { i, x ->
                    Surface(shape = RoundedCornerShape(16.dp), color = Card) { Column(Modifier.padding(12.dp)) {
                        Text("${i + 1}. " + x.optString("t"), fontWeight = FontWeight.Bold, color = Ink, fontSize = 15.sp)
                        Text(x.optString("how"), color = Ink, fontSize = 13.sp, lineHeight = 22.sp, modifier = Modifier.padding(vertical = 6.dp))
                        val done = saved.contains(x.optString("t"))
                        Chip(if (done) "✅ هفكّرك بكره 10 الصبح" else "⏰ فكّرني بكره الصبح", done) {
                            if (!done) { Lib.addRem("💡 " + x.optString("t"), x.optString("how") + " — من كتاب «${b.optString("t")}»", tomorrow(), "10:00"); saved.add(x.optString("t"))
                                Toast.makeText(ctx, "هيوصلك في تذكيراتي في بنيان", Toast.LENGTH_SHORT).show() }
                        }
                    } }
                }
            }
            "find" -> {
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("كلمة أو موضوع… مثلاً: الصبر") }, singleLine = true, shape = RoundedCornerShape(14.dp))
                Button({
                    val w = q.trim(); if (w.isEmpty() || busy.isNotEmpty()) return@Button
                    scope.launch {
                        if (uris == null) { val l = ArrayList<String>(); for (f in Lib.files(b)) { val u = Net.upload(f) { busy = it }; if (u == null) { l.clear(); break }; l.add(u) }; uris = l }
                        busy = "⏳ بدوّر في الكتاب كله…"
                        val pr = "ده كتاب «${b.optString("t")}»" + (if ((uris?.size ?: 0) > 1) " مقسوم على كذا ملف بالترتيب (رقم الصفحة = ترتيبها في الملفات كلها ورا بعض)" else "") +
                            ". لاقي كل الصفحات اللي فيها «$w» أو بتتكلم عنه (لحد 15 صفحة)، ولكل صفحة اكتب جملة قصيرة منها بالظبط. رجّع JSON بس: {\"r\":[{\"p\":12,\"s\":\"الجملة\"}]}"
                        val j = if (!uris.isNullOrEmpty()) Net.askJson(pr, fileUris = uris!!) else null
                        found = j?.optJSONArray("r")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it) }.filter { it.optInt("p") > 0 } } ?: emptyList()
                        busy = ""
                    }
                }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("🔎 دوّر") }
                found?.let { l ->
                    if (l.isEmpty()) Text("ملقتش حاجة — جرّب كلمة تانية", color = Muted)
                    l.forEach { x -> Surface(onClick = { onGo(x.optInt("p")); onDismiss() }, shape = RoundedCornerShape(14.dp), color = Card, modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(12.dp)) { Text("📄 صفحة ${x.optInt("p")}", fontWeight = FontWeight.Bold, color = Green); Text(x.optString("s"), color = Ink, lineHeight = 22.sp) }
                    } }
                }
            }
            "quote" -> {
                sents?.let { l ->
                    if (l.isEmpty()) Text("⚠️ مقدرتش أقرا الصفحة دي دلوقتي", color = Muted)
                    l.forEach { s ->
                        val done = saved.contains(s)
                        Surface(onClick = { if (!done) { Lib.addQuote(b, s, cur); saved.add(s) } }, shape = RoundedCornerShape(14.dp), color = if (done) soft(0xFFE8F3EE) else Card) {
                            Column(Modifier.padding(12.dp)) {
                                Text((if (done) "✅ " else "💾 ") + "«$s»", color = Ink, lineHeight = 24.sp)
                                if (done) Chip("📸 شاركه صورة", false) { Boost.shareQuote(ctx, s, b) }
                            }
                        }
                    }
                }
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("أو اكتب الاقتباس بنفسك") }, shape = RoundedCornerShape(14.dp))
                OutlinedButton({ if (q.isNotBlank()) { Lib.addQuote(b, q, cur); saved.add(q); q = ""; Toast.makeText(ctx, "💬 اتحفظ", Toast.LENGTH_SHORT).show() } }, Modifier.fillMaxWidth()) { Text("💾 احفظ") }
            }
        }
        if (busy.isNotEmpty()) Busy(busy)
    }
}

/** ملخص الجلسة + 3 أسئلة بعد ما تقفل الكتاب */
@Composable
fun RecapSheet(b: JSONObject, from: Int, to: Int, onDismiss: () -> Unit) {
    var sum by remember { mutableStateOf<String?>(null) }
    var qs by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var fail by remember { mutableStateOf(false) }
    var qi by remember { mutableIntStateOf(0) }
    var ok by remember { mutableIntStateOf(0) }
    var picked by remember { mutableIntStateOf(-1) }
    LaunchedEffect(Unit) {
        val pages = (maxOf(from, to - 5)..to).toList()
        val doc = try { Doc(Lib.files(b)) } catch (_: Exception) { null }
        val ims = doc?.let { d -> pages.filter { it in 1..d.count }.map { d.render(it, 1100) } } ?: emptyList()
        doc?.close()
        val j = if (ims.isEmpty()) null else Net.askJson("دي صفحات $from لـ $to من كتاب «${b.optString("t")}». رجّع JSON بس بالشكل ده: {\"sum\":\"ملخص في 3 سطور قصيرة بالعربي السهل القريب من المصري\",\"qs\":[{\"q\":\"سؤال قصير عن الفهم\",\"o\":[\"اختيار\",\"اختيار\",\"اختيار\"],\"a\":0}]} — 3 أسئلة، كل سؤال 3 اختيارات، و a رقم الإجابة الصح.", ims)
        if (j == null || j.optString("sum").isEmpty()) { fail = true; return@LaunchedEffect }
        sum = j.optString("sum")
        val a = j.optJSONArray("qs") ?: JSONArray()
        qs = (0 until a.length()).map { a.getJSONObject(it) }.filter { (it.optJSONArray("o")?.length() ?: 0) > 1 }.take(3)
        Lib.addSum(b, JSONObject().put("d", Lib.today()).put("p", JSONArray().put(from).put(to)).put("t", sum).put("qs", JSONArray(qs)))
    }
    Sheet("📝 اللي قريته النهارده", onDismiss) {
        when {
            fail -> Text("⚠️ مقدرتش أعمل الملخص دلوقتي", color = Muted)
            sum == null -> Busy("⏳ بجهّزلك ملخص صغير…")
            else -> {
                Surface(shape = RoundedCornerShape(14.dp), color = soft(0xFFFFF4E0)) { Text(sum!!, Modifier.padding(12.dp), fontWeight = FontWeight.Bold, lineHeight = 26.sp, color = Ink) }
                if (qs.isNotEmpty()) {
                    if (qi < qs.size) {
                        val x = qs[qi]; val o = x.optJSONArray("o")!!; val ans = x.optInt("a")
                        Text("❓ سؤال ${qi + 1} من ${qs.size}: " + x.optString("q"), fontWeight = FontWeight.Bold, color = Ink, lineHeight = 24.sp)
                        for (i in 0 until o.length()) {
                            val col = when { picked < 0 -> Card; i == ans -> soft(0xFFE9F7EF); i == picked -> soft(0xFFFDECEC); else -> Card }
                            Surface(onClick = { if (picked < 0) { picked = i; if (i == ans) ok++ } }, shape = RoundedCornerShape(12.dp), color = col, modifier = Modifier.fillMaxWidth()) { Text(o.getString(i), Modifier.padding(12.dp), fontWeight = FontWeight.Bold, color = Ink) }
                        }
                        if (picked >= 0) Button({ picked = -1; qi++ }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text(if (qi + 1 < qs.size) "السؤال اللي بعده" else "النتيجة") }
                    } else Text(if (ok == qs.size) "🏆 جاوبت صح على كله — عاش!" else "✅ جاوبت $ok من ${qs.size} صح", Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontWeight = FontWeight.Black, fontSize = 17.sp, color = Green)
                }
            }
        }
    }
}

/* ───── مراجعة ذكية (تكرار متباعد) ───── */
private val IV = listOf(1, 3, 7, 21, 60, 150)
data class RevItem(val k: String, val kind: String, val t: String, val b: JSONObject, val p: Int, val q: JSONObject? = null)

fun revItems(): List<RevItem> {
    val l = ArrayList<RevItem>()
    Lib.books.forEach { b ->
        b.optJSONArray("q")?.let { a -> for (i in 0 until a.length()) { val x = a.get(i); val t = Lib.quoteText(x); if (t.length > 8) l.add(RevItem("q:${b.optString("id")}:$i", "q", t, b, (x as? JSONObject)?.optInt("p") ?: 0)) } }
        b.optJSONArray("sums")?.let { a -> for (i in 0 until a.length()) { val s = a.optJSONObject(i) ?: continue
            s.optJSONArray("qs")?.let { qa -> for (j in 0 until qa.length()) { val q = qa.optJSONObject(j) ?: continue; if (q.has("q") && q.has("o")) l.add(RevItem("s:${b.optString("id")}:$i:$j", "s", q.optString("q"), b, 0, q)) } }
            if (s.optString("t").isNotEmpty()) l.add(RevItem("m:${b.optString("id")}:$i", "m", s.optString("t"), b, s.optJSONArray("p")?.optInt(1) ?: 0))
        } }
    }
    return l
}
fun revDue(): List<RevItem> {
    val rev = Lib.cfg.optJSONObject("rev") ?: JSONObject().also { Lib.cfg.put("rev", it) }
    val t = Lib.today(); val all = revItems()
    val old = all.filter { rev.optJSONObject(it.k)?.let { r -> r.optString("due") <= t } == true }
    val newToday = rev.keys().asSequence().count { rev.optJSONObject(it)?.optString("f") == t }
    return old + all.filter { !rev.has(it.k) }.take(maxOf(0, 3 - newToday))
}
fun revMark(x: RevItem, ok: Boolean) {
    val rev = Lib.cfg.optJSONObject("rev") ?: JSONObject().also { Lib.cfg.put("rev", it) }
    val r = rev.optJSONObject(x.k) ?: JSONObject().put("n", -1).put("f", Lib.today())
    val n = if (ok) minOf(IV.size - 1, r.optInt("n") + 1) else 0
    r.put("n", n); val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, if (ok) IV[n] else 1); r.put("due", Lib.ds(c.time))
    rev.put(x.k, r); Lib.save()
}

@Composable
fun ReviewCard() {
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val due = remember(Lib.ver) { revDue() }
    if (due.isEmpty()) return
    val x = due[0]
    var picked by remember(x.k) { mutableIntStateOf(-1) }
    val ctx = LocalContext.current
    Surface(shape = RoundedCornerShape(20.dp), color = soft(0xFFFFF7E8), modifier = Modifier.border(1.dp, soft(0xFFF0D9B5), RoundedCornerShape(20.dp))) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row { Text("🧠 افتكر اللي قريته", fontWeight = FontWeight.Bold, color = Ink, modifier = Modifier.weight(1f)); Text("${due.size} للمراجعة", color = Muted, fontSize = 11.sp) }
            if (x.kind == "s" && x.q != null) {
                Text(x.t, fontWeight = FontWeight.Bold, color = Ink, lineHeight = 24.sp)
                val o = x.q.optJSONArray("o")!!; val ans = x.q.optInt("a")
                for (i in 0 until o.length()) {
                    val col = when { picked < 0 -> Card; i == ans -> soft(0xFFE9F7EF); i == picked -> soft(0xFFFDECEC); else -> Card }
                    Surface(onClick = { if (picked < 0) { picked = i; Lib.bg.launch { kotlinx.coroutines.delay(if (i == ans) 700 else 1600); revMark(x, i == ans) } } }, shape = RoundedCornerShape(12.dp), color = col, modifier = Modifier.fillMaxWidth()) { Text(o.getString(i), Modifier.padding(10.dp), color = Ink) }
                }
            } else {
                Text(if (x.kind == "q") "«${x.t}»" else x.t, fontWeight = FontWeight.Bold, color = Ink, lineHeight = 26.sp, fontSize = 15.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Chip("👍 فاكرها", false) { revMark(x, true); Toast.makeText(ctx, "👍 هرجعهالك بعد كام يوم", Toast.LENGTH_SHORT).show() }
                    Chip("🔁 فكّرني تاني", false) { revMark(x, false) }
                }
            }
            Text("من «${x.b.optString("t")}»" + (if (x.p > 0) " — ص ${x.p}" else ""), color = Muted, fontSize = 11.sp)
        }
    }
}

/* ───── إحصائيات + إنجازات + تقرير الأسبوع ───── */
data class Badge(val k: String, val ic: String, val t: String, val ok: (Int, Int, Int, Int) -> Boolean)
val BADGES = listOf(
    Badge("b1", "📗", "أول كتاب") { d, _, _, _ -> d >= 1 }, Badge("b3", "📚", "3 كتب") { d, _, _, _ -> d >= 3 }, Badge("b10", "🏛", "10 كتب") { d, _, _, _ -> d >= 10 },
    Badge("s3", "🔥", "3 أيام ورا بعض") { _, s, _, _ -> s >= 3 }, Badge("s7", "🔥", "أسبوع كامل") { _, s, _, _ -> s >= 7 }, Badge("s30", "🌟", "شهر من غير ما تقطع") { _, s, _, _ -> s >= 30 },
    Badge("p100", "📄", "100 صفحة") { _, _, p, _ -> p >= 100 }, Badge("p500", "📜", "500 صفحة") { _, _, p, _ -> p >= 500 }, Badge("p1k", "🎓", "1000 صفحة") { _, _, p, _ -> p >= 1000 },
    Badge("q5", "💬", "5 اقتباسات") { _, _, _, q -> q >= 5 })

fun bestStreak(): Int {
    val ks = Lib.dayMap().filter { it.value > 0 }.keys.sorted(); var best = 0; var c = 0; var pv: Date? = null
    val f = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
    ks.forEach { k -> val d = f.parse(k) ?: return@forEach; c = if (pv != null && Math.round((d.time - pv!!.time) / 864e5) == 1L) c + 1 else 1; if (c > best) best = c; pv = d }
    return best
}

@Composable
fun StatsAndBadges() {
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val m = Lib.dayMap()
    val c = Calendar.getInstance(); var week = 0
    repeat(7) { week += m[Lib.ds(c.time)] ?: 0; c.add(Calendar.DAY_OF_MONTH, -1) }
    val yr = Calendar.getInstance().get(Calendar.YEAR).toString()
    val doneY = Lib.books.count { it.optString("sh") == "done" && it.optString("fd").startsWith(yr) }
    val done = Lib.books.count { it.optString("sh") == "done" }
    val total = m.values.sum(); val best = bestStreak()
    val quotes = Lib.books.sumOf { it.optJSONArray("q")?.length() ?: 0 }
    val got = Lib.cfg.optJSONObject("badges") ?: JSONObject().also { Lib.cfg.put("badges", it) }
    var fresh by remember { mutableStateOf<List<Badge>>(emptyList()) }
    LaunchedEffect(done, best, total, quotes) {
        val nw = BADGES.filter { it.ok(done, best, total, quotes) && !got.has(it.k) }
        if (nw.isNotEmpty()) { nw.forEach { got.put(it.k, Lib.today()) }; Lib.save(); fresh = nw }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("$week" to "صفحة الأسبوع ده", "$doneY" to "كتاب السنة دي", "$total" to "صفحة لحد دلوقتي").forEach { (n, l) ->
            Surface(shape = RoundedCornerShape(16.dp), color = Card, modifier = Modifier.weight(1f)) {
                Column(Modifier.padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(n, fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink); Text(l, fontSize = 10.sp, color = Muted, fontWeight = FontWeight.Bold) }
            }
        }
    }
    Spacer(Modifier.height(10.dp))
    Surface(shape = RoundedCornerShape(20.dp), color = Card) {
        Column(Modifier.padding(14.dp)) {
            Row { Text("🏅 إنجازاتي", fontWeight = FontWeight.Bold, color = Ink, modifier = Modifier.weight(1f)); Text("${got.length()} من ${BADGES.size}", color = Muted, fontSize = 12.sp) }
            Spacer(Modifier.height(8.dp))
            BADGES.chunked(5).forEach { row ->
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    row.forEach { bd -> val on = got.has(bd.k)
                        Column(Modifier.weight(1f).alpha(if (on) 1f else 0.3f), horizontalAlignment = Alignment.CenterHorizontally) {
                            Box(Modifier.size(44.dp).clip(CircleShape).background(if (on) soft(0xFFFFE7C2) else Sand), Alignment.Center) { Text(bd.ic, fontSize = 22.sp) }
                            Text(bd.t, fontSize = 9.sp, textAlign = TextAlign.Center, color = Muted, fontWeight = FontWeight.Bold, lineHeight = 12.sp)
                        }
                    }
                }
            }
        }
    }
    if (fresh.isNotEmpty()) AlertDialog(onDismissRequest = { fresh = emptyList() }, confirmButton = { TextButton({ fresh = emptyList() }) { Text("كمّل كدا 💪") } },
        title = { Text("🏅 إنجاز جديد!", fontWeight = FontWeight.Black) },
        text = { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) { fresh.forEach { Column(horizontalAlignment = Alignment.CenterHorizontally) { Text(it.ic, fontSize = 42.sp); Text(it.t, fontWeight = FontWeight.Bold) } } } })
}

@Composable
fun WeeklyReport() {
    val c = Calendar.getInstance()
    val back = (c.get(Calendar.DAY_OF_WEEK) - Calendar.FRIDAY + 7) % 7
    c.add(Calendar.DAY_OF_MONTH, -back)
    val key = Lib.ds(c.time)
    if (Lib.cfg.optString("wk") == key) return
    val m = Lib.dayMap(); var pg = 0; var days = 0; var prev = 0; var bp = 0; var bd: Date? = null
    val x = c.clone() as Calendar
    repeat(7) { val v = m[Lib.ds(x.time)] ?: 0; pg += v; if (v > 0) { days++; if (v > bp) { bp = v; bd = x.time } }; x.add(Calendar.DAY_OF_MONTH, -1) }
    repeat(7) { prev += m[Lib.ds(x.time)] ?: 0; x.add(Calendar.DAY_OF_MONTH, -1) }
    var show by remember { mutableStateOf(true) }
    if (pg == 0 && prev == 0) { Lib.cfg.put("wk", key); return }
    if (!show) return
    fun close() { Lib.cfg.put("wk", key); Lib.save(); show = false }
    AlertDialog(onDismissRequest = { close() }, confirmButton = { TextButton({ close() }) { Text("تمام") } },
        title = { Text("📊 تقرير الأسبوع", fontWeight = FontWeight.Black) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("$pg" to "صفحة", "$days/7" to "أيام قريت فيها").forEach { (n, l) -> Surface(shape = RoundedCornerShape(12.dp), color = soft(0xFFFFF4E0), modifier = Modifier.weight(1f)) { Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(n, fontWeight = FontWeight.Black, fontSize = 22.sp); Text(l, fontSize = 11.sp, color = Muted) } } }
            }
            Text(if (prev == 0) "بداية حلوة 👏" else if (pg >= prev) "📈 قريت أكتر من الأسبوع اللي فات ($prev صفحة) — عاش!" else "📉 الأسبوع اللي فات قريت $prev صفحة — يلا نعوّضها", fontWeight = FontWeight.Bold, lineHeight = 24.sp)
            bd?.let { Text("⭐ أحسن يوم: " + java.text.SimpleDateFormat("EEEE", java.util.Locale("ar")).format(it) + " ($bp صفحة)") }
        } })
}

/* ───── رشّحلي الكتاب الجاي ───── */
/** 👥 زي Goodreads «اللي حبّوا الكتاب ده حبّوا كمان» — لو متحدد، الترشيح بيبقى حوالين الكتاب ده */
var recSeed: JSONObject? = null

@Composable
fun RecommendSheet(onDismiss: () -> Unit, onSearch: (String) -> Unit) {
    var res by remember { mutableStateOf<List<JSONObject>?>(null) }
    val seed = remember { recSeed.also { recSeed = null } }
    LaunchedEffect(Unit) {
        if (seed != null) {
            val j = Net.askJson("زي قسم «Readers also enjoyed» في Goodreads: اللي حبّوا كتاب «${seed.optString("t")}»" + (if (seed.optString("a").isNotEmpty()) " لـ${seed.optString("a")}" else "") +
                (if (seed.has("r")) " (القارئ ده ادّاه ${seed.optInt("r")}/5)" else "") + " حبّوا كمان إيه؟ رشّح 5 كتب حقيقية ومشهورة ومتقيّمة عالي على Goodreads، يفضّل عربي أو مترجم للعربي، وسهلة لواحد لسه بيتعوّد على القراية. " +
                "رجّع JSON بس: {\"r\":[{\"t\":\"اسم الكتاب بالعربي\",\"a\":\"المؤلف\",\"why\":\"ليه هيعجبه — سطر واحد بالمصري\"}]}")
            res = j?.optJSONArray("r")?.let { a -> (0 until a.length()).map { a.getJSONObject(it) } } ?: emptyList()
            return@LaunchedEffect
        }
        val done = Lib.books.filter { it.optString("sh") == "done" }; val want = Lib.books.filter { it.optString("sh") == "want" }.take(40)
        val pr = "ده شخص بيحاول يتعوّد على القراية (بيقول إنه كسول). الكتب اللي خلصها وتقييمه: " + (done.joinToString("، ") { "«" + it.optString("t") + "» " + (if (it.has("r")) it.optInt("r").toString() + "/5" else "") }.ifEmpty { "لسه مخلصش" }) +
                ". الكتب اللي في قايمته: " + want.joinToString("، ") { "«" + it.optString("t") + "»" } + ". اختار 3 كتب من قايمته يبدأ بيها بالترتيب (الأسهل والأمتع الأول) ولو مفيش كفاية رشّح كتب عربية سهلة ومشهورة. رجّع JSON بس: {\"r\":[{\"t\":\"اسم الكتاب\",\"a\":\"المؤلف\",\"why\":\"ليه — سطر واحد بالمصري\"}]}"
        val j = Net.askJson(pr)
        var l = j?.optJSONArray("r")?.let { a -> (0 until a.length()).map { a.getJSONObject(it) } } ?: emptyList()
        if (l.isEmpty()) l = want.filter { it.optInt("pg") in 1..250 }.ifEmpty { want }.take(3).map { JSONObject().put("t", it.optString("t")).put("a", it.optString("a")).put("why", "من قايمتك") }
        res = l
    }
    Sheet(if (seed != null) "👥 اللي حبّوا «${seed.optString("t")}» حبّوا كمان" else "✨ أقرأ إيه بعد كده؟", onDismiss) {
        val l = res
        if (l != null && l.isEmpty()) Text("⚠️ مقدرتش أجيب ترشيحات دلوقتي — اتأكد من النت", color = Muted)
        if (l == null) Busy("⏳ بفكّر في أنسب كتاب ليك…") else l.take(if (seed != null) 5 else 3).forEachIndexed { i, r ->
            val mine = Lib.books.firstOrNull { it.optString("t") == r.optString("t") }
            Surface(shape = RoundedCornerShape(16.dp), color = Card) { Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("${i + 1}. " + r.optString("t"), fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Ink)
                if (r.optString("a").isNotEmpty()) Text(r.optString("a"), color = Muted, fontSize = 12.sp)
                Text(r.optString("why"), fontSize = 13.sp, color = Ink, lineHeight = 22.sp)
                if (mine != null) Chip("⏫ خليه الكتاب الجاي", false) { Lib.queue.remove(mine.optString("id")); Lib.queue.add(0, mine.optString("id")); Lib.save(); onDismiss() }
                else Chip("🔎 دوّر عليه ونزّله", false) { onSearch(r.optString("t")) }
            } }
        }
    }
}

@Composable
fun NotesSheet(b: JSONObject, onDismiss: () -> Unit) {
    Sheet("💬 اقتباساتي وملخصاتي — ${b.optString("t")}", onDismiss) {
        val q = b.optJSONArray("q"); val s = b.optJSONArray("sums")
        if ((q?.length() ?: 0) == 0 && (s?.length() ?: 0) == 0) Text("لسه مفيش — جوه الكتاب دوس 💡 ← «احفظ اقتباس»، والملخص بيتعمل لوحده لما تقفل بعد ما تقرا صفحتين.", color = Muted, lineHeight = 22.sp)
        val nctx = LocalContext.current
        q?.let { for (i in 0 until it.length()) { val x = it.get(i); Bubble("«" + Lib.quoteText(x) + "»" + ((x as? JSONObject)?.optInt("p")?.takeIf { p -> p > 0 }?.let { p -> "  — ص $p" } ?: ""))
            Chip("📸 شاركه صورة (ستوري / حالة)", false) { Boost.shareQuote(nctx, Lib.quoteText(x), b) } } }
        b.optJSONArray("hl")?.takeIf { it.length() > 0 }?.let { h -> Text("🖍 تعليماتي: " + (0 until h.length()).mapNotNull { h.optJSONObject(it)?.optInt("p") }.distinct().sorted().joinToString("، ") { "ص $it" }, color = Muted, fontSize = 13.sp) }
        s?.let { for (i in 0 until it.length()) { val x = it.optJSONObject(i) ?: continue; Text("📝 " + x.optString("d"), color = Muted, fontSize = 12.sp); Bubble(x.optString("t")) } }
    }
}

@Composable
fun SettingsSheet(onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    fun set(k: String, x: Any) { Lib.cfg.put(k, x); Lib.save(); Notify.schedule(ctx) }
    Sheet("🎯 هدفك والتذكيرات", onDismiss) {
        listOf(true to "🖼 شكل التطبيق", false to "🎨 أو لون بس").forEach { (sk, lbl) ->
        Text(lbl, fontWeight = FontWeight.Bold, color = Ink)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Themes.all.filter { it.skin == sk }.forEach { t -> val on = Themes.id == t.id
                Column(Modifier.clickable { Themes.set(t.id) }.width(if (sk) 96.dp else 78.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(58.dp).clip(RoundedCornerShape(16.dp)).background(Color(t.paper))
                        .border(if (on) 3.dp else 1.dp, if (on) Color(t.main) else Color(0x22000000), RoundedCornerShape(16.dp)), Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Box(Modifier.size(30.dp, 9.dp).clip(CircleShape).background(Color(t.main)))
                            Box(Modifier.size(22.dp, 6.dp).clip(CircleShape).background(Color(t.sand)))
                            if (on) Text("✓", color = Color(t.main), fontWeight = FontWeight.Black, fontSize = 12.sp)
                        }
                    }
                    Text(t.name, fontSize = 11.sp, color = Ink, fontWeight = if (on) FontWeight.Bold else FontWeight.Normal, maxLines = 2, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 4.dp))
                }
            }
        }
        }
        val uctx = LocalContext.current; val uscope = rememberCoroutineScope()
        OutlinedButton({ uscope.launch { Toast.makeText(uctx, Updater.check(uctx, true) ?: "", Toast.LENGTH_LONG).show() } }, Modifier.fillMaxWidth()) { Text("⬆️ شوف لو فيه تحديث للتطبيق (نسختك ${Updater.myVersion(uctx)})") }
        Text("هدفك كل يوم (صفحات)", fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(1, 5, 10, 15, 20, 30).forEach { g -> Chip(if (g == 1) "1️⃣ تحدي" else "$g", Lib.goal == g) { Lib.goal = g; Lib.save() } } }
        if (Lib.goal == 1) Text("1️⃣ تحدي الصفحة الواحدة: أصعب حاجة البداية — صفحة واحدة بس، وغالباً هتكمّل لوحدك.", color = Muted, fontSize = 13.sp, lineHeight = 20.sp)
        HorizontalDivider()
        Row(verticalAlignment = Alignment.CenterVertically) { Text("🔔 فكّرني بالليل لو لسه مكملتش هدفي", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("eve", true), { set("eve", it) }) }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf("20:00", "21:30", "22:30", "23:30").forEach { t -> Chip(t, Lib.cfg.optString("eveT", "21:30") == t) { set("eveT", t) } } }
        HorizontalDivider()
        Row(verticalAlignment = Alignment.CenterVertically) { Text("⚡ ابعتلي فقرة من كتابي كل يوم", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("para", true), { set("para", it) }) }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf("08:00", "13:00", "17:00", "19:00").forEach { t -> Chip(t, Lib.cfg.optString("paraT", "13:00") == t) { set("paraT", t) } } }
        OutlinedButton({ Notify.post(ctx, 9299, "🔔 تجربة", "التذكيرات شغالة ✅", null) }, Modifier.fillMaxWidth()) { Text("🔔 جرّب إشعار دلوقتي") }
        MoreSettings()
    }
}


/* ───── ⭐ تقييم الكتاب (زي Goodreads) ───── */
@Composable
fun Stars(n: Int, size: Int = 30, onPick: ((Int) -> Unit)? = null) {
    Row { (1..5).forEach { i -> Text(if (i <= n) "★" else "☆", fontSize = size.sp, color = Color(0xFFF0A04B),
        modifier = if (onPick != null) Modifier.clickable { onPick(i) }.padding(horizontal = 3.dp) else Modifier) } }
}

@Composable
fun RateSheet(b: JSONObject, onDismiss: () -> Unit) {
    var r by remember { mutableIntStateOf(b.optInt("r", 0)) }
    var rv by remember { mutableStateOf(b.optString("rv")) }
    Sheet("⭐ عجبك «${b.optString("t")}»؟", onDismiss) {
        Box(Modifier.fillMaxWidth(), Alignment.Center) { Stars(r, 40) { r = it } }
        Text(listOf("", "😕 معجبنيش", "😐 عادي", "🙂 كويس", "😃 حلو أوي", "🤩 تحفة!").getOrElse(r) { "" }, Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontWeight = FontWeight.Bold, color = Ink)
        OutlinedTextField(rv, { rv = it }, Modifier.fillMaxWidth(), label = { Text("رأيك في سطر (اختياري)") }, shape = RoundedCornerShape(14.dp))
        Button({ if (r > 0) { b.put("r", r); if (rv.isNotBlank()) b.put("rv", rv.trim()) else b.remove("rv"); Lib.touch(b, "r", "rv"); Lib.save() }; onDismiss() },
            Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("💾 احفظ") }
        val rctx = LocalContext.current
        if (r > 0) OutlinedButton({ Boost.shareQuote(rctx, "★".repeat(r) + "☆".repeat(5 - r) + (if (rv.isNotBlank()) "\n\n" + rv.trim() else ""), b) }, Modifier.fillMaxWidth()) { Text("📸 شارك تقييمك صورة") }
    }
}

/* ───── 🎯 تحدي القراية السنوي (زي Goodreads Reading Challenge) ───── */
fun yearKey() = Calendar.getInstance().get(Calendar.YEAR).toString()
fun challengeGoal(): Int = Lib.cfg.optJSONObject("chY")?.optInt(yearKey(), 0) ?: 0

@Composable
fun ChallengeCard(onYear: () -> Unit) {
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val yr = yearKey(); val g = challengeGoal()
    val done = Lib.books.count { it.optString("sh") == "done" && it.optString("fd").startsWith(yr) }
    var pick by remember { mutableStateOf(false) }
    Surface(onClick = { if (g == 0) pick = true else onYear() }, shape = RoundedCornerShape(20.dp), color = soft(0xFFF3ECFA)) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("🎯 تحدي $yr", fontWeight = FontWeight.Black, color = deep(0xFF5B2C83), fontSize = 16.sp, modifier = Modifier.weight(1f))
                if (g > 0) Text("✏️", Modifier.clickable { pick = true }.padding(4.dp))
            }
            if (g == 0) Text("حدد كام كتاب ناوي تخلّص السنة دي — زي تحدي Goodreads 📚", color = Ink, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
            else {
                val c = Calendar.getInstance()
                val exp = g * c.get(Calendar.DAY_OF_YEAR).toFloat() / c.getActualMaximum(Calendar.DAY_OF_YEAR)
                val diff = Math.round(done - exp)
                Text("$done من $g كتب", fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink, modifier = Modifier.padding(top = 4.dp))
                LinearProgressIndicator(progress = { (done.toFloat() / g).coerceIn(0f, 1f) }, Modifier.fillMaxWidth().padding(vertical = 6.dp).height(10.dp).clip(CircleShape), color = deep(0xFF7B3FA0), trackColor = Sand)
                Text(when { done >= g -> "🏆 خلّصت التحدي! أي كتاب زيادة بونص"; diff > 0 -> "📈 متقدّم عن الجدول بـ $diff كتاب"; diff < 0 -> "⏳ متأخر ${-diff} كتاب عن الجدول — كتاب صغير يعوّضها"; else -> "✅ ماشي في الجدول بالظبط" },
                    fontSize = 13.sp, color = Muted, fontWeight = FontWeight.Bold)
                Text("دوس تشوف «سنتي في القراية» 📖", fontSize = 12.sp, color = deep(0xFF7B3FA0), modifier = Modifier.padding(top = 4.dp))
            }
        }
    }
    if (pick) AlertDialog(onDismissRequest = { pick = false }, confirmButton = { TextButton({ pick = false }) { Text("قفل") } },
        title = { Text("🎯 هتقرا كام كتاب في $yr؟") }, text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("ابدأ بحاجة سهلة — تقدر تزوّدها بعدين", color = Muted, fontSize = 13.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(2, 4, 6, 12, 24).forEach { n -> Chip("$n", g == n) {
                    val o = Lib.cfg.optJSONObject("chY") ?: JSONObject().also { Lib.cfg.put("chY", it) }; o.put(yr, n); Lib.save(); pick = false } } }
            }
        })
}

/* ───── 📖 سنتي في القراية (زي Year in Books) ───── */
@Composable
fun YearSheet(onDismiss: () -> Unit, onOpen: (JSONObject) -> Unit) {
    val yr = yearKey()
    val bs = Lib.books.filter { it.optString("sh") == "done" && it.optString("fd").startsWith(yr) }.sortedBy { it.optString("fd") }
    val pages = Lib.dayMap().filter { it.key.startsWith(yr) }.values.sum()
    val days = Lib.dayMap().count { it.key.startsWith(yr) && it.value > 0 }
    val rated = bs.filter { it.optInt("r") > 0 }
    Sheet("📖 سنتي في القراية $yr", onDismiss) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("${bs.size}" to "كتاب", "$pages" to "صفحة", "$days" to "يوم قريت").forEach { (n, l) ->
                Surface(shape = RoundedCornerShape(14.dp), color = soft(0xFFF3ECFA), modifier = Modifier.weight(1f)) {
                    Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(n, fontWeight = FontWeight.Black, fontSize = 22.sp, color = Ink); Text(l, fontSize = 11.sp, color = Muted) } } }
        }
        if (bs.isEmpty()) Text("لسه مخلّصتش كتاب السنة دي — أول كتاب هيظهر هنا 🌱", color = Muted)
        else {
            bs.maxByOrNull { it.optInt("pg") }?.takeIf { it.optInt("pg") > 0 }?.let { Text("📏 أطول كتاب: «${it.optString("t")}» (${it.optInt("pg")} صفحة)", color = Ink, fontSize = 13.sp) }
            rated.maxByOrNull { it.optInt("r") }?.let { Text("❤️ أكتر كتاب عجبك: «${it.optString("t")}»", color = Ink, fontSize = 13.sp) }
            if (rated.isNotEmpty()) Text("⭐ متوسط تقييمك: " + String.format(java.util.Locale.US, "%.1f", rated.map { it.optInt("r") }.average()), color = Ink, fontSize = 13.sp)
            bs.forEach { b -> Surface(onClick = { onDismiss(); onOpen(b) }, shape = RoundedCornerShape(14.dp), color = Card) {
                Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Cover(b, Modifier.width(44.dp).height(62.dp)); Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(b.optString("t"), fontWeight = FontWeight.Bold, color = Ink, fontSize = 14.sp, maxLines = 2)
                        if (b.optInt("r") > 0) Stars(b.optInt("r"), 14)
                        if (b.optString("rv").isNotEmpty()) Text("«${b.optString("rv")}»", color = Muted, fontSize = 12.sp, maxLines = 2)
                    }
                }
            } }
        }
    }
}


/* ───── 🧭 استكشف (زي Explore / Lists في Goodreads) ───── */
val GENRES = listOf("📏 كتب قصيرة (أقل من 150 صفحة)", "📖 روايات عربية مشهورة", "🌍 روايات عالمية مترجمة", "💪 تطوير الذات", "💰 فلوس وبيزنس", "📊 إدارة وقيادة", "🕌 إسلاميات سهلة", "📜 سيرة وقصص الأنبياء والصحابة", "🏛 تاريخ بأسلوب قصصي", "🧠 علم نفس", "🤔 فلسفة مبسطة", "🔬 علوم مبسطة", "👤 سير ذاتية", "🔍 غموض وتشويق", "🐉 فانتازيا ومغامرات", "😂 كتب خفيفة وساخرة", "👨‍👧 تربية وأسرة", "🥗 صحة وتغذية", "🇬🇧 كتب إنجليزي سهلة", "🏆 أحسن كتب 2025-2026")

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ExploreBody(onSearch: (String) -> Unit) {
    val ctx = LocalContext.current
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val st = Explore.state()
    var sel by remember { mutableStateOf(st.optJSONArray("g")?.let { a -> (0 until a.length()).map { a.getString(it) }.toSet() } ?: emptySet()) }
    var q by remember { mutableStateOf(st.optString("q")) }
    val res = Explore.results()
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("اكتب أي حاجة: موضوع، كاتب، كتاب شبه…") }, shape = RoundedCornerShape(14.dp), maxLines = 3,
            leadingIcon = { Text("🔎") }, trailingIcon = { if (q.isNotEmpty()) Text("✕", Modifier.clickable { q = "" }.padding(8.dp), color = Muted) })
        Text("أو اختار تصنيف أو أكتر:", color = Muted, fontSize = 13.sp)
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            GENRES.forEach { x -> Chip((if (x in sel) "✓ " else "") + x, x in sel) { sel = if (x in sel) sel - x else sel + x } }
        }
        val ok = sel.isNotEmpty() || q.isNotBlank()
        Button({ if (!Net.hasGem()) Toast.makeText(ctx, "محتاج Gemini — اربط التطبيق الأول", Toast.LENGTH_LONG).show() else Explore.start(ctx, sel.toList(), q, false) },
            Modifier.fillMaxWidth().height(52.dp), enabled = ok && !Explore.busy, shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = Green)) {
            Text(if (Explore.busy) "⏳ بدوّر…" else if (sel.size > 1) "🔎 دوّر في ${sel.size} تصنيفات" else "🔎 دوّر", fontWeight = FontWeight.Black, fontSize = 16.sp)
        }
        if (Explore.busy) Text("⏳ بدوّر على أحسن كتب… تقدر تقفل التطبيق خالص، وهبعتلك إشعار أول ما أخلص 🔔", color = Muted, fontSize = 13.sp, lineHeight = 21.sp)
        if (Explore.err.isNotEmpty()) Text(Explore.err, color = Color(0xFFB3261E), fontSize = 13.sp)
        if (res.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("📚 لقيتلك ${res.size} كتاب", fontWeight = FontWeight.Black, color = Ink, modifier = Modifier.weight(1f))
                TextButton({ Explore.state().remove("r"); Lib.save(); Lib.ver++ }) { Text("🗑 امسح", color = Muted) }
            }
            res.forEach { r ->
                val mine = Lib.books.firstOrNull { it.optString("t") == r.optString("t") }
                Surface(shape = RoundedCornerShape(16.dp), color = Card) { Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(r.optString("t"), fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Ink)
                    Text(listOf(r.optString("a"), if (r.optInt("pg") > 0) "~${r.optInt("pg")} صفحة" else "", r.optString("cat")).filter { it.isNotBlank() }.joinToString(" • "), color = Muted, fontSize = 12.sp)
                    Text(r.optString("why"), fontSize = 13.sp, color = Ink, lineHeight = 21.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (mine == null) Chip("📌 عايز أقراه", false) { Lib.addLocal(r.optString("t"), r.optString("a")) {}; Lib.ver++; Toast.makeText(ctx, "📌 اتضاف لـ«عايز أقراه»", Toast.LENGTH_SHORT).show() }
                        else Chip("✅ عندك", true) {}
                        Chip("⬇️ نزّله", false) { onSearch(r.optString("t")) }
                    }
                } }
            }
            OutlinedButton({ Explore.start(ctx, sel.toList(), q, true) }, Modifier.fillMaxWidth().height(48.dp), enabled = !Explore.busy && ok, shape = RoundedCornerShape(16.dp)) {
                Text(if (Explore.busy) "⏳ بجيب كمان…" else "➕ هات كتب تانية", fontWeight = FontWeight.Bold, color = Green) }
        }
    }
}

/* ───── ℹ️ عن الكتاب (زي صفحة الكتاب في Goodreads) ───── */
@Composable
fun AboutSheet(b: JSONObject, onDismiss: () -> Unit) {
    var info by remember { mutableStateOf<JSONObject?>(b.optJSONObject("info")) }
    var err by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (info != null) return@LaunchedEffect
        val j = Net.askJson("عن كتاب «${b.optString("t")}»" + (if (b.optString("a").isNotEmpty()) " لـ${b.optString("a")}" else "") + ": اكتب معلومات صحيحة بس، ولو مش متأكد من حاجة سيبها فاضية. " +
            "رجّع JSON بس: {\"about\":\"الكتاب بيتكلم عن إيه في 3-4 سطور بالمصري من غير حرق\",\"genre\":\"التصنيف\",\"gr\":متوسط تقييمه التقريبي على Goodreads من 5 أو 0 لو مش عارف,\"pages\":عدد الصفحات التقريبي,\"who\":\"هيعجب مين — سطر\",\"time\":\"هياخد قد إيه لو قريت 10 صفحات في اليوم\"}")
        if (j == null) err = true else { b.put("info", j); Lib.save(); info = j }
    }
    Sheet("ℹ️ " + b.optString("t"), onDismiss) {
        val i = info
        if (i == null) { if (err) Text("⚠️ مقدرتش أجيب المعلومات دلوقتي", color = Muted) else Busy("⏳ بجيب معلومات الكتاب…") }
        else {
            if (b.optString("a").isNotEmpty()) Text("✍️ " + b.optString("a"), color = Muted)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                if (i.optDouble("gr", 0.0) > 0) Text("⭐ ~" + String.format(java.util.Locale.US, "%.1f", i.optDouble("gr")) + " على Goodreads", fontWeight = FontWeight.Bold, color = Color(0xFFB46A14), fontSize = 13.sp)
                if (i.optString("genre").isNotEmpty()) Text("🏷 " + i.optString("genre"), color = Muted, fontSize = 13.sp)
            }
            Text(i.optString("about"), color = Ink, lineHeight = 24.sp)
            if (i.optString("who").isNotEmpty()) Text("👤 " + i.optString("who"), color = Ink, fontSize = 13.sp)
            if (i.optString("time").isNotEmpty()) Text("⏳ " + i.optString("time"), color = Ink, fontSize = 13.sp)
            Text("المعلومات دي من الذكاء الاصطناعي وممكن تكون تقريبية", color = Muted, fontSize = 11.sp)
        }
    }
}

/* ───── 📈 إحصائياتي (زي Reading Stats) ───── */
@Composable
fun StatsBody() {
    val m = Lib.dayMap()
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("📄 الصفحات في آخر 30 يوم", fontWeight = FontWeight.Bold, color = Ink)
        val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_MONTH, -29)
        val days = (0 until 30).map { val v = m[Lib.ds(c.time)] ?: 0; c.add(Calendar.DAY_OF_MONTH, 1); v }
        val mx = (days.maxOrNull() ?: 0).coerceAtLeast(1)
        Row(Modifier.fillMaxWidth().height(90.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            days.forEach { v -> Box(Modifier.weight(1f).fillMaxHeight(maxOf(0.03f, v.toFloat() / mx)).clip(RoundedCornerShape(3.dp)).background(if (v > 0) Green else Sand)) }
        }
        Text("أعلى يوم: $mx صفحة • متوسط: ${days.sum() / 30} صفحة/يوم", color = Muted, fontSize = 12.sp)
        Text("📚 كتب خلصتها كل شهر (${yearKey()})", fontWeight = FontWeight.Bold, color = Ink, modifier = Modifier.padding(top = 8.dp))
        val per = (1..12).map { mo -> Lib.books.count { it.optString("sh") == "done" && it.optString("fd").startsWith(yearKey() + "-" + String.format(java.util.Locale.US, "%02d", mo)) } }
        val pmx = (per.maxOrNull() ?: 0).coerceAtLeast(1)
        Row(Modifier.fillMaxWidth().height(80.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            per.forEachIndexed { i, v -> Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                if (v > 0) Text("$v", fontSize = 10.sp, color = Ink)
                Box(Modifier.fillMaxWidth().height((60f * maxOf(0.05f, v.toFloat() / pmx)).dp).clip(RoundedCornerShape(3.dp)).background(if (v > 0) deep(0xFF7B3FA0) else Sand))
                Text("${i + 1}", fontSize = 9.sp, color = Muted)
            } }
        }
        val done = Lib.books.filter { it.optString("sh") == "done" }
        val avgPg = done.map { it.optInt("pg") }.filter { it > 0 }.let { if (it.isEmpty()) 0 else it.average().toInt() }
        Text("✅ خلصت ${done.size} كتاب • 🚫 سبت ${Lib.books.count { it.optString("sh") == "dnf" }} • 🔥 أطول سلسلة: ${bestStreak()} يوم" + (if (avgPg > 0) " • متوسط طول الكتاب $avgPg صفحة" else ""), color = Ink, fontSize = 13.sp, lineHeight = 22.sp)
    }
}
