package com.bunyan.maktabati

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Locale

/** صفوف الأزرار الجديدة في الرئيسية */
@Composable
fun MoreActions(onJourney: () -> Unit, onBuddy: () -> Unit, onPaper: () -> Unit, onSettings: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Action("🗺", "رحلتي", Modifier.weight(1f), onJourney)
        Action("💬", "رفيق", Modifier.weight(1f), onBuddy)
        Action("📷", "كتاب ورق", Modifier.weight(1f), onPaper)
        Action("⚙️", "الإعدادات", Modifier.weight(1f), onSettings)
    }
}

/** كروت التشجيع في الرئيسية: صدقة الشمعة، تحدي طبّقها، الحصالة */
@Composable
fun MotivationCards(onJar: () -> Unit) {
    val ctx = LocalContext.current
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (Boost.sadaqaDue()) Surface(shape = RoundedCornerShape(18.dp), color = Color(0xFFFFF0E6)) {
            Column(Modifier.padding(14.dp)) {
                Text("🕯 الشمعة طفت امبارح", fontWeight = FontWeight.Black, fontSize = 16.sp, color = Ink)
                Text("اتفقنا: يوم من غير قراية = صدقة ${Lib.cfg.optInt("sadaqa")} درهم 🤲 — والنهارده نولّعها تاني 🔥", color = Ink, fontSize = 14.sp, lineHeight = 22.sp, modifier = Modifier.padding(vertical = 6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ Boost.sadaqaDone(true); Toast.makeText(ctx, "🤲 ربنا يتقبّل — يلا صفحة النهارده", Toast.LENGTH_SHORT).show() }, colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("✅ اتصدقت") }
                    TextButton({ Boost.sadaqaDone(false) }) { Text("بعدين") }
                }
            }
        }
        // 🛠 تحدي طبّقها
        Lib.books.firstOrNull { it.optJSONObject("ch")?.optBoolean("ok") == false }?.let { b ->
            val ch = b.optJSONObject("ch")!!
            Surface(shape = RoundedCornerShape(18.dp), color = Color(0xFFEAF2FF)) {
                Column(Modifier.padding(14.dp)) {
                    Text("🛠 تحدي الأسبوع من «${b.optString("t")}»", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = Color(0xFF2B5DAA))
                    Text(ch.optString("t"), fontWeight = FontWeight.Black, fontSize = 16.sp, color = Ink, modifier = Modifier.padding(top = 4.dp))
                    Text(ch.optString("how"), color = Ink, fontSize = 13.sp, lineHeight = 21.sp, modifier = Modifier.padding(vertical = 4.dp))
                    Text("لحد " + ch.optString("due") + " — الكتاب مش هيتحسب «مخلّص» غير لما تطبّقه 😉", color = Muted, fontSize = 12.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                        Button({ ch.put("ok", true); Lib.save(); Toast.makeText(ctx, "🏆 عاش! كده الكتاب اتقرا واتطبّق", Toast.LENGTH_LONG).show() }, colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("✅ طبّقته") }
                        TextButton({ b.remove("ch"); Lib.save() }) { Text("مش مناسب") }
                    }
                }
            }
        }
        // 🎁 الحصالة
        val j = Boost.jar()
        Surface(onClick = onJar, shape = RoundedCornerShape(18.dp), color = Card, modifier = Modifier.border(1.dp, Color(0xFFEADFCA), RoundedCornerShape(18.dp))) {
            if (j == null) Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("🎁", fontSize = 28.sp); Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) { Text("حصالة القراية", fontWeight = FontWeight.Bold, color = Ink); Text("اختار حاجة نفسك فيها — كل صفحة تقراها = درهم فيها", color = Muted, fontSize = 13.sp) }
            } else {
                val got = Boost.jarPages(); val price = j.optInt("price"); val pc = (got.toFloat() / price).coerceIn(0f, 1f)
                Column(Modifier.padding(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(if (pc >= 1f) "🎉" else "🐷", fontSize = 28.sp); Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text("🎁 " + j.optString("n"), fontWeight = FontWeight.Black, color = Ink, fontSize = 16.sp)
                            Text(if (pc >= 1f) "الحصالة اتملت! اشتريها انت تستاهل 🎉" else "معاك $got من $price درهم — فاضل ${price - got} صفحة", color = Muted, fontSize = 13.sp)
                        }
                    }
                    LinearProgressIndicator(progress = { pc }, Modifier.fillMaxWidth().padding(top = 8.dp).height(10.dp).clip(CircleShape), color = Flame, trackColor = Sand)
                }
            }
        }
    }
}

