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
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.ui.draw.drawWithContent
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
    var bkVer by remember { mutableIntStateOf(0) }
    var night by remember { mutableStateOf(Lib.cfg.optBoolean("night", false)) }
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
    /* ⏱ دقيقتين بس */
    var sprintEnd by remember { mutableLongStateOf(if (Lib.sprint) t0 + 120000L else 0L) }
    var sprintDone by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { Lib.sprint = false }
    LaunchedEffect(secs) { if (sprintEnd > 0 && System.currentTimeMillis() >= sprintEnd) { sprintEnd = 0; sprintDone = true } }
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
        if (Lib.credit(b, cur)) {
            sess++
            if (Lib.goal == 1 && Lib.todayPages() == 1) Toast.makeText(ctx, "✅ عدّيت تحدي الصفحة الواحدة النهارده! أي صفحة زيادة بونص 💪", Toast.LENGTH_LONG).show()
            else if (sess == 5 || sess == 10 || sess == 20) Toast.makeText(ctx, "🔥 $sess صفحات في القعدة دي — عاش!", Toast.LENGTH_SHORT).show()
        }
    }

    /* 🎧 القراية بالصوت — خدمة بتكمّل والشاشة مقفولة */
    val listening = Speech.playing && Speech.bookId == b.optString("id")
    LaunchedEffect(Speech.page, listening) { if (listening && Speech.page in 1..n && Speech.page != cur) goTo(Speech.page, true) }
    fun toggleListen() {
        if (listening) Speech.stop(ctx)
        else if (!Net.hasGem()) Toast.makeText(ctx, "محتاج Gemini — اربط التطبيق بحساب بنيان الأول", Toast.LENGTH_LONG).show()
        else { Speech.start(ctx, b, cur); Toast.makeText(ctx, if (Speech.natural()) "🗣 بجهّز الصوت الطبيعي… وتقدر تقفل الشاشة" else "🎧 بجهّز الصفحة… وتقدر تقفل الشاشة", Toast.LENGTH_SHORT).show() }
    }

    /* 🌙 وضع التركيز: الشاشة متطفيش + فلتر دافي + الإشعارات تسكت */
    val act = ctx as? android.app.Activity
    var warm by remember { mutableStateOf(Lib.cfg.optBoolean("warm", false)) }
    DisposableEffect(Unit) {
        act?.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val nm = ctx.getSystemService(android.app.NotificationManager::class.java)
        var prev = -1
        if (Lib.cfg.optBoolean("dnd", false) && nm.isNotificationPolicyAccessGranted) { prev = nm.currentInterruptionFilter; nm.setInterruptionFilter(android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY) }
        Keys.reader = true
        onDispose {
            act?.window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            if (prev > 0) try { nm.setInterruptionFilter(prev) } catch (_: Exception) {}
            Keys.reader = false
        }
    }
    /* 🔊 قلب الصفحات بزراير الصوت */
    LaunchedEffect(Unit) { Keys.flow.collect { d -> goTo(cur + d, true) } }

    /* 🪝 طُعم قبل ما تبدأ */
    var hook by remember { mutableStateOf<String?>(if (Lib.cfg.optBoolean("hook", true) && Net.hasGem()) "" else null) }
    LaunchedEffect(Unit) { if (hook != null) { val h = try { Boost.hook(doc, b, start) } catch (_: Exception) { null }; hook = if (h.isNullOrEmpty()) null else h } }

    /* 📺 الحلقات */
    var epMsg by remember { mutableStateOf<String?>(null) }
    var lastEp by remember { mutableIntStateOf(Boost.epAt(b, start)?.first ?: -1) }
    LaunchedEffect(cur) {
        val e = Boost.epAt(b, cur) ?: return@LaunchedEffect
        if (lastEp >= 0 && e.first == lastEp + 1) {
            val prevN = Boost.eps(b).getOrNull(lastEp)?.optString("n") ?: ""
            epMsg = "🎬 خلصت الحلقة ${lastEp + 1}" + (if (prevN.isNotEmpty()) " «$prevN»" else "") + "!\nالجاية: «${e.second.optString("n")}» — حلقة كمان؟"
        }
        lastEp = e.first
    }

    /* 🖍 التعليم على الصفحة */
    var hlMode by remember { mutableStateOf(false) }
    fun onHl(p: Int, r: FloatArray) {
        val hl = b.optJSONArray("hl") ?: org.json.JSONArray().also { b.put("hl", it) }
        val o = JSONObject().put("p", p).put("r", org.json.JSONArray(r.map { it.toDouble() })).put("d", Lib.today())
        hl.put(o); Lib.save()
        if (Net.hasGem()) scope.launch {
            try {
                val full = doc.render(p, 1500); val x1 = (r[0] * full.width).toInt().coerceIn(0, full.width - 2); val y1 = (r[1] * full.height).toInt().coerceIn(0, full.height - 2)
                val x2 = (r[2] * full.width).toInt().coerceIn(x1 + 1, full.width); val y2 = (r[3] * full.height).toInt().coerceIn(y1 + 1, full.height)
                val crop = Bitmap.createBitmap(full, x1, y1, x2 - x1, y2 - y1)
                val t = Net.ask("اكتب الكلام العربي اللي في الصورة دي بالظبط زي ما هو، جملة كاملة، من غير أي تعليق.", listOf(crop))?.trim()
                if (!t.isNullOrEmpty()) { o.put("t", t); Lib.addQuote(b, t, p); Toast.makeText(ctx, "🖍 اتعلّم واتحفظ في اقتباساتك", Toast.LENGTH_SHORT).show() }
            } catch (_: Exception) {}
        } else Toast.makeText(ctx, "🖍 اتعلّم", Toast.LENGTH_SHORT).show()
    }

    var showTools by remember { mutableStateOf(false) }
    var aiMenu by remember { mutableStateOf(false) }
    var ai by remember { mutableStateOf<String?>(null) }
    val bg = if (night) Color(0xFF1A1A1A) else Color(0xFFEDE6D8)
    Column(Modifier.fillMaxSize().background(bg).drawWithContent { drawContent(); if (warm) drawRect(Color(0x33FF8A00)) }) {
        // الشريط اللي فوق
        Row(Modifier.fillMaxWidth().background(if (night) Color(0xFF111111) else Color(0xFFFBF6EC)).statusBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            IconBtn("✕") { close() }
            Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                Text(b.optString("t"), fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1, color = if (night) Color.White else Color(0xFF1D2733))
                Text("صفحة $cur من $n • ${cur * 100 / n}%" + remain(b, n - cur), fontSize = 12.sp, color = Color(0xFF7A6A55))
                Text("⏱ ${secs / 60}:${String.format(Locale.US, "%02d", secs % 60)} • +$sess صفحة", fontSize = 11.sp, color = Color(0xFF1F7A55), fontWeight = FontWeight.Bold)
            }
            IconBtn(if (listening) "⏸" else "🎧", on = listening) { toggleListen() }
            Spacer(Modifier.width(6.dp))
            IconBtn("🖍", on = hlMode) { hlMode = !hlMode; if (hlMode) { zoom = 1f; panX = 0f; Toast.makeText(ctx, "🖍 اسحب صباعك على الجملة علشان تعلّم عليها", Toast.LENGTH_SHORT).show() } }
            Spacer(Modifier.width(6.dp))
            IconBtn("💡") { aiMenu = true }
            Spacer(Modifier.width(6.dp))
            IconBtn("⋯") { showTools = true }
        }
        if (sprintEnd > 0) {
            val left = ((sprintEnd - System.currentTimeMillis()) / 1000).coerceAtLeast(0) + 0 * secs
            Text("⏱ فاضل ${left / 60}:${String.format(Locale.US, "%02d", left % 60)} وتقدر تقفل — اقرا على راحتك", Modifier.fillMaxWidth().background(Color(0xFF1F7A55)).padding(8.dp), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        if (flip) androidx.compose.foundation.pager.HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth().onSizeChanged { widthPx = it.width }, beyondViewportPageCount = 1, userScrollEnabled = !hlMode) { i ->
            Box(Modifier.fillMaxSize().padding(vertical = 6.dp), Alignment.Center) { PageView(doc, i + 1, widthPx, night, fit = true, b = b, hlMode = hlMode, onHl = ::onHl) }
        } else Box(Modifier.weight(1f).fillMaxWidth().onSizeChanged { widthPx = it.width }
            .pointerInput(hlMode) {
                if (!hlMode) detectTransformGestures { _, pan, z, _ ->
                    zoom = (zoom * z).coerceIn(1f, 3f)
                    val maxX = (zoom - 1f) * widthPx / 2f
                    panX = if (zoom <= 1.01f) 0f else (panX + pan.x).coerceIn(-maxX, maxX)
                }
            }) {
            LazyColumn(state = list, userScrollEnabled = !hlMode, modifier = Modifier.fillMaxSize().graphicsLayer { scaleX = zoom; scaleY = zoom; translationX = panX; transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 0f) },
                contentPadding = PaddingValues(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                itemsIndexed(List(n) { it + 1 }) { _, p -> PageView(doc, p, widthPx, night, b = b, hlMode = hlMode, onHl = ::onHl) }
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
                Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("🔖 العلامات", fontWeight = FontWeight.Bold)
                    @Suppress("UNUSED_EXPRESSION") bkVer
                    val bks = (0 until (b.optJSONArray("bk")?.length() ?: 0)).map { b.optJSONArray("bk")!!.optInt(it) }.sorted()
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        val has = bks.contains(cur)
                        Chip(if (has) "🔖 شيل علامة ص $cur" else "🔖 علّم صفحة $cur", has) {
                            val a = org.json.JSONArray(); (if (has) bks - cur else bks + cur).sorted().forEach { a.put(it) }
                            b.put("bk", a); Lib.touch(b, "bk"); Lib.save(); bkVer++
                        }
                        bks.filter { it != cur }.forEach { p -> Chip("ص $p", false) { showTools = false; scope.launch { goTo(p, true) } } }
                    }
                    Text("📖 شكل القراية", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("↕️ اسكرول", !flip) { if (flip) { val c = cur; flip = false; Lib.cfg.put("mode", "scroll"); Lib.save(); scope.launch { list.scrollToItem(c - 1) } } }
                        Chip("📖 صفحة صفحة", flip) { if (!flip) { val c = cur; flip = true; zoom = 1f; panX = 0f; Lib.cfg.put("mode", "flip"); Lib.save(); scope.launch { pager.scrollToPage(c - 1) } } }
                    }
                    Text("🎧 سرعة الصوت", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(0.75f, 1f, 1.25f, 1.5f).forEach { r -> Chip("${r}x", Speech.rate == r) { Speech.rate = r } } }
                    Text("😴 وقّف الصوت بعد", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(15, 30, 60).forEach { m -> Chip("$m د", false) { Speech.sleepAt = System.currentTimeMillis() + m * 60000L; Toast.makeText(ctx, "😴 الصوت هيقف بعد $m دقيقة", Toast.LENGTH_SHORT).show() } }
                        if (Speech.sleepAt > 0) Chip("❌ إلغاء", true) { Speech.sleepAt = 0 }
                    }
                    Text("🗣 الصوت", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("📱 صوت الموبايل", !Speech.natural()) { Lib.cfg.put("voice", "tts"); Lib.save() }
                        Chip("🗣 صوت طبيعي", Speech.natural()) { Lib.cfg.put("voice", "gem"); Lib.save() }
                    }
                    Text("🌙 التركيز", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("🟠 فلتر دافي", warm) { warm = !warm; Lib.cfg.put("warm", warm); Lib.save() }
                        Chip("🔕 سكّت الإشعارات", Lib.cfg.optBoolean("dnd", false)) {
                            val nm = ctx.getSystemService(android.app.NotificationManager::class.java)
                            if (!nm.isNotificationPolicyAccessGranted) { Toast.makeText(ctx, "فعّل «مكتبتي» من الشاشة اللي هتفتح، وارجع", Toast.LENGTH_LONG).show(); ctx.startActivity(android.content.Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)) }
                            else { Lib.cfg.put("dnd", !Lib.cfg.optBoolean("dnd", false)); Lib.save(); Toast.makeText(ctx, "هتشتغل من المرة الجاية اللي تفتح فيها كتاب", Toast.LENGTH_SHORT).show() }
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip(if (night) "☀️ نهاري" else "🌙 ليلي", night) { night = !night; Lib.cfg.put("night", night); Lib.save() }
                        Chip("🔍 ترجيع الحجم", false) { zoom = 1f; panX = 0f }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip("✅ خلصته", b.optString("sh") == "done") { Lib.setShelf(b, "done"); showTools = false; close() }
                    }
                }
            })
    }
    if (sprintDone) AlertDialog(onDismissRequest = { sprintDone = false },
        confirmButton = { Button({ sprintDone = false }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1F7A55))) { Text("📖 هكمّل شوية") } },
        dismissButton = { TextButton({ sprintDone = false; close() }) { Text("كفاية كده 👋") } },
        title = { Text("👏 الدقيقتين خلصوا!", fontWeight = FontWeight.Bold) },
        text = { Text("كده انت قريت النهارده — وده أهم من أي عدد صفحات 💚\nلو مستمتع كمّل، ولو لأ اقفل وارجع بكره.", fontSize = 16.sp, lineHeight = 26.sp) })
    hook?.let { h ->
        AlertDialog(onDismissRequest = { hook = null }, confirmButton = { Button({ hook = null }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1F7A55))) { Text("يلا نبدأ 📖") } },
            title = { Text("🪝 قبل ما تبدأ…", fontWeight = FontWeight.Bold) },
            text = { if (h.isEmpty()) Text("⏳ …", fontSize = 18.sp) else Text(h, fontSize = 18.sp, lineHeight = 30.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1D2733)) })
    }
    epMsg?.let { m ->
        AlertDialog(onDismissRequest = { epMsg = null }, confirmButton = { Button({ epMsg = null }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1F7A55))) { Text("▶️ حلقة كمان") } },
            dismissButton = { TextButton({ epMsg = null; close() }) { Text("كفاية النهارده") } }, text = { Text(m, fontSize = 17.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold) })
    }
    if (aiMenu) AiMenu({ ai = it; aiMenu = false }) { aiMenu = false }
    ai?.let { k -> AiSheet(k, b, doc, cur, onGo = { p -> scope.launch { goTo(p) } }) { ai = null } }
}

