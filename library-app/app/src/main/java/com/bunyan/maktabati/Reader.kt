package com.bunyan.maktabati

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color as AColor
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.LruCache
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.File
import java.util.Locale

/** ملف الكتاب (ممكن يكون كذا جزء) — بيتعرض بـ PdfRenderer بتاع أندرويد */
class Doc(files: List<File>) {
    private val fds = files.map { ParcelFileDescriptor.open(it, ParcelFileDescriptor.MODE_READ_ONLY) }
    private val rs = fds.map { PdfRenderer(it) }
    private val offs = rs.runningFold(0) { a, r -> a + r.pageCount }
    val count = offs.last()
    private val lock = Mutex()
    private val cache = object : LruCache<String, Bitmap>(28 * 1024 * 1024) { override fun sizeOf(k: String, v: Bitmap) = v.byteCount }
    private val ratios = HashMap<Int, Float>()

    private fun loc(p: Int): Pair<PdfRenderer, Int> { var j = rs.size - 1; while (j > 0 && p <= offs[j]) j--; return rs[j] to (p - 1 - offs[j]) }

    suspend fun ratio(p: Int): Float = ratios[p] ?: lock.withLock { withContext(Dispatchers.IO) {
        val (r, i) = loc(p); r.openPage(i).use { pg -> (pg.height.toFloat() / pg.width).also { ratios[p] = it } }
    } }

    suspend fun render(p: Int, w: Int): Bitmap {
        val key = "$p@$w"
        cache.get(key)?.let { return it }
        return lock.withLock {
            withContext(Dispatchers.IO) {
                val (r, i) = loc(p)
                r.openPage(i).use { pg ->
                    val h = (w.toFloat() * pg.height / pg.width).toInt().coerceAtLeast(1)
                    val bm = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    bm.eraseColor(AColor.WHITE)
                    pg.render(bm, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    ratios[p] = h.toFloat() / w
                    bm
                }
            }
        }.also { cache.put(key, it) }
    }

    fun close() { try { rs.forEach { it.close() }; fds.forEach { it.close() } } catch (_: Exception) {} }
}

private const val VP = "دي صفحة من كتاب عربي هتتقري بصوت عالي بقارئ آلي. اكتب كلام الصفحة بالظبط بالترتيب الصح، واكتبه مشكول تشكيل كامل وصحيح نحويًا (كل حرف عليه حركته الصح، وخصوصًا أواخر الكلمات)، علشان القارئ ينطقه صح. متكتبش رقم الصفحة ولا العناوين المتكررة فوق ولا الحواشي، ومن غير أي شرح أو تعليق. الآيات اكتبها بتشكيلها الصح."

@Composable
fun ReaderScreen(b: JSONObject, onClose: (Int, Int, Int) -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val doc = remember(b) { try { Doc(Lib.files(b)) } catch (e: Exception) { null } }
    DisposableEffect(doc) { onDispose { doc?.close() } }
    if (doc == null || doc.count == 0) { Box(Modifier.fillMaxSize(), Alignment.Center) { Text("⚠️ الملف بايظ — امسحه ونزّله تاني") }; return }
    val n = doc.count
    if (b.optInt("pg") != n) { b.put("pg", n); Lib.touch(b, "pg"); Lib.save() }
    val start = b.optInt("cur", 1).coerceIn(1, n)
    val list = rememberLazyListState(initialFirstVisibleItemIndex = start - 1)
    var flip by remember { mutableStateOf(Lib.cfg.optString("mode") == "flip") }
    val pager = androidx.compose.foundation.pager.rememberPagerState(initialPage = start - 1) { n }
    var widthPx by remember { mutableIntStateOf(1080) }
    var night by remember { mutableStateOf(false) }
    var zoom by remember { mutableFloatStateOf(1f) }
    var panX by remember { mutableFloatStateOf(0f) }
    var sess by remember { mutableIntStateOf(0) }
    val t0 = remember { System.currentTimeMillis() }
    var secs by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) { while (true) { delay(1000); secs = (System.currentTimeMillis() - t0) / 1000 } }