@Composable
fun JarSheet(onDismiss: () -> Unit) {
    val j = Boost.jar()
    var n by remember { mutableStateOf(j?.optString("n") ?: "") }
    var price by remember { mutableStateOf(j?.optInt("price")?.toString() ?: "") }
    Sheet("🎁 حصالة القراية", onDismiss) {
        Text("اختار حاجة نفسك فيها، وكل صفحة تقراها من النهارده = درهم في الحصالة. لما تتملى اشتريها 🎉", color = Ink, lineHeight = 24.sp)
        OutlinedTextField(n, { n = it }, Modifier.fillMaxWidth(), label = { Text("الجايزة (مثلاً: ساعة جديدة)") }, singleLine = true, shape = RoundedCornerShape(14.dp))
        OutlinedTextField(price, { price = it.filter { c -> c.isDigit() } }, Modifier.fillMaxWidth(), label = { Text("سعرها بالدرهم") }, singleLine = true, shape = RoundedCornerShape(14.dp))
        Button({
            val p = price.toIntOrNull() ?: 0
            if (n.isNotBlank() && p > 0) { Lib.cfg.put("jar", JSONObject().put("n", n.trim()).put("price", p).put("from", j?.optString("from")?.takeIf { j.optString("n") == n.trim() } ?: Lib.today())); Lib.save(); onDismiss() }
        }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("💾 احفظ") }
        if (j != null) OutlinedButton({ Lib.cfg.remove("jar"); Lib.save(); onDismiss() }, Modifier.fillMaxWidth()) { Text(if (Boost.jarPages() >= j.optInt("price")) "🎉 اشتريتها — ابدأ حصالة جديدة" else "🗑 امسح الحصالة") }
    }
}

