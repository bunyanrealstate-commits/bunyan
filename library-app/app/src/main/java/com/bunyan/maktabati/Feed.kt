package com.bunyan.maktabati

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** ربط الكتب بتطبيق «يومي وأهدافي»: يومي بيسأل هنا عن قرايتك (كتب بتقراها/خلصتها + صفحات ودقايق كل يوم).
 *  مسموح بس للتطبيقات اللي متوقّعة بنفس مفتاح مكتبتي. */
class YawmiFeed : ContentProvider() {
    override fun onCreate() = true
    override fun query(uri: Uri, p: Array<String>?, s: String?, a: Array<String>?, o: String?): Cursor? {
        val ctx = context ?: return null
        val caller = callingPackage ?: return null
        if (caller != ctx.packageName && ctx.packageManager.checkSignatures(caller, ctx.packageName) != PackageManager.SIGNATURE_MATCH) return null
        return MatrixCursor(arrayOf("json")).apply { addRow(arrayOf<Any>(feed(ctx))) }
    }
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, v: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, a: Array<String>?) = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<String>?) = 0

    companion object {
        fun feed(ctx: Context): String {
            val out = JSONObject(); val books = JSONArray()
            try {
                val j = JSONObject(File(ctx.filesDir, "lib.json").readText())
                val arr = j.optJSONArray("books") ?: JSONArray()
                for (i in 0 until arr.length()) {
                    val b = arr.optJSONObject(i) ?: continue
                    val sh = b.optString("sh"); val log = b.optJSONArray("log"); val tm = b.optJSONArray("tm")
                    if (sh != "now" && sh != "done" && (log == null || log.length() == 0)) continue
                    val o = JSONObject().put("id", b.optString("id")).put("t", b.optString("t")).put("a", b.optString("a")).put("sh", sh)
                        .put("cur", b.optInt("cur")).put("maxp", b.optInt("maxp")).put("pg", b.optInt("pg")).put("sd", b.optString("sd")).put("fd", b.optString("fd"))
                    if (log != null) o.put("log", log)
                    if (tm != null) o.put("tm", tm)
                    books.put(o)
                }
                out.put("goal", j.optInt("goal", 10))
            } catch (_: Exception) {}
            return out.put("books", books).put("at", System.currentTimeMillis()).toString()
        }
    }
}
