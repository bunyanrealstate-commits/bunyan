package com.bunyan.maktabati

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaMetadata
import android.media.PlaybackParams
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import android.widget.Toast
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

const val VOCAL_PROMPT = "دي صفحة من كتاب عربي هتتقري بصوت عالي بقارئ آلي. اكتب كلام الصفحة بالظبط بالترتيب الصح، واكتبه مشكول تشكيل كامل وصحيح نحويًا (كل حرف عليه حركته الصح، وخصوصًا أواخر الكلمات)، علشان القارئ ينطقه صح. متكتبش رقم الصفحة ولا العناوين المتكررة فوق ولا الحواشي، ومن غير أي شرح أو تعليق. الآيات اكتبها بتشكيلها الصح."

/** القراية بالصوت — شغالة كخدمة: بتكمّل والشاشة مقفولة، وليها أزرار في شاشة القفل والإشعارات */
object Speech {
    var playing by mutableStateOf(false)
    var bookId by mutableStateOf("")
    var page by mutableIntStateOf(0)
    var rate by mutableFloatStateOf(1f)
    var sleepAt by mutableLongStateOf(0L)
    var status by mutableStateOf("")

    fun natural() = Lib.cfg.optString("voice") == "gem"

    fun start(ctx: Context, b: JSONObject, p: Int) {
        bookId = b.optString("id"); page = p; playing = true
        val i = Intent(ctx, ReadService::class.java).setAction("start")
        if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
    }
    fun stop(ctx: Context) { playing = false; try { ctx.startService(Intent(ctx, ReadService::class.java).setAction("stop")) } catch (_: Exception) {} }

    /** نص الصفحة مشكول صح (بيتحفظ علشان المرة الجاية) */
    suspend fun vocal(doc: Doc, b: JSONObject, p: Int): String {
        val f = File(Lib.dir, "tts/${b.optString("id")}_$p.txt")
        if (f.exists()) return f.readText()
        val t = Net.gemini(VOCAL_PROMPT, doc.render(p, 1500))?.replace(Regex("[*#_`>]"), " ")?.replace(Regex("\\s+"), " ")?.trim()
        if (!t.isNullOrEmpty() && t.length > 5) { f.writeText(t); return t }
        return ""
    }

    /** صوت طبيعي من Gemini (PCM 24kHz) — بيتحفظ لكل صفحة */
    suspend fun naturalAudio(b: JSONObject, p: Int, text: String): ByteArray? = withContext(Dispatchers.IO) {
        val f = File(Lib.dir, "tts/${b.optString("id")}_$p.pcm")
        if (f.exists() && f.length() > 1000) return@withContext f.readBytes()
        val g = Lib.gem() ?: return@withContext null
        val voice = Lib.cfg.optString("voiceName", "Charon")
        val body = JSONObject()
            .put("contents", JSONArray().put(JSONObject().put("parts", JSONArray().put(JSONObject().put("text", "اقرأ النص ده بصوت هادي ودافي وواضح، بالعربي الفصيح وبالتشكيل المكتوب، من غير ما تزوّد أي كلمة:\n" + text)))))
            .put("generationConfig", JSONObject().put("responseModalities", JSONArray().put("AUDIO"))
                .put("speechConfig", JSONObject().put("voiceConfig", JSONObject().put("prebuiltVoiceConfig", JSONObject().put("voiceName", voice))))).toString()
        for (m in listOf("gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts")) {
            try {
                val c = URL("https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent").openConnection() as HttpURLConnection
                c.requestMethod = "POST"; c.doOutput = true; c.connectTimeout = 20000; c.readTimeout = 180000
                c.setRequestProperty("Content-Type", "application/json"); c.setRequestProperty("x-goog-api-key", g.optString("key"))
                c.outputStream.use { it.write(body.toByteArray()) }
                if (c.responseCode != 200) continue
                val j = JSONObject(c.inputStream.bufferedReader().readText())
                val ps = j.optJSONArray("candidates")?.optJSONObject(0)?.optJSONObject("content")?.optJSONArray("parts") ?: continue
                for (i in 0 until ps.length()) {
                    val d = ps.getJSONObject(i).optJSONObject("inlineData") ?: ps.getJSONObject(i).optJSONObject("inline_data") ?: continue
                    val bytes = Base64.decode(d.optString("data"), Base64.DEFAULT)
                    if (bytes.size > 1000) { f.writeBytes(bytes); return@withContext bytes }
                }
            } catch (_: Exception) {}
        }
        null
    }
}