/* ───── 🗺 رحلتي ───── */
@Composable
fun JourneyScreen(onBack: () -> Unit, onOpen: (JSONObject) -> Unit) {
    BackHandler { onBack() }
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val done = Lib.books.filter { it.optString("sh") == "done" }.sortedBy { it.optString("fd") }
    val now = Lib.books.filter { it.optString("sh") == "now" }.sortedByDescending { it.optLong("rd") }
    val next = (Lib.queue.mapNotNull { Lib.book(it) } + Lib.books).filter { it.optString("sh", "want") == "want" }.distinctBy { it.optString("id") }.take(5)
    val stops = done.map { it to 2 } + now.map { it to 1 } + next.map { it to 0 }
    val km = Lib.dayMap().values.sum()
    val st = rememberLazyListState(initialFirstVisibleItemIndex = maxOf(0, done.size - 1))
    Column(Modifier.fillMaxSize().background(Color(0xFFEAF4E8))) {
        Row(Modifier.fillMaxWidth().background(Paper).statusBarsPadding().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp))
            Column { Text("🗺 رحلتي في القراية", fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink)
                Text("قطعت $km كم (كل صفحة = كيلو) • ${done.size} مدينة وصلتها", color = Muted, fontSize = 12.sp) }
        }
        LazyColumn(state = st, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(vertical = 20.dp)) {
            itemsIndexed(stops) { i, (b, kind) ->
                val left = i % 2 == 0
                val pc = if (kind == 1 && b.optInt("pg") > 0) (b.optInt("cur").toFloat() / b.optInt("pg")).coerceIn(0f, 1f) else 0f
                Box(Modifier.fillMaxWidth().height(150.dp)) {
                    // الطريق
                    Canvas(Modifier.fillMaxSize()) {
                        val x1 = if (left) size.width * 0.28f else size.width * 0.72f; val x2 = if (left) size.width * 0.72f else size.width * 0.28f
                        if (i < stops.size - 1) {
                            val path = Path().apply { moveTo(x1, size.height * 0.35f); cubicTo(x1, size.height * 0.9f, x2, size.height * 0.75f, x2, size.height * 1.35f) }
                            drawPath(path, Color(0xFF8C7A5B), style = Stroke(width = 26f, cap = StrokeCap.Round))
                            drawPath(path, Color.White.copy(alpha = 0.8f), style = Stroke(width = 4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(18f, 16f))))
                        }
                        drawCircle(when (kind) { 2 -> Color(0xFF1F7A55); 1 -> Color(0xFFF0A04B); else -> Color(0xFFB9B2A3) }, 34f, Offset(x1, size.height * 0.35f))
                        drawCircle(Color.White, 14f, Offset(x1, size.height * 0.35f))
                    }
                    // اسم المدينة (الكتاب)
                    Column(Modifier.align(if (left) Alignment.TopEnd else Alignment.TopStart).padding(horizontal = 16.dp).padding(top = 22.dp).widthIn(max = 200.dp),
                        horizontalAlignment = if (left) Alignment.End else Alignment.Start) {
                        Text(when (kind) { 2 -> "🏁 وصلتها"; 1 -> "🚗 في الطريق ليها"; else -> "📍 جاية" }, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = when (kind) { 2 -> Green; 1 -> Flame; else -> Muted })
                        Surface(onClick = { onOpen(b) }, shape = RoundedCornerShape(12.dp), color = Card) {
                            Text(b.optString("t"), Modifier.padding(horizontal = 10.dp, vertical = 6.dp), fontWeight = FontWeight.Bold, color = Ink, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                        if (kind == 1) Text("${(pc * 100).toInt()}% من الطريق", fontSize = 11.sp, color = Flame, fontWeight = FontWeight.Bold)
                    }
                    // العربية على الطريق
                    if (kind == 1) {
                        val bx = if (left) 0.28f + 0.44f * pc else 0.72f - 0.44f * pc
                        BoxWithConstraints(Modifier.fillMaxSize()) {
                            Text("🚗", fontSize = 30.sp, modifier = Modifier.offset(x = maxWidth * bx - 18.dp, y = maxHeight * (0.35f + 0.65f * pc) - 22.dp))
                        }
                    }
                }
            }
            item { Text(if (next.isEmpty()) "🏔 ضيف كتب لقايمتك علشان الطريق يكمّل" else "…والطريق لسه مكمّل 🌄", Modifier.fillMaxWidth().padding(24.dp), textAlign = TextAlign.Center, color = Muted) }
        }
    }
}

