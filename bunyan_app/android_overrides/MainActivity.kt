package com.bunyan.bunyan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** بيستقبل كود الربط اللي بنيان القديم بيبعته لوحده (bnyapp://link?c=...) */
class MainActivity : FlutterActivity() {
    private var link: String? = null
    private var ch: MethodChannel? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        link = intent?.dataString
        ch = MethodChannel(engine.dartExecutor.binaryMessenger, "bny/link")
        ch!!.setMethodCallHandler { call, res ->
            when (call.method) {
                "take" -> { val l = link; link = null; res.success(l) }
                "openOld" -> { val i = packageManager.getLaunchIntentForPackage("com.bunyan.furnished"); if (i != null) { startActivity(i); res.success(true) } else res.success(false) }
                else -> res.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val d = intent.dataString
        if (d != null) { link = d; ch?.invokeMethod("ping", null) }
    }
}
