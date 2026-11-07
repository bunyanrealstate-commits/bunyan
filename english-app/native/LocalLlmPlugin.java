package com.bunyan.english;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;

import android.app.DownloadManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Runs Gemma fully on the phone. The model is fetched once into app storage, then no internet is needed. */
@CapacitorPlugin(name = "LocalLlm")
public class LocalLlmPlugin extends Plugin {
    private static final String NAME = "gemma3-1b-it-int4.task";
    private static final long MIN_SIZE = 400_000_000L;
    private LlmInference llm;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    private SharedPreferences prefs() { return getContext().getSharedPreferences("llm", Context.MODE_PRIVATE); }
    private File extFile() { return new File(getContext().getExternalFilesDir(null), NAME); }
    private File intFile() { return new File(getContext().getFilesDir(), NAME); }
    private File modelFile() { File i = intFile(); return (i.exists() && i.length() > MIN_SIZE) ? i : extFile(); }
    private DownloadManager dm() { return (DownloadManager) getContext().getSystemService(Context.DOWNLOAD_SERVICE); }

    private JSObject query() {
        JSObject o = new JSObject();
        boolean ready = (intFile().exists() && intFile().length() > MIN_SIZE)
                || (prefs().getBoolean("ready", false) && extFile().exists() && extFile().length() > MIN_SIZE);
        String state = ready ? "ready" : "none";
        long loaded = 0, total = -1;
        long id = prefs().getLong("id", -1);
        if (!ready && id >= 0) {
            try (Cursor c = dm().query(new DownloadManager.Query().setFilterById(id))) {
                if (c != null && c.moveToFirst()) {
                    int st = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                    loaded = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                    total = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));
                    if (st == DownloadManager.STATUS_SUCCESSFUL) {
                        if (extFile().length() > MIN_SIZE) {
                            prefs().edit().putBoolean("ready", true).remove("id").apply();
                            ready = true; state = "ready";
                        } else { state = "failed"; prefs().edit().remove("id").apply(); }
                    } else if (st == DownloadManager.STATUS_FAILED) {
                        state = "failed";
                        o.put("reason", c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)));
                        prefs().edit().remove("id").apply();
                        dm().remove(id);
                    } else if (st == DownloadManager.STATUS_PAUSED) {
                        state = "paused";
                    } else {
                        state = "downloading";
                    }
                } else {
                    prefs().edit().remove("id").apply();
                }
            } catch (Exception e) { state = "none"; }
        }
        o.put("ready", ready);
        o.put("state", state);
        o.put("loaded", loaded);
        o.put("total", total);
        o.put("loadedModel", llm != null);
        return o;
    }

    @PluginMethod
    public void status(PluginCall call) { call.resolve(query()); }

    /** Hands the download to Android's download manager: it keeps going with the app closed and shows a notification. */
    @PluginMethod
    public void download(PluginCall call) {
        final String url = call.getString("url");
        if (url == null) { call.reject("no_url"); return; }
        JSObject now = query();
        String st = now.getString("state");
        if ("ready".equals(st) || "downloading".equals(st) || "paused".equals(st)) { call.resolve(now); return; }
        try {
            File f = extFile();
            if (f.exists()) f.delete();
            DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url))
                    .setTitle("عقل صاحبك — مدرّب الإنجليزي")
                    .setDescription("بيتحمّل مرة واحدة بس")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    .setDestinationInExternalFilesDir(getContext(), null, NAME)
                    .setAllowedOverMetered(true)
                    .setAllowedOverRoaming(true);
            long id = dm().enqueue(r);
            prefs().edit().putLong("id", id).putBoolean("ready", false).apply();
            call.resolve(query());
        } catch (Throwable e) {
            call.reject(String.valueOf(e.getMessage()));
        }
    }

    @PluginMethod
    public void load(PluginCall call) {
        worker.execute(() -> {
            try {
                if (llm == null) {
                    File f = modelFile();
                    if (!f.exists() || f.length() < MIN_SIZE) { call.reject("no_model"); return; }
                    LlmInference.LlmInferenceOptions opts = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(f.getAbsolutePath())
                            .setMaxTokens(1024)
                            .build();
                    llm = LlmInference.createFromOptions(getContext(), opts);
                }
                call.resolve();
            } catch (Throwable e) {
                call.reject(String.valueOf(e.getMessage()));
            }
        });
    }

    @PluginMethod
    public void generate(PluginCall call) {
        final String prompt = call.getString("prompt", "");
        worker.execute(() -> {
            try {
                if (llm == null) { call.reject("not_loaded"); return; }
                String text = llm.generateResponse(prompt);
                JSObject o = new JSObject();
                o.put("text", text);
                call.resolve(o);
            } catch (Throwable e) {
                call.reject(String.valueOf(e.getMessage()));
            }
        });
    }
}