/* ───── 💬 رفيق ───── */
@Composable
fun BuddyScreen(onBack: () -> Unit) {
    BackHandler { onBack() }
    val scope = rememberCoroutineScope()
    val msgs = remember { mutableStateListOf<Pair<String, String>>().also { l ->
        Lib.cfg.optJSONArray("buddy")?.let { a -> for (i in 0 until a.length()) a.optJSONObject(i)?.let { l.add(it.optString("r") to it.optString("t")) } }
    } }
    var q by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val st = rememberLazyListState()
    fun persist() { val a = JSONArray(); msgs.takeLast(40).forEach { (r, t) -> a.put(JSONObject().put("r", r).put("t", t)) }; Lib.cfg.put("buddy", a); Lib.save() }
    suspend fun reply() { busy = true; val a = Boost.buddyReply(msgs.toList()); msgs.add("him" to (a ?: "⚠️ مش قادر أرد دلوقتي — اتأكد من النت")); persist(); busy = false; st.animateScrollToItem(msgs.size) }
    LaunchedEffect(Unit) {
        if (!Net.hasGem()) return@LaunchedEffect
        val lastDay = Lib.cfg.optString("buddyDay")
        if (msgs.isEmpty() || lastDay != Lib.today()) { Lib.cfg.put("buddyDay", Lib.today()); reply() } else st.scrollToItem(msgs.size)
    }
    Column(Modifier.fillMaxSize().background(Paper).statusBarsPadding().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) { Text("💬 رفيق", fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink); Text("صاحبك في القراية — بيفتكر كل اللي قريته", color = Muted, fontSize = 12.sp) }
            TextButton({ msgs.clear(); persist(); scope.launch { reply() } }) { Text("🧹 جديد") }
        }
        if (!Net.hasGem()) Text("⚠️ رفيق محتاج Gemini — اربط التطبيق ببنيان الأول", Modifier.padding(16.dp), color = Color(0xFFB3261E))
        LazyColumn(state = st, modifier = Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            itemsIndexed(msgs) { _, (r, t) ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = if (r == "me") Arrangement.Start else Arrangement.End) {
                    Surface(shape = RoundedCornerShape(18.dp), color = if (r == "me") Green else Card, modifier = Modifier.widthIn(max = 300.dp)) {
                        Text(t, Modifier.padding(12.dp), color = if (r == "me") Color.White else Ink, fontSize = 15.sp, lineHeight = 25.sp)
                    }
                }
            }
            if (busy) item { Text("رفيق بيكتب… ✍️", color = Muted, modifier = Modifier.padding(8.dp)) }
        }
        Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(q, { q = it }, Modifier.weight(1f), placeholder = { Text("اكتب لرفيق…") }, shape = RoundedCornerShape(18.dp), maxLines = 4)
            Spacer(Modifier.width(8.dp))
            Button({ val t = q.trim(); if (t.isNotEmpty() && !busy) { q = ""; msgs.add("me" to t); persist(); scope.launch { st.animateScrollToItem(msgs.size); reply() } } },
                colors = ButtonDefaults.buttonColors(containerColor = Green), shape = RoundedCornerShape(16.dp), modifier = Modifier.height(54.dp)) { Text("ابعت") }
        }
    }
}