@Composable
private fun AiMenu(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    Sheet("💡 ساعدني أفهم", onDismiss) {
        listOf("explain" to "💡 اشرحلي الصفحة دي", "word" to "🔤 كلمة أو جملة مش فاهمها", "ask" to "💬 اسأل الكتاب أي سؤال", "quote" to "💬 احفظ اقتباس من الصفحة", "find" to "🔎 دوّر جوه الكتاب", "ideas" to "💼 أفكار من الكتاب لشغلي").forEach { (k, t) ->
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
fun PageView(doc: Doc, p: Int, w: Int, night: Boolean, fit: Boolean = false, b: JSONObject? = null, hlMode: Boolean = false, onHl: ((Int, FloatArray) -> Unit)? = null) {
    var bm by remember(p, w) { mutableStateOf<Bitmap?>(null) }
    var ratio by remember(p) { mutableFloatStateOf(1.414f) }
    LaunchedEffect(p, w) { try { ratio = doc.ratio(p); bm = doc.render(p, (w * 1.6f).toInt().coerceAtMost(2000)) } catch (_: Exception) {} }
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    val marks = b?.optJSONArray("hl")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it) }.filter { it.optInt("p") == p }.mapNotNull { o -> o.optJSONArray("r")?.let { r -> FloatArray(4) { k -> r.optDouble(k).toFloat() } } } } ?: emptyList()
    var drag by remember { mutableStateOf<FloatArray?>(null) }
    Box((if (fit) Modifier.fillMaxSize().wrapContentSize().aspectRatio(1f / ratio, matchHeightConstraintsFirst = ratio > 1.3f) else Modifier.fillMaxWidth().aspectRatio(1f / ratio)).padding(horizontal = 6.dp).clip(RoundedCornerShape(4.dp)).background(Color.White), Alignment.Center) {
        val img = bm
        if (img != null) Image(img.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds,
            colorFilter = if (night) androidx.compose.ui.graphics.ColorFilter.colorMatrix(androidx.compose.ui.graphics.ColorMatrix(floatArrayOf(
                -0.9f, 0f, 0f, 0f, 235f, 0f, -0.9f, 0f, 0f, 235f, 0f, 0f, -0.9f, 0f, 235f, 0f, 0f, 0f, 1f, 0f))) else null)
        else Text("$p", color = Color(0xFFBBBBBB), fontSize = 22.sp)
        // 🖍 التعليمات المحفوظة + اللي بتعلّمه دلوقتي
        androidx.compose.foundation.Canvas(Modifier.matchParentSize().then(if (hlMode && onHl != null) Modifier.pointerInput(p) {
            detectDragGestures(
                onDragStart = { o -> drag = floatArrayOf(o.x / size.width, o.y / size.height, o.x / size.width, o.y / size.height) },
                onDrag = { ch, _ -> val d = drag; if (d != null) drag = floatArrayOf(d[0], d[1], (ch.position.x / size.width).coerceIn(0f, 1f), (ch.position.y / size.height).coerceIn(0f, 1f)) },
                onDragEnd = {
                    val d = drag; drag = null
                    if (d != null) {
                        val th = 0.018f
                        val r = floatArrayOf(minOf(d[0], d[2]), (minOf(d[1], d[3]) - th).coerceAtLeast(0f), maxOf(d[0], d[2]), (maxOf(d[1], d[3]) + th).coerceAtMost(1f))
                        if (r[2] - r[0] > 0.04f) onHl(p, r)
                    }
                },
                onDragCancel = { drag = null })
        } else Modifier)) {
            val hc = Color(0x66FFE14D)
            (marks + listOfNotNull(drag?.let { d -> floatArrayOf(minOf(d[0], d[2]), minOf(d[1], d[3]) - 0.018f, maxOf(d[0], d[2]), maxOf(d[1], d[3]) + 0.018f) })).forEach { r ->
                drawRect(hc, androidx.compose.ui.geometry.Offset(r[0] * size.width, r[1] * size.height), androidx.compose.ui.geometry.Size((r[2] - r[0]) * size.width, (r[3] - r[1]) * size.height))
            }
        }
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
