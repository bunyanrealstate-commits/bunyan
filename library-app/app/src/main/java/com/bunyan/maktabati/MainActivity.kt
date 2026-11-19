package com.bunyan.maktabati

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

val Green = Color(0xFF1F7A55)
val Ink = Color(0xFF1D2733)
val Muted = Color(0xFF7A6A55)
val Paper = Color(0xFFFBF6EC)
val Card = Color(0xFFFFFFFF)
val Sand = Color(0xFFF1EADB)
val Flame = Color(0xFFF0A04B)

class MainActivity : androidx.fragment.app.FragmentActivity() {
    private val incoming = mutableStateOf<Intent?>(null)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Lib.init(this)
        if (android.os.Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)  // 🔒 محدش يشوف الكتب من «التطبيقات الأخيرة»
        incoming.value = intent
        setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                MaterialTheme(colorScheme = lightColorScheme(primary = Green, background = Paper, surface = Card)) {
                    App(incoming)
                }
            }
        }
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); incoming.value = intent }
    /* 🔊 زراير الصوت بتقلب الصفحات جوه الكتاب */
    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        val k = event.keyCode
        if (Keys.reader && !Speech.playing && Lib.cfg.optBoolean("volkeys", true) && (k == android.view.KeyEvent.KEYCODE_VOLUME_DOWN || k == android.view.KeyEvent.KEYCODE_VOLUME_UP)) {
            if (event.action == android.view.KeyEvent.ACTION_DOWN) Keys.flow.tryEmit(if (k == android.view.KeyEvent.KEYCODE_VOLUME_DOWN) 1 else -1)
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}

object Keys {
    @Volatile var reader = false
    val flow = kotlinx.coroutines.flow.MutableSharedFlow<Int>(extraBufferCapacity = 8)
}

@Composable
fun App(incoming: MutableState<Intent?>) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var reading by remember { mutableStateOf<JSONObject?>(null) }
    var screen by remember { mutableStateOf("home") }
    var recap by remember { mutableStateOf<Triple<JSONObject, Int, Int>?>(null) }
    var sheet by remember { mutableStateOf<String?>(null) }
    var notes by remember { mutableStateOf<JSONObject?>(null) }
    var searchQ by remember { mutableStateOf("") }
    val notifPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(Unit) {
        Notify.ensure(ctx); Notify.schedule(ctx)
        if (android.os.Build.VERSION.SDK_INT >= 33 && androidx.core.content.ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED)
            notifPerm.launch(android.Manifest.permission.POST_NOTIFICATIONS)
    }
    val dl = Dl.prog
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver

    fun toast(s: String) = Toast.makeText(ctx, s, Toast.LENGTH_SHORT).show()

    var pendingOpen by remember { mutableStateOf<String?>(null) }
    fun fetch(b: JSONObject, open: Boolean) { if (open) pendingOpen = b.optString("id"); Dl.fetch(ctx, b) }
    LaunchedEffect(Dl.done) { val d = Dl.done ?: return@LaunchedEffect; if (d == pendingOpen) { pendingOpen = null; Lib.book(d)?.let { reading = it } }; Dl.done = null }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(4000); Dl.prefetchNext(ctx) }

    fun openBook(b: JSONObject) { if (Lib.have(b)) reading = b else fetch(b, true) }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) addFromUri(ctx, uri)?.let { reading = it }
    }

    LaunchedEffect(incoming.value, Lib.revealed) {
        if (!Lib.revealed) return@LaunchedEffect
        val itn = incoming.value ?: return@LaunchedEffect
        incoming.value = null
        itn.getStringExtra("open")?.let { id -> if (id == "buddy") screen = "buddy" else Lib.book(id)?.let { b -> openBook(b) }; return@LaunchedEffect }
        val d = itn.data ?: return@LaunchedEffect
        if (d.scheme == "bnylib") {
            val code = d.getQueryParameter("c") ?: d.fragment ?: ""
            if (!linkWith(code)) toast("⚠️ كود الربط مش مظبوط") else { toast("✅ اتربط بحساب بنيان — بنزّل مكتبتك…"); Lib.msg = Lib.sync(); toast(Lib.msg); screen = "home" }
        } else if (itn.action == Intent.ACTION_VIEW) addFromUri(ctx, d)?.let { b -> reading = b }
    }
    LaunchedEffect(Unit) { if (Lib.link != null) Lib.msg = Lib.sync(); Lib.comeback()?.let { toast(it) } }
    // تحديث التطبيق لوحده + ربط تلقائي لو كود الربط متنسخ (زرار بنيان بينسخه)
    var hiddenAt by remember { mutableLongStateOf(0L) }
    val life = androidx.compose.ui.platform.LocalLifecycleOwner.current
    DisposableEffect(life) {
        val ob = androidx.lifecycle.LifecycleEventObserver { _, e ->
            if (e == androidx.lifecycle.Lifecycle.Event.ON_STOP) hiddenAt = System.currentTimeMillis()
            if (e == androidx.lifecycle.Lifecycle.Event.ON_START && hiddenAt > 0 && System.currentTimeMillis() - hiddenAt > 60_000) { Lib.revealed = false; reading = null; screen = "home"; sheet = null; notes = null }
            if (e == androidx.lifecycle.Lifecycle.Event.ON_RESUME) scope.launch {
                kotlinx.coroutines.delay(700)
                if (Lib.link == null) try {
                    val cm = ctx.getSystemService(android.content.ClipboardManager::class.java)
                    val t = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(ctx)?.toString() ?: ""
                    if (t.contains("BNYLINK-") && linkWith(t)) { toast("✅ اتربط بحساب بنيان — بنزّل مكتبتك…"); Lib.msg = Lib.sync(); toast(Lib.msg) }
                } catch (_: Exception) {}
                Updater.check(ctx)?.let { toast(it) }
            }
        }
        life.lifecycle.addObserver(ob); onDispose { life.lifecycle.removeObserver(ob) }
    }

    if (!Lib.revealed) { DecoyScreen(); return }
    val r = reading
    if (r != null) { ReaderScreen(r) { from, to, read ->
        reading = null
        if (read >= 2 && Net.hasGem()) recap = Triple(r, from, to)
        if (Net.hasGem()) Lib.bg.launch { prepNext(r, to) }
        Notify.schedule(ctx)
        scope.launch { Lib.sync() }
        Dl.prefetchNext(ctx)
    }; return }
    recap?.let { (b, f, t) -> RecapSheet(b, f, t) { recap = null } }
    when (sheet) {
        "rec" -> RecommendSheet({ sheet = null }) { q -> sheet = null; searchQ = q; screen = "search" }
        "set" -> SettingsSheet { sheet = null }
        "jar" -> JarSheet { sheet = null }
    }
    notes?.let { NotesSheet(it) { notes = null } }

    when (screen) {
        "search" -> SearchScreen(searchQ, onBack = { screen = "home"; searchQ = "" }) { h ->
            val b = Lib.addLocal(h.title, h.author) { it.put("ia", h.id) }
            screen = "home"; fetch(b, false); toast("⬇️ بنزّل «${h.title}»")
        }
        "link" -> LinkScreen { screen = "home" }
        "buddy" -> BuddyScreen { screen = "home" }
        "journey" -> JourneyScreen({ screen = "home" }) { b -> screen = "home"; openBook(b) }
        "paper" -> PaperScreen { screen = "home" }
        else -> HomeScreen(dl, onOpen = { openBook(it) }, onFetch = { fetch(it, false) }, onSearch = { screen = "search" },
            onPick = { pick.launch(arrayOf("application/pdf")) }, onLink = { screen = "link" },
            onSync = { scope.launch { Lib.msg = Lib.sync(); toast(Lib.msg) } },
            onRec = { sheet = "rec" }, onSettings = { sheet = "set" }, onNotes = { notes = it },
            onMore = { k -> if (k == "jar") sheet = "jar" else screen = k },
            onSearchQ = { q -> searchQ = q; screen = "search" })
    }
}