/* ───── 📷 الكتاب الورق ───── */
@Composable
fun PaperScreen(onBack: () -> Unit) {
    BackHandler { onBack() }
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    var book by remember { mutableStateOf(Lib.books.filter { it.optBoolean("paper") }.maxByOrNull { it.optLong("rd") }) }
    var newT by remember { mutableStateOf("") }
    var shot by remember { mutableStateOf<Bitmap?>(null) }
    var text by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf("") }
    var out by remember { mutableStateOf<String?>(null) }
    var sents by remember { mutableStateOf<List<String>>(emptyList()) }
    val saved = remember { mutableStateListOf<String>() }
    val tts = remember { mutableStateOf<TextToSpeech?>(null) }
    DisposableEffect(Unit) { var t: TextToSpeech? = null; t = TextToSpeech(ctx) { if (it == TextToSpeech.SUCCESS) { t?.setLanguage(Locale("ar")); tts.value = t } }; onDispose { t?.stop(); t?.shutdown() } }
    val camFile = remember { File(ctx.cacheDir, "share/cam.jpg").also { it.parentFile?.mkdirs() } }
    val camUri = remember { androidx.core.content.FileProvider.getUriForFile(ctx, ctx.packageName + ".files", camFile) }
    val cam = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val b = book ?: return@rememberLauncherForActivityResult
        if (!ok) return@rememberLauncherForActivityResult
        val o = BitmapFactory.Options().apply { inSampleSize = 2 }
        val bm = BitmapFactory.decodeFile(camFile.path, o) ?: return@rememberLauncherForActivityResult
        shot = bm; text = null; out = null; sents = emptyList(); saved.clear()
        val p = b.optInt("maxp", 0) + 1
        b.put("cur", p); Lib.credit(b, p); Lib.touch(b, "cur")
        Toast.makeText(ctx, "✅ صفحة $p اتحسبت", Toast.LENGTH_SHORT).show()
        if (Net.hasGem()) scope.launch {
            busy = "⏳ بقرا الصفحة…"
            val j = Net.askJson("دي صورة صفحة من كتاب ورق. رجّع JSON بس: {\"t\":\"كلام الصفحة كله بالظبط مشكول تشكيل صحيح علشان يتقري بصوت عالي\",\"s\":[\"أحلى 4 جمل فيها بالظبط\"]}", listOf(bm))
            text = j?.optString("t")?.takeIf { it.isNotEmpty() }; sents = j?.optJSONArray("s")?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList(); busy = ""
        }
    }
    Column(Modifier.fillMaxSize().background(Paper).statusBarsPadding().padding(14.dp).verticalScrollable(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) { IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp)); Text("📷 الكتاب الورق", fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink) }
        Text("بتقرا كتاب ورق؟ صوّر كل صفحة تخلّصها: بتتحسب في الشمعة والهدف، وتقدر تسمعها أو تحفظ منها اقتباس.", color = Muted, lineHeight = 22.sp)
        val papers = Lib.books.filter { it.optBoolean("paper") }
        if (papers.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { papers.take(4).forEach { b -> Chip(b.optString("t").take(18), book?.optString("id") == b.optString("id")) { book = b } } }
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(newT, { newT = it }, Modifier.weight(1f), placeholder = { Text("اسم كتاب ورق جديد") }, singleLine = true, shape = RoundedCornerShape(14.dp))
            Spacer(Modifier.width(8.dp))
            OutlinedButton({ if (newT.isNotBlank()) { val ex = Lib.books.firstOrNull { it.optString("t") == newT.trim() }; val b = ex ?: Lib.addLocal(newT.trim(), "") {}; b.put("paper", true); Lib.setShelf(b, "now"); book = b; newT = "" } }) { Text("➕") }
        }
        val b = book
        if (b != null) {
            Text("📖 «${b.optString("t")}» — قريت ${b.optInt("maxp")} صفحة", fontWeight = FontWeight.Bold, color = Ink)
            Button({ cam.launch(camUri) }, Modifier.fillMaxWidth().height(56.dp), colors = ButtonDefaults.buttonColors(containerColor = Green), shape = RoundedCornerShape(16.dp)) { Text("📷 صوّر الصفحة اللي خلّصتها", fontSize = 16.sp, fontWeight = FontWeight.Bold) }
        }
        shot?.let { bm -> androidx.compose.foundation.Image(bm.asImageBitmapSafe(), null, Modifier.fillMaxWidth().heightIn(max = 260.dp).clip(RoundedCornerShape(12.dp))) }
        if (busy.isNotEmpty()) Busy(busy)
        text?.let { t ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Chip("🎧 اسمعها", false) { tts.value?.let { s -> s.stop(); Regex("[^.!؟?،\n]{1,220}[.!؟?،]?").findAll(t).forEach { m -> s.speak(m.value, TextToSpeech.QUEUE_ADD, null, null) } } }
                Chip("⏹", false) { tts.value?.stop() }
                Chip("💡 اشرحلي", false) { val bm = shot ?: return@Chip; scope.launch { busy = "⏳ بشرح…"; out = Net.ask("اشرح الصفحة دي لواحد كسلان في القراية: الفكرة في سطرين وأهم 3 نقط بالمصري البسيط.", listOf(bm)); busy = "" } }
            }
        }
        out?.let { Bubble(it) }
        val bb = book
        sents.forEach { s ->
            val done = saved.contains(s)
            Surface(onClick = { if (!done && bb != null) { Lib.addQuote(bb, s, bb.optInt("maxp")); saved.add(s) } }, shape = RoundedCornerShape(14.dp), color = if (done) Color(0xFFE8F3EE) else Card) {
                Column(Modifier.padding(12.dp)) { Text((if (done) "✅ " else "💾 ") + "«$s»", color = Ink, lineHeight = 24.sp); if (done) Chip("📸 شاركه صورة", false) { Boost.shareQuote(ctx, s, bb) } }
            }
        }
    }
}

