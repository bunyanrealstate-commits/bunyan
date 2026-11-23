package com.bunyan.yawmi;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** بيقرا قرايتك من تطبيق «مكتبتي» (نفس مفتاح التوقيع) عشان تظهر في يومي وأهدافي */
@CapacitorPlugin(name = "Maktabati")
public class MaktabatiPlugin extends Plugin {
    @PluginMethod
    public void read(PluginCall call) {
        JSObject r = new JSObject();
        try (Cursor c = getContext().getContentResolver().query(Uri.parse("content://com.bunyan.maktabati.yawmi/feed"), null, null, null, null)) {
            if (c != null && c.moveToFirst()) { r.put("ok", true); r.put("json", c.getString(0)); } else r.put("ok", false);
        } catch (Exception e) { r.put("ok", false); r.put("err", String.valueOf(e)); }
        call.resolve(r);
    }
    @PluginMethod
    public void open(PluginCall call) {
        Intent i = getContext().getPackageManager().getLaunchIntentForPackage("com.bunyan.maktabati");
        if (i != null) { i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); getContext().startActivity(i); }
        call.resolve();
    }
}