fun addFromUri(ctx: android.content.Context, uri: Uri): JSONObject? = try {
    var name = "كتاب"
    ctx.contentResolver.query(uri, null, null, null, null)?.use { c -> val i = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME); if (i >= 0 && c.moveToFirst()) name = c.getString(i) }
    val title = name.removeSuffix(".pdf").removeSuffix(".PDF").replace('_', ' ')
    val b = Lib.book(Lib.books.firstOrNull { it.optString("t") == title && !Lib.have(it) }?.optString("id") ?: "") ?: Lib.addLocal(title, "") {}
    ctx.contentResolver.openInputStream(uri)!!.use { inp -> File(Lib.dir, "books/${b.optString("id")}.pdf").outputStream().use { inp.copyTo(it) } }
    cover(b); Lib.save(); b
} catch (e: Exception) { Toast.makeText(ctx, "⚠️ مقدرتش أفتح الملف", Toast.LENGTH_SHORT).show(); null }

fun cover(b: JSONObject) {
    val f = File(Lib.dir, "covers/${b.optString("id")}.jpg"); if (f.exists()) return
    try {
        val files = Lib.files(b); if (files.isEmpty()) return
        val pfd = android.os.ParcelFileDescriptor.open(files[0], android.os.ParcelFileDescriptor.MODE_READ_ONLY)
        android.graphics.pdf.PdfRenderer(pfd).use { r -> r.openPage(0).use { pg ->
            val w = 300; val h = (w.toFloat() * pg.height / pg.width).toInt()
            val bm = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888); bm.eraseColor(android.graphics.Color.WHITE)
            pg.render(bm, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            f.outputStream().use { bm.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        } }
        pfd.close()
    } catch (_: Exception) {}
}

@Composable
fun Cover(b: JSONObject, modifier: Modifier) {
    val f = File(Lib.dir, "covers/${b.optString("id")}.jpg")
    val bm = remember(b.optString("id"), f.exists(), Lib.ver) { if (f.exists()) BitmapFactory.decodeFile(f.path) else null }
    Box(modifier.clip(RoundedCornerShape(10.dp)).background(Brush.verticalGradient(listOf(Color(0xFF2E8B67), Color(0xFF1B5E44)))), Alignment.Center) {
        if (bm != null) Image(bm.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        else Text(b.optString("t"), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(8.dp), maxLines = 4)
    }
}

@Composable
fun HomeScreen(dl: Map<String, Float>, onOpen: (JSONObject) -> Unit, onFetch: (JSONObject) -> Unit, onSearch: () -> Unit, onPick: () -> Unit, onLink: () -> Unit, onSync: () -> Unit,
               onRec: () -> Unit, onSettings: () -> Unit, onNotes: (JSONObject) -> Unit, onMore: (String) -> Unit = {}, onSearchQ: (String) -> Unit = {}) {
    val hctx = LocalContext.current
    val hscope = rememberCoroutineScope()
    var epBusy by remember { mutableStateOf("") }
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    var shelf by remember { mutableStateOf("now") }
    var tab by rememberSaveable { mutableStateOf("home") }
    BackHandler(tab != "home") { tab = "home" }
    var q by remember { mutableStateOf("") }
    var menu by remember { mutableStateOf<JSONObject?>(null) }
    var goalDlg by remember { mutableStateOf(false) }
    var rate by remember { mutableStateOf<JSONObject?>(null) }
    var year by remember { mutableStateOf(false) }
    var about by remember { mutableStateOf<JSONObject?>(null) }
    val cur = Lib.current()
    val today = Lib.todayPages(); val goal = Lib.goal; val st = Lib.streak()
    val list = Lib.books.filter { it.optString("sh", "want") == shelf && (q.isBlank() || it.optString("t").contains(q) || it.optString("a").contains(q)) }
        .let { l -> if (shelf == "want") l.sortedBy { b -> Lib.queue.indexOf(b.optString("id")).let { if (it < 0) 9999 else it } } else l.sortedByDescending { it.optLong("rd", 0) } }

    Column(Modifier.fillMaxSize().background(Paper)) {
    LazyVerticalGrid(GridCells.Fixed(3), Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(start = 14.dp, end = 14.dp, top = 0.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item(span = { GridItemSpan(3) }) {
            Row(Modifier.statusBarsPadding().padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(when (tab) { "books" -> "📚 كتبي"; "find" -> "🧭 اكتشف"; "me" -> "🏅 إنجازاتي"; else -> "📚 مكتبتي" }, fontSize = 26.sp, fontWeight = FontWeight.Black, color = Ink, modifier = Modifier.weight(1f))
                if (Lib.syncing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                else if (Lib.link != null) Text("🔄", fontSize = 20.sp, modifier = Modifier.clickable { onSync() }.padding(8.dp))
                Text("⚙️", fontSize = 20.sp, modifier = Modifier.clickable { onSettings() }.padding(8.dp))
            }
        }
        if (tab == "home") {
        if (Lib.link != null && Lib.msg.isNotEmpty() && !Lib.msg.startsWith("تمام")) item(span = { GridItemSpan(3) }) {
            Surface(onClick = onSync, shape = RoundedCornerShape(14.dp), color = Color(0xFFFDECEC)) {
                Text((if (Lib.solo()) "⚠️ النسخة الاحتياطية: " else "⚠️ المزامنة مع بنيان: ") + Lib.msg + " — دوس هنا تجرب تاني", Modifier.padding(12.dp), color = Color(0xFFB3261E), fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
        }
        if (Lib.link == null) item(span = { GridItemSpan(3) }) {
            Surface(onClick = onLink, shape = RoundedCornerShape(18.dp), color = Color(0xFFE8F3EE)) {
                Column(Modifier.padding(14.dp)) {
                    Text("🔗 كتبك لسه منزلتش — التطبيق مش مربوط ببنيان", fontWeight = FontWeight.Black, color = Green, fontSize = 16.sp)
                    Text("1) دوس الزرار ده هيفتحلك بنيان\n2) في بنيان ادخل «مكتبتي» ودوس «📱 افتح في تطبيق مكتبتي»\n3) هيرجعك هنا وكتبك تنزل لوحدها", fontSize = 14.sp, color = Ink, lineHeight = 24.sp, modifier = Modifier.padding(vertical = 8.dp))
                    val lctx = LocalContext.current
                    Button({
                        val i = lctx.packageManager.getLaunchIntentForPackage("com.bunyan.furnished")
                        if (i != null) lctx.startActivity(i) else Toast.makeText(lctx, "تطبيق بنيان مش متسطّب على الموبايل ده", Toast.LENGTH_LONG).show()
                    }, Modifier.fillMaxWidth().height(50.dp), colors = ButtonDefaults.buttonColors(containerColor = Green), shape = RoundedCornerShape(14.dp)) { Text("افتح بنيان", fontWeight = FontWeight.Bold, fontSize = 16.sp) }
                }
            }
        }
        // ⏱ رجوع سهل لو بقالك فترة مش بتقرا
        if (cur != null && today == 0 && st == 0) item(span = { GridItemSpan(3) }) {
            val idle = Lib.idleDays()
            Surface(shape = RoundedCornerShape(22.dp), color = Color(0xFFE8F3EE)) {
                Column(Modifier.padding(16.dp)) {
                    Text(if (idle >= 999) "👋 أول خطوة أسهل مما تتخيل" else if (idle >= 2) "👋 وحشتنا… بقالك $idle يوم" else "👋 لسه مقرتش النهارده", fontWeight = FontWeight.Black, fontSize = 18.sp, color = Green)
                    Text("مش مطلوب منك كتاب ولا فصل — دقيقتين بس، ولو عايز تقفل بعدها اقفل 😉\nأو اسمعه وانت سايق أو قبل ما تنام 🎧", fontSize = 14.sp, color = Ink, lineHeight = 23.sp, modifier = Modifier.padding(vertical = 8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button({ Lib.sprint = true; onOpen(cur) }, Modifier.weight(1f).height(54.dp), shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("⏱ دقيقتين بس", fontWeight = FontWeight.Black, fontSize = 16.sp) }
                        OutlinedButton({ listenNow(hctx, cur, onFetch) }, Modifier.weight(1f).height(54.dp), shape = RoundedCornerShape(16.dp)) { Text("🎧 اسمعه", fontWeight = FontWeight.Black, fontSize = 16.sp, color = Green) }
                    }
                }
            }
        }
        // الكتاب الحالي
        if (cur != null) item(span = { GridItemSpan(3) }) {
            val pg = cur.optInt("pg", 0); val c = cur.optInt("cur", 0)
            Surface(shape = RoundedCornerShape(22.dp), color = Color(0xFFFFF4E0), modifier = Modifier.border(1.dp, Color(0xFFF0D9B5), RoundedCornerShape(22.dp))) {
                Column(Modifier.padding(16.dp)) {
                    Row {
                        Column(Modifier.weight(1f)) {
                            Text(if (cur.optString("sh") == "now") "بتقرأ دلوقتي" else "الكتاب الجاي", color = Flame, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text(cur.optString("t"), fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(cur.optString("a"), color = Muted, fontSize = 13.sp, maxLines = 1)
                            Spacer(Modifier.height(10.dp))
                            if (pg > 0) {
                                LinearProgressIndicator(progress = { (c.toFloat() / pg).coerceIn(0f, 1f) }, Modifier.fillMaxWidth().height(8.dp).clip(CircleShape), color = Green, trackColor = Sand)
                                Text("صفحة $c من $pg • ${c * 100 / pg}%" + remain(cur, pg - c), fontSize = 12.sp, color = Muted, modifier = Modifier.padding(top = 4.dp))
                            }
                            val ep = Boost.epAt(cur, maxOf(1, c))
                            if (ep != null) Text("📺 الحلقة ${ep.first + 1} من ${Boost.eps(cur).size}: «${ep.second.optString("n")}»", fontSize = 13.sp, color = Color(0xFF7B3FA0), fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp), maxLines = 2)
                            else if (Lib.have(cur) && pg > 0) Text(if (epBusy.isNotEmpty()) epBusy else "📺 قسّمه حلقات قصيرة زي المسلسل", fontSize = 13.sp, color = Color(0xFF7B3FA0), fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(top = 6.dp).clickable { if (epBusy.isEmpty()) hscope.launch { epBusy = "⏳ بجهّز الحلقات…"; Boost.genEpisodes(cur) { epBusy = it }; epBusy = "" } })
                        }
                        Spacer(Modifier.width(12.dp))
                        Cover(cur, Modifier.width(78.dp).height(110.dp))
                    }
                    Spacer(Modifier.height(12.dp))
                    val p = dl[cur.optString("id")]
                    Button(onClick = { onOpen(cur) }, Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = Green), enabled = p == null) {
                        Text(when { p != null -> "⬇️ بنزّل… ${(p * 100).toInt()}%"; !Lib.have(cur) -> "⬇️ نزّله وابدأ"; Boost.epAt(cur, maxOf(1, c)) != null -> "▶️ كمّل الحلقة"; c > 1 -> "📖 كمّل من صفحة $c"; else -> "📖 ابدأ القراية" }, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    }
                    val lst = Speech.playing && Speech.bookId == cur.optString("id")
                    OutlinedButton({ if (lst) Speech.stop(hctx) else listenNow(hctx, cur, onFetch) }, Modifier.fillMaxWidth().padding(top = 8.dp).height(46.dp), shape = RoundedCornerShape(16.dp), enabled = p == null) {
                        Text(if (lst) "⏸ وقّف الصوت (صفحة ${Speech.page})" else "🎧 اسمعه بدل ما تقراه — والشاشة مقفولة", fontWeight = FontWeight.Bold, color = Green)
                    }
                }
            }
        }
        // هدف اليوم + الشمعة
        item(span = { GridItemSpan(3) }) {
            Surface(onClick = { onSettings() }, shape = RoundedCornerShape(20.dp), color = Card) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(64.dp), Alignment.Center) {
                        CircularProgressIndicator(progress = { (today.toFloat() / goal).coerceIn(0f, 1f) }, Modifier.fillMaxSize(), color = Flame, trackColor = Sand, strokeWidth = 6.dp)
                        Text("$today", fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink)
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(if (goal == 1) "1️⃣ التحدي: صفحة واحدة بس" else "هدف النهارده: $goal صفحات", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Ink)
                        Text(if (goal == 1) (if (today >= 1) "✅ عدّيت التحدي! وقريت $today — كل صفحة زيادة بونص 💪" else "افتح الكتاب واقرا صفحة واحدة… بس كده 😉") else if (today >= goal) "🎉 خلّصت هدف النهارده!" else "فاضلك ${goal - today} صفحة بس", color = Muted, fontSize = 13.sp)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (st > 0) "🔥" else "🕯", fontSize = 26.sp)
                        Text("$st يوم", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = if (st > 0) Flame else Muted)
                    }
                }
            }
        }
        item(span = { GridItemSpan(3) }) { MotivationCards { onMore("jar") } }
        item(span = { GridItemSpan(3) }) { ReviewCard() }
        }
        if (tab == "books") {
        item(span = { GridItemSpan(3) }) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Action("🔎", "نزّل كتاب", Modifier.weight(1f), onSearch)
                Action("📄", "من موبايلي", Modifier.weight(1f), onPick)
                Action("📷", "كتاب ورق", Modifier.weight(1f)) { onMore("paper") }
                Action(if (Lib.link == null) "🔗" else "☁️", if (Lib.link == null) "اربط" else "محفوظ احتياطي", Modifier.weight(1f), onLink)
            }
        }
        // الرفوف
        item(span = { GridItemSpan(3) }) {
            Column {
                Row(Modifier.clip(RoundedCornerShape(14.dp)).background(Sand).padding(4.dp)) {
                    listOf("now" to "📖 بقراه", "want" to "📌 عايز", "done" to "✅ خلصته", "dnf" to "🚫 سبته").forEach { (k, t) ->
                        val n = Lib.books.count { it.optString("sh", "want") == k }
                        Surface(onClick = { shelf = k }, shape = RoundedCornerShape(11.dp), color = if (shelf == k) Card else Color.Transparent, modifier = Modifier.weight(1f)) {
                            Text("$t $n", Modifier.padding(vertical = 9.dp), textAlign = TextAlign.Center, fontWeight = FontWeight.Bold, fontSize = 13.sp, color = if (shelf == k) Ink else Muted)
                        }
                    }
                }
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth().padding(top = 8.dp), placeholder = { Text("🔎 دوّر في كتبك") }, singleLine = true, shape = RoundedCornerShape(14.dp))
            }
        }
        if (list.isEmpty()) item(span = { GridItemSpan(3) }) { Text(if (shelf == "dnf") "الكتاب اللي مش عاجبك سيبه من غير ذنب — زي Goodreads «Did not finish» 🙂" else "مفيش كتب هنا", Modifier.fillMaxWidth().padding(30.dp), textAlign = TextAlign.Center, color = Muted) }
        items(list, key = { it.optString("id") }) { b ->
            val p = dl[b.optString("id")]; val have = Lib.have(b)
            Column(Modifier.clickable { menu = b }) {
                Box {
                    Cover(b, Modifier.fillMaxWidth().aspectRatio(0.7f))
                    if (!have && p == null) Text("⬇️", Modifier.align(Alignment.TopStart).padding(4.dp).clip(CircleShape).background(Color(0xCCFFFFFF)).padding(4.dp), fontSize = 12.sp)
                    if (p != null) CircularProgressIndicator(progress = { p }, Modifier.align(Alignment.Center).size(36.dp), color = Color.White, trackColor = Color(0x55FFFFFF))
                }
                val pg = b.optInt("pg"); if (pg > 0 && b.optInt("cur") > 0) LinearProgressIndicator(progress = { (b.optInt("cur").toFloat() / pg).coerceIn(0f, 1f) }, Modifier.fillMaxWidth().padding(top = 4.dp).height(4.dp).clip(CircleShape), color = Green, trackColor = Sand)
                Text(b.optString("t"), fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, color = Ink, modifier = Modifier.padding(top = 4.dp))
                if (b.optInt("r") > 0) Stars(b.optInt("r"), 12)
            }
        }
        }
        if (tab == "find") {
        item(span = { GridItemSpan(3) }) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Action("✨", "أقرا إيه بعد كده؟", Modifier.weight(1f), onRec)
                Action("💬", "رفيق القراية", Modifier.weight(1f)) { onMore("buddy") }
            }
        }
        item(span = { GridItemSpan(3) }) { Text("🧭 استكشف بالتصنيف", fontWeight = FontWeight.Black, fontSize = 17.sp, color = Ink) }
        item(span = { GridItemSpan(3) }) { ExploreBody { q -> onSearchQ(q) } }
        }
        if (tab == "me") {
        item(span = { GridItemSpan(3) }) { ChallengeCard { year = true } }
        item(span = { GridItemSpan(3) }) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Action("📖", "سنتي في القراية", Modifier.weight(1f)) { year = true }
                Action("🗺", "رحلتي", Modifier.weight(1f)) { onMore("journey") }
            }
        }
        item(span = { GridItemSpan(3) }) { Column(Modifier.padding(top = 10.dp)) { StatsAndBadges() } }
        item(span = { GridItemSpan(3) }) { Text("«عشر صفحات كل يوم = حوالي 12 كتاب في السنة»", Modifier.fillMaxWidth().padding(top = 16.dp), textAlign = TextAlign.Center, color = Muted, fontSize = 13.sp) }
        item(span = { GridItemSpan(3) }) { Surface(shape = RoundedCornerShape(20.dp), color = Card) { Column(Modifier.padding(14.dp)) { StatsBody() } } }
        }
    }
    NavigationBar(containerColor = Card, tonalElevation = 0.dp) {
        listOf(Triple("home", "🏠", "الرئيسية"), Triple("books", "📚", "كتبي"), Triple("find", "🧭", "اكتشف"), Triple("me", "🏅", "إنجازاتي")).forEach { (k, ic, t) ->
            NavigationBarItem(selected = tab == k, onClick = { tab = k }, icon = { Text(ic, fontSize = 22.sp) }, label = { Text(t, fontWeight = FontWeight.Bold, fontSize = 12.sp) },
                colors = NavigationBarItemDefaults.colors(indicatorColor = Color(0xFFE8F3EE), selectedTextColor = Green, unselectedTextColor = Muted))
        }
    }
    }
    WeeklyReport()

    menu?.let { b ->
        AlertDialog(onDismissRequest = { menu = null }, confirmButton = { TextButton({ menu = null }) { Text("قفل") } },
            title = { Text(b.optString("t"), fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (b.optString("a").isNotEmpty()) Text(b.optString("a"), color = Muted)
                    Button({ menu = null; onOpen(b) }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text(if (Lib.have(b)) "📖 اقرأ" else "⬇️ نزّل واقرأ") }
                    val nq = (b.optJSONArray("q")?.length() ?: 0) + (b.optJSONArray("sums")?.length() ?: 0)
                    OutlinedButton({ menu = null; onNotes(b) }, Modifier.fillMaxWidth()) { Text("💬 اقتباساتي وملخصاتي ($nq)") }
                    if (b.optString("sh") == "done") Row(verticalAlignment = Alignment.CenterVertically) { Text("تقييمك: ", color = Muted); Stars(b.optInt("r"), 26) { menu = null; rate = b } }
                    if (Net.hasGem()) OutlinedButton({ menu = null; about = b }, Modifier.fillMaxWidth()) { Text("ℹ️ عن الكتاب") }
                    if (Net.hasGem()) OutlinedButton({ menu = null; recSeed = b; onRec() }, Modifier.fillMaxWidth()) { Text("👥 اللي حبّوه حبّوا كمان…") }
                    if (!Lib.have(b) && b.optString("ia").isNotEmpty()) OutlinedButton({ menu = null; onFetch(b) }, Modifier.fillMaxWidth()) { Text("⬇️ نزّله بس") }
                    if (Net.hasGem() && b.optString("sh") != "want" && b.optJSONObject("ch") == null) OutlinedButton({ val bb = b; menu = null; Toast.makeText(hctx, "⏳ بجهّزلك تحدي من الكتاب…", Toast.LENGTH_SHORT).show()
                        hscope.launch { Toast.makeText(hctx, if (Boost.genChallenge(bb)) "🛠 التحدي في الصفحة الرئيسية" else "⚠️ مقدرتش دلوقتي", Toast.LENGTH_SHORT).show() } }, Modifier.fillMaxWidth()) { Text("🛠 طبّقها: تحدي من الكتاب") }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("want" to "📌 عايز", "now" to "📖 بقراه", "done" to "✅ خلصته", "dnf" to "🚫 سبته").forEach { (k, t) -> Chip(t, b.optString("sh", "want") == k) { Lib.setShelf(b, k); menu = null; if (k == "done") rate = b; if (k == "dnf") Toast.makeText(hctx, "🚫 سيبناه — مش كل كتاب لازم يكمل. شوف الجاي 👇", Toast.LENGTH_SHORT).show()
                            if (k == "done" && Net.hasGem() && b.optJSONObject("ch") == null) hscope.launch { if (Boost.genChallenge(b)) Toast.makeText(hctx, "🛠 ليك تحدي تطبّقه من الكتاب ده — في الرئيسية", Toast.LENGTH_LONG).show() } } }
                    }
                    if (Lib.have(b)) TextButton({ Lib.files(b).forEach { it.delete() }; Lib.save(); menu = null }) { Text("🗑 امسح الملف من الموبايل (التقدم بيفضل)", color = Color(0xFFB3261E)) }
                }
            })
    }
    rate?.let { RateSheet(it) { rate = null } }
    about?.let { AboutSheet(it) { about = null } }
    if (year) YearSheet({ year = false }) { menu = it }
    if (goalDlg) {
        AlertDialog(onDismissRequest = { goalDlg = false }, confirmButton = { TextButton({ goalDlg = false }) { Text("تمام") } },
            title = { Text("🎯 هدفك كل يوم") }, text = {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(5, 10, 15, 20, 30).forEach { g -> Chip("$g", Lib.goal == g) { Lib.goal = g; Lib.save() } } }
            })
    }
}