fun Bitmap.asImageBitmapSafe() = this.asImageBitmap()

@Composable
fun Modifier.verticalScrollable(): Modifier = this.then(Modifier.verticalScroll(rememberScrollState()))

/* ───── ⚙️ الإعدادات الجديدة ───── */
@Composable
fun MoreSettings() {
    val ctx = LocalContext.current
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    fun set(k: String, x: Any) { Lib.cfg.put(k, x); Lib.save(); Notify.schedule(ctx) }
    HorizontalDivider()
    Text("📱 بدل الاسكرول", fontWeight = FontWeight.Bold)
    Text("لما تفتح انستجرام أو تيك توك بالليل وتطوّل، يجيلك: «بدل 10 دقايق اسكرول، 3 صفحات وتنام؟»", color = Muted, fontSize = 13.sp, lineHeight = 20.sp)
    if (!Boost.usageOk(ctx)) Button({ Toast.makeText(ctx, "دوّر على «مكتبتي» وفعّلها، وارجع", Toast.LENGTH_LONG).show(); ctx.startActivity(Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)) },
        Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("فعّلها (إذن مرة واحدة)") }
    else Row(verticalAlignment = Alignment.CenterVertically) { Text("شغّالة من ${Lib.cfg.optInt("nudgeFrom", 20)}:00 لـ ${Lib.cfg.optInt("nudgeTo", 2)}:00", Modifier.weight(1f)); Switch(Lib.cfg.optBoolean("nudge", true), { set("nudge", it) }) }
    HorizontalDivider()
    Text("🤲 صدقة الشمعة", fontWeight = FontWeight.Bold)
    Text("لو يوم عدّى من غير قراية، التطبيق يفكّرك تتصدق بالمبلغ ده" + (if (Boost.sadaqaTotal() > 0) " — اتصدقت لحد دلوقتي بـ ${Boost.sadaqaTotal()} درهم 🤲" else ""), color = Muted, fontSize = 13.sp, lineHeight = 20.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(0, 5, 10, 20, 50).forEach { a -> Chip(if (a == 0) "مقفول" else "$a درهم", Lib.cfg.optInt("sadaqa", 0) == a) { set("sadaqa", a) } } }
    HorizontalDivider()
    Row(verticalAlignment = Alignment.CenterVertically) { Text("💬 رفيق يسألني كل ليلة عن قرايتي", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("buddy", true), { set("buddy", it) }) }
    Row(verticalAlignment = Alignment.CenterVertically) { Text("🪝 جملة تشويق قبل ما أبدأ", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("hook", true), { set("hook", it) }) }
    Row(verticalAlignment = Alignment.CenterVertically) { Text("🔊 قلب الصفحات بزراير الصوت", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("volkeys", true), { set("volkeys", it) }) }
    Row(verticalAlignment = Alignment.CenterVertically) { Text("⬇️ نزّل الكتاب الجاي لوحده على الواي فاي", Modifier.weight(1f), fontWeight = FontWeight.Bold); Switch(Lib.cfg.optBoolean("prefetch", true), { set("prefetch", it) }) }
    HorizontalDivider()
    Text("🗣 الصوت الطبيعي", fontWeight = FontWeight.Bold)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Chip("📱 صوت الموبايل", Lib.cfg.optString("voice") != "gem") { set("voice", "tts") }
        Chip("🗣 صوت طبيعي (Gemini)", Lib.cfg.optString("voice") == "gem") { set("voice", "gem") }
    }
    if (Lib.cfg.optString("voice") == "gem") Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf("Charon" to "👨 هادي", "Orus" to "👨 عميق", "Kore" to "👩 هادية", "Aoede" to "👩 دافية").forEach { (k, t) -> Chip(t, Lib.cfg.optString("voiceName", "Charon") == k) { set("voiceName", k); File(Lib.dir, "tts").listFiles()?.filter { it.name.endsWith(".pcm") }?.forEach { it.delete() } } }
    }
}