    // الصفحة الحالية = أكتر صفحة ظاهرة على الشاشة
    val cur by remember { derivedStateOf {
        if (flip) return@derivedStateOf pager.currentPage + 1
        val vis = list.layoutInfo.visibleItemsInfo
        if (vis.isEmpty()) start else {
            val top = list.layoutInfo.viewportStartOffset; val bot = list.layoutInfo.viewportEndOffset
            vis.maxByOrNull { minOf(it.offset + it.size, bot) - maxOf(it.offset, top) }!!.index + 1
        }
    } }
    fun close() { onClose(start, cur, sess) }
    BackHandler { close() }
    suspend fun goTo(p: Int, anim: Boolean = false) { val i = (p - 1).coerceIn(0, n - 1); if (flip) { if (anim) pager.animateScrollToPage(i) else pager.scrollToPage(i) } else { if (anim) list.animateScrollToItem(i) else list.scrollToItem(i) } }
    // سرعتك: متوسط الوقت اللي بتقعده على الصفحة
    DisposableEffect(cur) {
        val e = System.currentTimeMillis()
        onDispose {
            val dw = ((System.currentTimeMillis() - e) / 1000).toInt()
            if (dw in 20..600) { val o = b.optInt("spd", 0); b.put("spd", if (o == 0) dw else (o * 0.8 + dw * 0.2).toInt()) }
        }
    }
    // بتتحسب الصفحة لو فضلت عليها 20 ثانية (مش اسكرول)
    LaunchedEffect(cur) {
        Lib.setCur(b, cur)
        delay(20000)
        if (Lib.credit(b, cur)) { sess++; if (sess == 5 || sess == 10 || sess == 20) Toast.makeText(ctx, "🔥 $sess صفحات في القعدة دي — عاش!", Toast.LENGTH_SHORT).show() }
    }