class ReadService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = CompletableDeferred<Boolean>()
    private val pending = HashMap<String, CompletableDeferred<Unit>>()
    private var track: AudioTrack? = null
    private var session: MediaSession? = null
    private var doc: Doc? = null
    private var warnedVoice = false

    override fun onBind(i: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (!Lib.isInit()) Lib.init(applicationContext)
        tts = TextToSpeech(this) { st -> if (st == TextToSpeech.SUCCESS) { tts?.setLanguage(Locale("ar")); ttsReady.complete(true) } else ttsReady.complete(false) }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { pending.remove(id)?.complete(Unit) }
            @Deprecated("") override fun onError(id: String?) { pending.remove(id)?.complete(Unit) }
        })
        session = MediaSession(this, "maktabati").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { resume() }
                override fun onPause() { pause() }
                override fun onSkipToNext() { skip(1) }
                override fun onSkipToPrevious() { skip(-1) }
                override fun onStop() { finish() }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "start" -> {
                intent.getStringExtra("b")?.let { id -> Lib.book(id)?.let { bk -> Speech.bookId = id; Speech.page = bk.optInt("cur", 1).coerceAtLeast(1) } }
                show(); begin()
            }
            "pause" -> pause()
            "play" -> resume()
            "next" -> skip(1)
            "prev" -> skip(-1)
            "stop" -> finish()
            else -> show()
        }
        return START_NOT_STICKY
    }

    private fun book(): JSONObject? = Lib.book(Speech.bookId)

    private fun begin() {
        job?.cancel(); hush()
        val b = book() ?: return finish()
        doc?.close(); doc = try { Doc(Lib.files(b)) } catch (_: Exception) { null }
        val d = doc ?: return finish()
        Speech.playing = true
        job = scope.launch {
            if (!Net.hasGem()) { toast("محتاج Gemini — اربط التطبيق ببنيان الأول"); finish(); return@launch }
            var p = Speech.page.coerceIn(1, d.count)
            while (isActive && Speech.playing) {
                Speech.page = p; show(); Speech.status = "📖 بجهّز صفحة $p…"
                val txt = Speech.vocal(d, b, p)
                if (p < d.count) launch { try { Speech.vocal(d, b, p + 1).let { t -> if (Speech.natural() && t.isNotEmpty()) Speech.naturalAudio(b, p + 1, t) } } catch (_: Exception) {} }
                if (txt.isEmpty()) { toast("⚠️ مقدرتش أقرا الصفحة دي — اتأكد من النت"); break }
                Speech.status = ""
                var done = false
                if (Speech.natural()) {
                    val pcm = Speech.naturalAudio(b, p, txt)
                    if (pcm != null) { playPcm(pcm); done = true }
                    else if (!warnedVoice) { warnedVoice = true; toast("الصوت الطبيعي مش متاح دلوقتي — هقرا بصوت الموبايل") }
                }
                if (!done) {
                    if (!ttsReady.await()) { toast("صوت القراية العربي مش جاهز على الموبايل"); break }
                    for (s in Regex("[^.!؟?،\n]{1,220}[.!؟?،]?").findAll(txt).map { it.value.trim() }.filter { it.isNotEmpty() }) {
                        if (!Speech.playing || !isActive) break
                        say(s)
                    }
                }
                if (!Speech.playing || !isActive) break
                Lib.credit(b, p)
                if (Speech.sleepAt > 0 && System.currentTimeMillis() >= Speech.sleepAt) { Speech.sleepAt = 0; toast("😴 وقفت القراية — تصبح على خير"); break }
                if (p >= d.count) { toast("🎉 خلصت الكتاب!"); break }
                p++
            }
            if (Speech.playing) finish()
        }
    }

    private suspend fun say(s: String) {
        val t = tts ?: return
        val id = java.util.UUID.randomUUID().toString(); val d = CompletableDeferred<Unit>(); pending[id] = d
        t.setSpeechRate(0.95f * Speech.rate)
        t.speak(s, TextToSpeech.QUEUE_ADD, null, id); d.await()
    }

    private suspend fun playPcm(pcm: ByteArray) {
        val tr = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(24000).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(pcm.size).build()
        track = tr
        try {
            tr.write(pcm, 0, pcm.size)
            try { tr.playbackParams = PlaybackParams().setSpeed(Speech.rate) } catch (_: Exception) {}
            tr.play()
            val frames = pcm.size / 2
            while (Speech.playing && tr.playbackHeadPosition < frames && tr.playState == AudioTrack.PLAYSTATE_PLAYING) delay(150)
        } finally { try { tr.stop() } catch (_: Exception) {}; tr.release(); if (track === tr) track = null }
    }

    private fun hush() {
        try { tts?.stop() } catch (_: Exception) {}
        pending.values.forEach { it.complete(Unit) }; pending.clear()
        try { track?.stop() } catch (_: Exception) {}
    }

    private fun pause() { Speech.playing = false; job?.cancel(); hush(); show() }
    private fun resume() { Speech.playing = true; show(); begin() }
    private fun skip(d: Int) { val n = doc?.count ?: return; Speech.page = (Speech.page + d).coerceIn(1, n); if (Speech.playing) begin() else show() }
    private fun finish() {
        Speech.playing = false; job?.cancel(); hush(); Speech.status = ""
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }

    private fun toast(s: String) { Toast.makeText(applicationContext, s, Toast.LENGTH_LONG).show() }

    private fun act(a: String, code: Int) = PendingIntent.getService(this, code, Intent(this, ReadService::class.java).setAction(a), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    private fun ic(r: Int) = android.graphics.drawable.Icon.createWithResource(this, r)

    private fun show() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel("mk_play") == null)
            nm.createNotificationChannel(NotificationChannel("mk_play", "القراية بالصوت", NotificationManager.IMPORTANCE_LOW))
        val b = book()
        val title = b?.optString("t") ?: "مكتبتي"
        val sub = "صفحة ${Speech.page}" + (b?.optInt("pg")?.takeIf { it > 0 }?.let { " من $it" } ?: "")
        session?.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title).putString(MediaMetadata.METADATA_KEY_ARTIST, sub)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, b?.optString("a") ?: "").build())
        session?.setPlaybackState(PlaybackState.Builder()
            .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_STOP)
            .setState(if (Speech.playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, 0, 1f).build())
        val open = PendingIntent.getActivity(this, 501, Intent(this, MainActivity::class.java).putExtra("open", Speech.bookId).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val nb = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "mk_play") else @Suppress("DEPRECATION") Notification.Builder(this))
            .setSmallIcon(android.R.drawable.ic_media_play).setContentTitle("🎧 " + title).setContentText(sub)
            .setContentIntent(open).setOngoing(Speech.playing).setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(ic(android.R.drawable.ic_media_previous), "⏮", act("prev", 1)).build())
            .addAction(if (Speech.playing) Notification.Action.Builder(ic(android.R.drawable.ic_media_pause), "⏸ وقّف", act("pause", 2)).build() else Notification.Action.Builder(ic(android.R.drawable.ic_media_play), "▶️ كمّل", act("play", 3)).build())
            .addAction(Notification.Action.Builder(ic(android.R.drawable.ic_media_next), "⏭", act("next", 4)).build())
            .addAction(Notification.Action.Builder(ic(android.R.drawable.ic_menu_close_clear_cancel), "✕", act("stop", 5)).build())
            .setDeleteIntent(act("stop", 6))
            .setStyle(Notification.MediaStyle().setMediaSession(session?.sessionToken).setShowActionsInCompactView(0, 1, 2))
        val n = nb.build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(77, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) else startForeground(77, n)
    }

    override fun onDestroy() {
        Speech.playing = false; job?.cancel(); hush(); scope.cancel()
        try { tts?.shutdown() } catch (_: Exception) {}
        session?.release(); doc?.close()
        super.onDestroy()
    }
}