@Composable
fun Action(ic: String, t: String, m: Modifier, click: () -> Unit) {
    Surface(onClick = click, shape = RoundedCornerShape(16.dp), color = Card, modifier = m.border(1.dp, Color(0xFFEADFCA), RoundedCornerShape(16.dp))) {
        Column(Modifier.padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(ic, fontSize = 22.sp); Text(t, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Ink)
        }
    }
}

@Composable
fun SearchScreen(initial: String, onBack: () -> Unit, onPick: (Net.Hit) -> Unit) {
    BackHandler { onBack() }
    val scope = rememberCoroutineScope()
    var q by remember { mutableStateOf(initial) }
    var busy by remember { mutableStateOf(false) }
    var res by remember { mutableStateOf<List<Net.Hit>?>(null) }
    var err by remember { mutableStateOf("") }
    fun go() { if (q.isBlank()) return; busy = true; err = ""; scope.launch { try { res = Net.search(q.trim()) } catch (e: Exception) { err = "⚠️ مفيش نت؟"; res = null }; busy = false } }
    Column(Modifier.fillMaxSize().background(Paper).statusBarsPadding().padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp))
            Text("🔎 نزّل كتاب من أرشيف الإنترنت", fontWeight = FontWeight.Black, fontSize = 18.sp, color = Ink)
        }
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth(), placeholder = { Text("اسم الكتاب أو المؤلف") }, singleLine = true, shape = RoundedCornerShape(14.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search), keyboardActions = KeyboardActions(onSearch = { go() }),
            trailingIcon = { TextButton({ go() }) { Text("دوّر") } })
        LaunchedEffect(Unit) { if (initial.isNotBlank()) go() }
        if (busy) LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 8.dp), color = Green)
        if (err.isNotEmpty()) Text(err, color = Color(0xFFB3261E), modifier = Modifier.padding(8.dp))
        LazyColumn(Modifier.fillMaxSize().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val r = res
            if (r != null && r.isEmpty()) item { Text("ملقتش حاجة — جرّب اسم أقصر أو اسم المؤلف", color = Muted, modifier = Modifier.padding(16.dp)) }
            items(r ?: emptyList()) { h ->
                Surface(onClick = { onPick(h) }, shape = RoundedCornerShape(14.dp), color = Card) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(h.title, fontWeight = FontWeight.Bold, color = Ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            if (h.author.isNotEmpty()) Text(h.author, color = Muted, fontSize = 12.sp, maxLines = 1)
                        }
                        Text("⬇️", fontSize = 20.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun LinkScreen(onBack: () -> Unit) {
    BackHandler { onBack() }
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var code by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().background(Paper).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) { IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp)); Text(if (Lib.solo()) "☁️ النسخة الاحتياطية" else "🔗 الربط بحساب بنيان", fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink) }
        if (Lib.link != null) {
            if (Lib.solo()) Text("🔓 مكتبتي تطبيق لوحده — مش مربوط ببنيان ولا بأي برنامج تاني.\nكتبك وتقدمك محفوظين على الموبايل، ونسخة احتياطية منهم في ملف خاص بمكتبتي بس (لو غيّرت الموبايل بترجع لوحدها).", color = Green, fontWeight = FontWeight.Bold, lineHeight = 24.sp)
            else Text("✅ التطبيق مربوط بحسابك. كتبك وتقدمك بيتزامنوا مع مكتبتي في بنيان.", color = Green, fontWeight = FontWeight.Bold)
            if (Lib.msg.isNotEmpty()) Text("آخر مرة: " + Lib.msg, color = Muted, fontSize = 13.sp)
            OutlinedButton({ scope.launch { Toast.makeText(ctx, Lib.sync(), Toast.LENGTH_SHORT).show() } }, Modifier.fillMaxWidth()) { Text(if (Lib.solo()) "☁️ احفظ نسخة احتياطية دلوقتي" else "🔄 زامن دلوقتي") }
            if (!Lib.solo()) TextButton({ Lib.link = null; Lib.save() }) { Text("فك الربط", color = Color(0xFFB3261E)) }
        } else {
            Text("أسهل طريقة: افتح بنيان ← مكتبتي ← دوس «📱 افتح في تطبيق مكتبتي» وهيتربط لوحده.", fontSize = 15.sp, color = Ink, lineHeight = 24.sp)
            Text("أو الصق كود الربط (BNYLINK-…) هنا:", color = Muted)
            OutlinedTextField(code, { code = it }, Modifier.fillMaxWidth().height(120.dp), shape = RoundedCornerShape(14.dp))
            Button({
                val o = Lib.parseLink(code)
                if (o == null) Toast.makeText(ctx, "⚠️ الكود مش مظبوط", Toast.LENGTH_SHORT).show() else {
                    Lib.link = JSONObject().put("r", o.optString("r")).put("t", o.optString("t")).put("p", o.optString("p", "book.json")).put("g", o.optString("g"))
                    Lib.save(); scope.launch { Lib.msg = Lib.sync(); Toast.makeText(ctx, Lib.msg, Toast.LENGTH_LONG).show(); onBack() }
                }
            }, Modifier.fillMaxWidth().height(50.dp), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("اربط", fontWeight = FontWeight.Bold) }
        }
        Spacer(Modifier.height(20.dp))
        OutlinedButton({ scope.launch { Toast.makeText(ctx, Updater.check(ctx, true) ?: "", Toast.LENGTH_LONG).show() } }, Modifier.fillMaxWidth()) { Text("⬆️ شوف لو فيه تحديث للتطبيق") }
        Text("نسخة التطبيق: " + Updater.myVersion(ctx) + " — بيتحدث لوحده", color = Muted, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
    }
}