    /* 🎧 القراية بالصوت */
    var listening by remember { mutableStateOf(false) }
    var rate by remember { mutableFloatStateOf(1f) }
    val tts = remember { mutableStateOf<TextToSpeech?>(null) }
    DisposableEffect(Unit) {
        var t: TextToSpeech? = null
        t = TextToSpeech(ctx) { st -> if (st == TextToSpeech.SUCCESS) { t?.setLanguage(Locale("ar")); tts.value = t } }
        onDispose { t?.stop(); t?.shutdown() }
    }
    val pending = remember { HashMap<String, CompletableDeferred<Unit>>() }
    LaunchedEffect(tts.value) {
        tts.value?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { pending.remove(id)?.complete(Unit) }
            @Deprecated("") override fun onError(id: String?) { pending.remove(id)?.complete(Unit) }
        })
    }
    suspend fun say(s: String) {
        val t = tts.value ?: return
        val id = java.util.UUID.randomUUID().toString(); val d = CompletableDeferred<Unit>(); pending[id] = d
        t.setSpeechRate(0.95f * rate)
        t.speak(s, TextToSpeech.QUEUE_ADD, null, id); d.await()
    }
    suspend fun vocal(p: Int): String {
        val f = File(Lib.dir, "tts/${b.optString("id")}_$p.txt")
        if (f.exists()) return f.readText()
        val bm = doc.render(p, 1500)
        val t = Net.gemini(VP, bm)?.replace(Regex("[*#_`>]"), " ")?.replace(Regex("\\s+"), " ")?.trim()
        if (!t.isNullOrEmpty() && t.length > 5) { f.writeText(t); return t }
        return ""
    }
    LaunchedEffect(listening) {
        if (!listening) { tts.value?.stop(); pending.values.forEach { it.complete(Unit) }; pending.clear(); return@LaunchedEffect }
        if (Lib.gem() == null) { Toast.makeText(ctx, "محتاج Gemini — اربط التطبيق بحساب بنيان الأول", Toast.LENGTH_LONG).show(); listening = false; return@LaunchedEffect }
        if (tts.value == null) { Toast.makeText(ctx, "صوت القراية العربي مش جاهز على الموبايل", Toast.LENGTH_LONG).show(); listening = false; return@LaunchedEffect }
        Toast.makeText(ctx, "📖 بجهّز الصفحة بالتشكيل الصح…", Toast.LENGTH_SHORT).show()
        var p = cur
        while (isActive && listening) {
            val txt = vocal(p)
            if (p < n) launch { try { vocal(p + 1) } catch (_: Exception) {} }
            if (txt.isEmpty()) { Toast.makeText(ctx, "⚠️ مقدرتش أقرا الصفحة دي — اتأكد من النت", Toast.LENGTH_SHORT).show(); listening = false; break }
            for (s in Regex("[^.!؟?،\n]{1,220}[.!؟?،]?").findAll(txt).map { it.value.trim() }.filter { it.isNotEmpty() }) { if (!listening) break; say(s) }
            if (!listening) break
            Lib.credit(b, p)
            if (p >= n) { listening = false; Toast.makeText(ctx, "🎉 خلصت الكتاب!", Toast.LENGTH_LONG).show(); break }
            p++; goTo(p, true)
        }
    }

    var showTools by remember { mutableStateOf(false) }
    var aiMenu by remember { mutableStateOf(false) }
    var ai by remember { mutableStateOf<String?>(null) }
    var sleepAt by remember { mutableLongStateOf(0L) }
    LaunchedEffect(sleepAt) { if (sleepAt > 0) { delay(sleepAt - System.currentTimeMillis()); listening = false; sleepAt = 0; Toast.makeText(ctx, "😴 وقفت القراية بالصوت", Toast.LENGTH_SHORT).show() } }
    val bg = if (night) Color(0xFF1A1A1A) else Color(0xFFEDE6D8)
    Column(Modifier.fillMaxSize().background(bg)) {
        // الشريط اللي فوق
        Row(Modifier.fillMaxWidth().background(if (night) Color(0xFF111111) else Color(0xFFFBF6EC)).statusBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            IconBtn("✕") { close() }
            Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                Text(b.optString("t"), fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1, color = if (night) Color.White else Color(0xFF1D2733))
                Text("صفحة $cur من $n • ${cur * 100 / n}%" + remain(b, n - cur), fontSize = 12.sp, color = Color(0xFF7A6A55))
                Text("⏱ ${secs / 60}:${String.format(Locale.US, "%02d", secs % 60)} • +$sess صفحة", fontSize = 11.sp, color = Color(0xFF1F7A55), fontWeight = FontWeight.Bold)
            }
            IconBtn(if (listening) "⏸" else "🎧", on = listening) { listening = !listening }
            Spacer(Modifier.width(6.dp))
            IconBtn("💡") { aiMenu = true }
            Spacer(Modifier.width(6.dp))
            IconBtn("⋯") { showTools = true }
        }
        if (flip) androidx.compose.foundation.pager.HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth().onSizeChanged { widthPx = it.width }, beyondViewportPageCount = 1) { i ->
            Box(Modifier.fillMaxSize().padding(vertical = 6.dp), Alignment.Center) { PageView(doc, i + 1, widthPx, night, fit = true) }
        } else Box(Modifier.weight(1f).fillMaxWidth().onSizeChanged { widthPx = it.width }
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, z, _ ->
                    zoom = (zoom * z).coerceIn(1f, 3f)
                    val maxX = (zoom - 1f) * widthPx / 2f
                    panX = if (zoom <= 1.01f) 0f else (panX + pan.x).coerceIn(-maxX, maxX)
                }
            }) {
            LazyColumn(state = list, modifier = Modifier.fillMaxSize().graphicsLayer { scaleX = zoom; scaleY = zoom; translationX = panX; transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 0f) },
                contentPadding = PaddingValues(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                itemsIndexed(List(n) { it + 1 }) { _, p -> PageView(doc, p, widthPx, night) }
            }
        }
        // سلايدر الصفحات
        Row(Modifier.fillMaxWidth().background(if (night) Color(0xFF111111) else Color(0xFFFBF6EC)).navigationBarsPadding().padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            var sl by remember(cur) { mutableFloatStateOf(cur.toFloat()) }
            Slider(value = sl, onValueChange = { sl = it }, onValueChangeFinished = { scope.launch { goTo(sl.toInt()) } },
                valueRange = 1f..n.toFloat().coerceAtLeast(2f), modifier = Modifier.weight(1f))
        }
    }
    if (showTools) {
        AlertDialog(onDismissRequest = { showTools = false }, confirmButton = { TextButton({ showTools = false }) { Text("قفل") } },
            title = { Text("⚙️ أدوات القراية") }, text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("📖 شكل القراية", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("↕️ اسكرول", !flip) { if (flip) { val c = cur; flip = false; Lib.cfg.put("mode", "scroll"); Lib.save(); scope.launch { list.scrollToItem(c - 1) } } }
                        Chip("📖 صفحة صفحة", flip) { if (!flip) { val c = cur; flip = true; zoom = 1f; panX = 0f; Lib.cfg.put("mode", "flip"); Lib.save(); scope.launch { pager.scrollToPage(c - 1) } } }
                    }
                    Text("🎧 سرعة الصوت", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(0.75f, 1f, 1.25f, 1.5f).forEach { r -> Chip("${r}x", rate == r) { rate = r } } }
                    Text("😴 وقّف الصوت بعد", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(15, 30, 60).forEach { m -> Chip("$m د", false) { sleepAt = System.currentTimeMillis() + m * 60000L; Toast.makeText(ctx, "😴 الصوت هيقف بعد $m دقيقة", Toast.LENGTH_SHORT).show() } }
                        if (sleepAt > 0) Chip("❌ إلغاء", true) { sleepAt = 0 }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip(if (night) "☀️ نهاري" else "🌙 ليلي", night) { night = !night }
                        Chip("🔍 ترجيع الحجم", false) { zoom = 1f; panX = 0f }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("✅ خلصته", b.optString("sh") == "done") { Lib.setShelf(b, "done"); showTools = false; close() }
                    }
                }
            })
    }
    if (aiMenu) AiMenu({ ai = it; aiMenu = false }) { aiMenu = false }
    ai?.let { k -> AiSheet(k, b, doc, cur, onGo = { p -> scope.launch { goTo(p) } }) { ai = null } }
}

