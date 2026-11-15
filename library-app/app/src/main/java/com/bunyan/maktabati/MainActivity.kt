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
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
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

class MainActivity : ComponentActivity() {
    private val incoming = mutableStateOf<Intent?>(null)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Lib.init(this)
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
}

@Composable
fun App(incoming: MutableState<Intent?>) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var reading by remember { mutableStateOf<JSONObject?>(null) }
    var screen by remember { mutableStateOf("home") }
    val dl = remember { mutableStateMapOf<String, Float>() }
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver

    fun toast(s: String) = Toast.makeText(ctx, s, Toast.LENGTH_SHORT).show()

    fun fetch(b: JSONObject, open: Boolean) {
        val id = b.optString("id")
        if (dl.containsKey(id)) return
        if (b.optString("ia").isEmpty()) { toast("الكتاب ده اترفع من ملف — دوس «📄 من موبايلي» واختاره"); return }
        dl[id] = 0f
        scope.launch {
            try {
                val parts = Net.parts(b)
                if (parts.isEmpty()) throw Exception("مفيش PDF")
                parts.forEachIndexed { i, f ->
                    val to = File(Lib.dir, "books/" + (if (i == 0) "$id.pdf" else "$id#part${i + 1}.pdf"))
                    if (!to.exists()) Net.download(Net.iaUrl(b.optString("ia"), f), to) { got, tot ->
                        dl[id] = ((i + (if (tot > 0) got.toFloat() / tot else 0f)) / parts.size).coerceIn(0f, 1f)
                    }
                }
                cover(b)
                Lib.save(); dl.remove(id)
                if (open) reading = b
            } catch (e: Exception) { dl.remove(id); toast("⚠️ التحميل وقف — جرّب تاني (${e.message?.take(30)})") }
        }
    }

    fun openBook(b: JSONObject) { if (Lib.have(b)) reading = b else fetch(b, true) }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) addFromUri(ctx, uri)?.let { reading = it }
    }

    LaunchedEffect(incoming.value) {
        val itn = incoming.value ?: return@LaunchedEffect
        incoming.value = null
        val d = itn.data ?: return@LaunchedEffect
        if (d.scheme == "bnylib") {
            val code = d.getQueryParameter("c") ?: d.fragment ?: ""
            val o = Lib.parseLink(code)
            if (o == null) toast("⚠️ كود الربط مش مظبوط") else {
                Lib.link = JSONObject().put("r", o.optString("r")).put("t", o.optString("t")).put("p", o.optString("p", "book.json")).put("g", o.optString("g"))
                Lib.save(); toast("✅ اتربط بحساب بنيان — بنزّل مكتبتك…"); Lib.msg = Lib.sync(); screen = "home"
            }
        } else if (itn.action == Intent.ACTION_VIEW) addFromUri(ctx, d)?.let { b -> reading = b }
    }
    LaunchedEffect(Unit) { if (Lib.link != null) Lib.msg = Lib.sync() }

    val r = reading
    if (r != null) { ReaderScreen(r) { reading = null; scope.launch { Lib.sync() } }; return }

    when (screen) {
        "search" -> SearchScreen(onBack = { screen = "home" }) { h ->
            val b = Lib.addLocal(h.title, h.author) { it.put("ia", h.id) }
            screen = "home"; fetch(b, false); toast("⬇️ بنزّل «${h.title}»")
        }
        "link" -> LinkScreen { screen = "home" }
        else -> HomeScreen(dl, onOpen = { openBook(it) }, onFetch = { fetch(it, false) }, onSearch = { screen = "search" },
            onPick = { pick.launch(arrayOf("application/pdf")) }, onLink = { screen = "link" },
            onSync = { scope.launch { Lib.msg = Lib.sync(); toast(Lib.msg) } })
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
fun HomeScreen(dl: Map<String, Float>, onOpen: (JSONObject) -> Unit, onFetch: (JSONObject) -> Unit, onSearch: () -> Unit, onPick: () -> Unit, onLink: () -> Unit, onSync: () -> Unit) {
    @Suppress("UNUSED_VARIABLE") val v = Lib.ver
    var shelf by remember { mutableStateOf("now") }
    var q by remember { mutableStateOf("") }
    var menu by remember { mutableStateOf<JSONObject?>(null) }
    var goalDlg by remember { mutableStateOf(false) }
    val cur = Lib.current()
    val today = Lib.todayPages(); val goal = Lib.goal; val st = Lib.streak()
    val list = Lib.books.filter { it.optString("sh", "want") == shelf && (q.isBlank() || it.optString("t").contains(q) || it.optString("a").contains(q)) }
        .let { l -> if (shelf == "want") l.sortedBy { b -> Lib.queue.indexOf(b.optString("id")).let { if (it < 0) 9999 else it } } else l.sortedByDescending { it.optLong("rd", 0) } }

    LazyVerticalGrid(GridCells.Fixed(3), Modifier.fillMaxSize().background(Paper), contentPadding = PaddingValues(start = 14.dp, end = 14.dp, top = 0.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item(span = { GridItemSpan(3) }) {
            Row(Modifier.statusBarsPadding().padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("📚 مكتبتي", fontSize = 26.sp, fontWeight = FontWeight.Black, color = Ink, modifier = Modifier.weight(1f))
                if (Lib.syncing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                else if (Lib.link != null) Text("🔄", fontSize = 20.sp, modifier = Modifier.clickable { onSync() }.padding(8.dp))
            }
        }
        if (Lib.link == null) item(span = { GridItemSpan(3) }) {
            Surface(onClick = onLink, shape = RoundedCornerShape(18.dp), color = Color(0xFFE8F3EE)) {
                Column(Modifier.padding(14.dp)) {
                    Text("🔗 اربط التطبيق بحساب بنيان", fontWeight = FontWeight.Bold, color = Green, fontSize = 15.sp)
                    Text("علشان كتبك وتقدمك يبقوا واحد هنا وفي بنيان، والقراية بالصوت تشتغل.", fontSize = 13.sp, color = Muted)
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
                        }
                        Spacer(Modifier.width(12.dp))
                        Cover(cur, Modifier.width(78.dp).height(110.dp))
                    }
                    Spacer(Modifier.height(12.dp))
                    val p = dl[cur.optString("id")]
                    Button(onClick = { onOpen(cur) }, Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = Green), enabled = p == null) {
                        Text(when { p != null -> "⬇️ بنزّل… ${(p * 100).toInt()}%"; !Lib.have(cur) -> "⬇️ نزّله وابدأ"; c > 1 -> "📖 كمّل من صفحة $c"; else -> "📖 ابدأ القراية" }, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
        // هدف اليوم + الشمعة
        item(span = { GridItemSpan(3) }) {
            Surface(onClick = { goalDlg = true }, shape = RoundedCornerShape(20.dp), color = Card) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(64.dp), Alignment.Center) {
                        CircularProgressIndicator(progress = { (today.toFloat() / goal).coerceIn(0f, 1f) }, Modifier.fillMaxSize(), color = Flame, trackColor = Sand, strokeWidth = 6.dp)
                        Text("$today", fontWeight = FontWeight.Black, fontSize = 20.sp, color = Ink)
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text("هدف النهارده: $goal صفحات", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Ink)
                        Text(if (today >= goal) "🎉 خلّصت هدف النهارده!" else "فاضلك ${goal - today} صفحة بس", color = Muted, fontSize = 13.sp)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (st > 0) "🔥" else "🕯", fontSize = 26.sp)
                        Text("$st يوم", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = if (st > 0) Flame else Muted)
                    }
                }
            }
        }
        // أزرار
        item(span = { GridItemSpan(3) }) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Action("🔎", "نزّل كتاب", Modifier.weight(1f), onSearch)
                Action("📄", "من موبايلي", Modifier.weight(1f), onPick)
                Action(if (Lib.link == null) "🔗" else "✅", if (Lib.link == null) "اربط ببنيان" else "مربوط", Modifier.weight(1f), onLink)
            }
        }
        // الرفوف
        item(span = { GridItemSpan(3) }) {
            Column {
                Row(Modifier.clip(RoundedCornerShape(14.dp)).background(Sand).padding(4.dp)) {
                    listOf("now" to "📖 بقراه", "want" to "📌 عايز أقراه", "done" to "✅ خلصته").forEach { (k, t) ->
                        val n = Lib.books.count { it.optString("sh", "want") == k }
                        Surface(onClick = { shelf = k }, shape = RoundedCornerShape(11.dp), color = if (shelf == k) Card else Color.Transparent, modifier = Modifier.weight(1f)) {
                            Text("$t $n", Modifier.padding(vertical = 9.dp), textAlign = TextAlign.Center, fontWeight = FontWeight.Bold, fontSize = 13.sp, color = if (shelf == k) Ink else Muted)
                        }
                    }
                }
                OutlinedTextField(q, { q = it }, Modifier.fillMaxWidth().padding(top = 8.dp), placeholder = { Text("🔎 دوّر في كتبك") }, singleLine = true, shape = RoundedCornerShape(14.dp))
            }
        }
        if (list.isEmpty()) item(span = { GridItemSpan(3) }) { Text("مفيش كتب هنا", Modifier.fillMaxWidth().padding(30.dp), textAlign = TextAlign.Center, color = Muted) }
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
            }
        }
        item(span = { GridItemSpan(3) }) { Text("«عشر صفحات كل يوم = حوالي 12 كتاب في السنة»", Modifier.fillMaxWidth().padding(top = 16.dp), textAlign = TextAlign.Center, color = Muted, fontSize = 13.sp) }
    }

    menu?.let { b ->
        AlertDialog(onDismissRequest = { menu = null }, confirmButton = { TextButton({ menu = null }) { Text("قفل") } },
            title = { Text(b.optString("t"), fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (b.optString("a").isNotEmpty()) Text(b.optString("a"), color = Muted)
                    Button({ menu = null; onOpen(b) }, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text(if (Lib.have(b)) "📖 اقرأ" else "⬇️ نزّل واقرأ") }
                    if (!Lib.have(b) && b.optString("ia").isNotEmpty()) OutlinedButton({ menu = null; onFetch(b) }, Modifier.fillMaxWidth()) { Text("⬇️ نزّله بس") }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("want" to "📌 عايز", "now" to "📖 بقراه", "done" to "✅ خلصته").forEach { (k, t) -> Chip(t, b.optString("sh", "want") == k) { Lib.setShelf(b, k); menu = null } }
                    }
                    if (Lib.have(b)) TextButton({ Lib.files(b).forEach { it.delete() }; Lib.save(); menu = null }) { Text("🗑 امسح الملف من الموبايل (التقدم بيفضل)", color = Color(0xFFB3261E)) }
                }
            })
    }
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
fun SearchScreen(onBack: () -> Unit, onPick: (Net.Hit) -> Unit) {
    BackHandler { onBack() }
    val scope = rememberCoroutineScope()
    var q by remember { mutableStateOf("") }
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
        Row(verticalAlignment = Alignment.CenterVertically) { IconBtn("→") { onBack() }; Spacer(Modifier.width(10.dp)); Text("🔗 الربط بحساب بنيان", fontWeight = FontWeight.Black, fontSize = 19.sp, color = Ink) }
        if (Lib.link != null) {
            Text("✅ التطبيق مربوط بحسابك. كتبك وتقدمك بيتزامنوا مع مكتبتي في بنيان.", color = Green, fontWeight = FontWeight.Bold)
            OutlinedButton({ scope.launch { Toast.makeText(ctx, Lib.sync(), Toast.LENGTH_SHORT).show() } }, Modifier.fillMaxWidth()) { Text("🔄 زامن دلوقتي") }
            TextButton({ Lib.link = null; Lib.save() }) { Text("فك الربط", color = Color(0xFFB3261E)) }
        } else {
            Text("أسهل طريقة: افتح بنيان ← مكتبتي ← دوس «📱 افتح في تطبيق مكتبتي» وهيتربط لوحده.", fontSize = 15.sp, color = Ink, lineHeight = 24.sp)
            Text("أو الصق كود الربط (BNYLINK-…) هنا:", color = Muted)
            OutlinedTextField(code, { code = it }, Modifier.fillMaxWidth().height(120.dp), shape = RoundedCornerShape(14.dp))
            Button({
                val o = Lib.parseLink(code)
                if (o == null) Toast.makeText(ctx, "⚠️ الكود مش مظبوط", Toast.LENGTH_SHORT).show() else {
                    Lib.link = JSONObject().put("r", o.optString("r")).put("t", o.optString("t")).put("p", o.optString("p", "book.json")).put("g", o.optString("g"))
                    Lib.save(); scope.launch { Toast.makeText(ctx, Lib.sync(), Toast.LENGTH_SHORT).show(); onBack() }
                }
            }, Modifier.fillMaxWidth().height(50.dp), colors = ButtonDefaults.buttonColors(containerColor = Green)) { Text("اربط", fontWeight = FontWeight.Bold) }
        }
    }
}