/** يحضّر أول فقرة من الصفحة اللي وقفت عندها علشان إشعار «5 دقايق» */
suspend fun prepNext(b: JSONObject, p: Int) {
    try {
        val doc = Doc(Lib.files(b)); if (p !in 1..doc.count) { doc.close(); return }
        val bm = doc.render(p, 1100); doc.close()
        val t = Net.ask("اكتب أول فقرة في الصفحة دي بالظبط زي ما هي مكتوبة (حوالي 300 حرف)، من غير رقم الصفحة ولا العنوان المتكرر ومن غير أي تعليق.", listOf(bm))?.trim() ?: return
        if (t.length > 30) { b.put("nx", JSONObject().put("p", p).put("t", t.take(330))); Lib.save() }
    } catch (_: Exception) {}
}

fun linkWith(code: String): Boolean {
    val o = Lib.parseLink(code) ?: return false
    Lib.link = JSONObject().put("r", o.optString("r")).put("t", o.optString("t")).put("p", o.optString("p", "book.json").ifEmpty { "book.json" }).put("g", o.optString("g"))
    Lib.save(); return true
}

/** 🎧 يشغّل الكتاب بالصوت من غير ما يفتحه (والسماع بيتحسب قراية) */
fun listenNow(ctx: android.content.Context, b: JSONObject, onFetch: (JSONObject) -> Unit) {
    when {
        !Net.hasGem() -> Toast.makeText(ctx, "محتاج Gemini — اربط التطبيق ببنيان الأول", Toast.LENGTH_LONG).show()
        !Lib.have(b) -> { onFetch(b); Toast.makeText(ctx, "⬇️ بنزّل الكتاب… دوس «اسمعه» تاني لما يخلص", Toast.LENGTH_LONG).show() }
        else -> { Speech.start(ctx, b, b.optInt("cur", 1).coerceAtLeast(1)); Toast.makeText(ctx, "🎧 بيبدأ دلوقتي… اقفل الشاشة وريّح 😌", Toast.LENGTH_SHORT).show() }
    }
}