@Composable
private fun AiMenu(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    Sheet("💡 ساعدني أفهم", onDismiss) {
        listOf("explain" to "💡 اشرحلي الصفحة دي", "word" to "🔤 كلمة أو جملة مش فاهمها", "ask" to "💬 اسأل الكتاب أي سؤال", "quote" to "💬 احفظ اقتباس من الصفحة", "ideas" to "💼 أفكار من الكتاب لشغلي").forEach { (k, t) ->
            Surface(onClick = { onPick(k) }, shape = RoundedCornerShape(14.dp), color = Card, modifier = Modifier.fillMaxWidth()) { Text(t, Modifier.padding(14.dp), fontWeight = FontWeight.Bold, color = Ink, fontSize = 15.sp) }
        }
    }
}

fun remain(b: JSONObject, left: Int): String {
    val spd = b.optInt("spd", 0); if (spd <= 0 || left <= 0) return ""
    val m = (left * spd / 60).coerceAtLeast(1)
    return " • ⏱ فاضل " + if (m < 60) "$m د" else String.format(Locale.US, "%.1f ساعة", m / 60f)
}

@Composable
fun PageView(doc: Doc, p: Int, w: Int, night: Boolean, fit: Boolean = false) {
    var bm by remember(p, w) { mutableStateOf<Bitmap?>(null) }
    var ratio by remember(p) { mutableFloatStateOf(1.414f) }
    LaunchedEffect(p, w) { try { ratio = doc.ratio(p); bm = doc.render(p, (w * 1.6f).toInt().coerceAtMost(2000)) } catch (_: Exception) {} }
    Box((if (fit) Modifier.fillMaxSize().wrapContentSize().aspectRatio(1f / ratio, matchHeightConstraintsFirst = ratio > 1.3f) else Modifier.fillMaxWidth().aspectRatio(1f / ratio)).padding(horizontal = 6.dp).clip(RoundedCornerShape(4.dp)).background(Color.White), Alignment.Center) {
        val b = bm
        if (b != null) Image(b.asImageBitmap(), null, Modifier.fillMaxSize().graphicsLayer {
            if (night) { /* عكس الألوان للوضع الليلي */ }
        }, contentScale = ContentScale.FillBounds,
            colorFilter = if (night) androidx.compose.ui.graphics.ColorFilter.colorMatrix(androidx.compose.ui.graphics.ColorMatrix(floatArrayOf(
                -0.9f, 0f, 0f, 0f, 235f, 0f, -0.9f, 0f, 0f, 235f, 0f, 0f, -0.9f, 0f, 235f, 0f, 0f, 0f, 1f, 0f))) else null)
        else Text("$p", color = Color(0xFFBBBBBB), fontSize = 22.sp)
    }
}

@Composable
fun IconBtn(t: String, on: Boolean = false, click: () -> Unit) {
    Surface(onClick = click, shape = RoundedCornerShape(12.dp), color = if (on) Color(0xFF1F7A55) else Color(0xFFF1EADB), modifier = Modifier.size(42.dp)) {
        Box(contentAlignment = Alignment.Center) { Text(t, fontSize = 18.sp, color = if (on) Color.White else Color(0xFF1D2733)) }
    }
}

@Composable
fun Chip(t: String, on: Boolean, click: () -> Unit) {
    Surface(onClick = click, shape = RoundedCornerShape(12.dp), color = if (on) Color(0xFF1F7A55) else Color(0xFFF1EADB)) {
        Text(t, Modifier.padding(horizontal = 12.dp, vertical = 9.dp), fontWeight = FontWeight.Bold, fontSize = 13.sp, color = if (on) Color.White else Color(0xFF1D2733))
    }
}