/* ───── 🔒 الشاشة اللي أي حد يشوفها: مكتبة فاضية ─────
   السر: دوسة طويلة (5 ثواني) على كلمة «مكتبتي» فوق ← يطلع الرقم السري */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun DecoyScreen() {
    val ctx = LocalContext.current
    var pad by remember { mutableStateOf(false) }
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    // 🎭 كتب التمويه: مكتبة منفصلة خالص عن كتبك الحقيقية
    val list = Lib.cfg.optJSONArray("decoy") ?: JSONArray().also { Lib.cfg.put("decoy", it) }
    val dbooks = (0 until list.length()).mapNotNull { list.optJSONObject(it) }
    var open by remember { mutableStateOf<JSONObject?>(null) }
    var del by remember { mutableStateOf<JSONObject?>(null) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) try {
            var name = "كتاب"
            ctx.contentResolver.query(uri, null, null, null, null)?.use { c -> val i = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME); if (i >= 0 && c.moveToFirst()) name = c.getString(i) }
            val b = JSONObject().put("id", "d" + System.currentTimeMillis()).put("t", name.removeSuffix(".pdf").removeSuffix(".PDF").replace('_', ' ')).put("a", "").put("sh", "now")
            ctx.contentResolver.openInputStream(uri)!!.use { inp -> File(Lib.dir, "books/${b.optString("id")}.pdf").outputStream().use { inp.copyTo(it) } }
            cover(b); list.put(b); Lib.save()
        } catch (_: Exception) { Toast.makeText(ctx, "⚠️ مقدرتش أفتح الملف", Toast.LENGTH_SHORT).show() }
    }
    val o = open
    if (o != null) { ReaderScreen(o) { _, _, _ -> open = null; Lib.save() }; return }
    Column(Modifier.fillMaxSize().background(Paper).statusBarsPadding().padding(16.dp)) {
        Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("📚 ", fontSize = 26.sp)
            Text("مكتبتي", fontSize = 26.sp, fontWeight = FontWeight.Black, color = Ink,
                modifier = Modifier.pointerInput(Unit) {
                    // لازم تفضل دايس 5 ثواني من غير ما تشيل صباعك
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        val up = withTimeoutOrNull(5000L) { waitForUpOrCancellation() }
                        if (up == null) { if (Lib.hasPin() && canBio(ctx)) askBio(ctx, { Lib.revealed = true }) { pad = true } else pad = true }
                    }
                })
            Spacer(Modifier.weight(1f))
            if (dbooks.isNotEmpty()) TextButton({ pick.launch(arrayOf("application/pdf")) }) { Text("➕ ضيف كتاب", color = Green, fontWeight = FontWeight.Bold) }
        }
        if (dbooks.isEmpty()) {
            Spacer(Modifier.weight(1f))
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("📖", fontSize = 64.sp)
                Text("مكتبتك فاضية", fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink)
                Text("لسه مضفتش أي كتاب", color = Muted)
                OutlinedButton({ pick.launch(arrayOf("application/pdf")) }) { Text("➕ ضيف كتاب") }
            }
            Spacer(Modifier.weight(1.3f))
        } else LazyVerticalGrid(GridCells.Fixed(3), Modifier.fillMaxSize().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            items(dbooks, key = { it.optString("id") }) { b ->
                Column(Modifier.pointerInput(b.optString("id")) {
                    androidx.compose.foundation.gestures.detectTapGestures(onTap = { open = b }, onLongPress = { del = b })
                }) {
                    Cover(b, Modifier.fillMaxWidth().aspectRatio(0.7f))
                    Text(b.optString("t"), fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, color = Ink, modifier = Modifier.padding(top = 4.dp))
                    val pg = b.optInt("pg"); val c = b.optInt("cur")
                    if (pg > 0 && c > 1) Text("صفحة $c من $pg", fontSize = 10.sp, color = Muted)
                }
            }
        }
    }
    del?.let { b -> AlertDialog(onDismissRequest = { del = null },
        confirmButton = { TextButton({
            for (i in 0 until list.length()) if (list.optJSONObject(i)?.optString("id") == b.optString("id")) { list.remove(i); break }
            Lib.files(b).forEach { it.delete() }; File(Lib.dir, "covers/${b.optString("id")}.jpg").delete(); Lib.save(); del = null
        }) { Text("امسحه", color = Color(0xFFB3261E)) } },
        dismissButton = { TextButton({ del = null }) { Text("لأ") } },
        title = { Text("تمسح «${b.optString("t")}»؟") }) }
    if (pad) PinPad({ pad = false }) { pad = false; Lib.revealed = true }
}

@Composable
fun PinPad(onDismiss: () -> Unit, onOk: () -> Unit) {
    val ctx = LocalContext.current
    val setup = !Lib.hasPin()
    var p by remember { mutableStateOf("") }
    var first by remember { mutableStateOf<String?>(null) }
    var wrong by remember { mutableIntStateOf(0) }
    var waitTill by remember { mutableLongStateOf(0L) }
    fun done(x: String) {
        if (setup) {
            if (first == null) { first = x; p = "" }
            else if (first == x) { Lib.setPin(x); Notify.schedule(ctx); try { ReadWidget.refresh(ctx) } catch (_: Exception) {}; Toast.makeText(ctx, "🔒 اتحفظ الرقم السري", Toast.LENGTH_SHORT).show(); onOk() }
            else { Toast.makeText(ctx, "⚠️ الرقمين مش زي بعض — ابدأ تاني", Toast.LENGTH_SHORT).show(); first = null; p = "" }
        } else if (Lib.checkPin(x)) onOk()
        else { wrong++; p = ""; if (wrong >= 5) { waitTill = System.currentTimeMillis() + 30_000; wrong = 0; Toast.makeText(ctx, "استنى 30 ثانية", Toast.LENGTH_SHORT).show() } }
    }
    AlertDialog(onDismissRequest = onDismiss, confirmButton = {}, dismissButton = { TextButton(onDismiss) { Text("إلغاء") } },
        title = { Text(if (setup) (if (first == null) "🔒 اختار رقم سري (4 أرقام)" else "🔒 اكتبه تاني للتأكيد") else "🔒", fontWeight = FontWeight.Bold) },
        text = {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text((1..4).joinToString(" ") { if (it <= p.length) "●" else "○" }, fontSize = 28.sp, color = Ink)
                listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("", "0", "⌫")).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { row.forEach { k ->
                        if (k.isEmpty()) Spacer(Modifier.size(64.dp))
                        else Surface(onClick = {
                            if (System.currentTimeMillis() < waitTill) return@Surface
                            if (k == "⌫") p = p.dropLast(1) else if (p.length < 4) { p += k; if (p.length == 4) done(p) }
                        }, shape = CircleShape, color = Sand, modifier = Modifier.size(64.dp)) { Box(contentAlignment = Alignment.Center) { Text(k, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Ink) } }
                    } }
                }
            }
        })
}


/* ───── 👆 البصمة ───── */
fun canBio(ctx: android.content.Context): Boolean = try {
    androidx.biometric.BiometricManager.from(ctx).canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK) == androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS
} catch (_: Exception) { false }

fun askBio(ctx: android.content.Context, onOk: () -> Unit, onPin: () -> Unit) {
    val act = ctx as? androidx.fragment.app.FragmentActivity ?: return onPin()
    val p = androidx.biometric.BiometricPrompt(act, androidx.core.content.ContextCompat.getMainExecutor(act), object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: androidx.biometric.BiometricPrompt.AuthenticationResult) { onOk() }
        override fun onAuthenticationError(code: Int, msg: CharSequence) {
            if (code == androidx.biometric.BiometricPrompt.ERROR_NEGATIVE_BUTTON || code == androidx.biometric.BiometricPrompt.ERROR_LOCKOUT ||
                code == androidx.biometric.BiometricPrompt.ERROR_LOCKOUT_PERMANENT) onPin()
        }
    })
    p.authenticate(androidx.biometric.BiometricPrompt.PromptInfo.Builder().setTitle("📚 مكتبتي").setSubtitle("حط صباعك")
        .setNegativeButtonText("🔢 الرقم السري").setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK).build())
}
