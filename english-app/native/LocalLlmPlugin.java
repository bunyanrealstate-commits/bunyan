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
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

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
        Context ctx = getContext();
        boolean ready = (intFile().exists() && intFile().length() > MIN_SIZE)
                || (prefs().getBoolean("ready", false) && extFile().exists() && extFile().length() > MIN_SIZE);
        String state;
        long loaded = 0, total = -1;
        if (ready) state = "ready";
        else if (ModelDownloadService.running) {
            state = "downloading"; loaded = ModelDownloadService.loaded.get(); total = ModelDownloadService.total;
        } else {
            total = prefs().getLong("total", -1);
            String map = prefs().getString("chunks", "");
            if (total > 0 && !map.isEmpty() && ModelDownloadService.part(ctx).exists()) {
                long chunk = 8L * 1024 * 1024;
                for (int i = 0; i < map.length(); i++) if (map.charAt(i) == '1') loaded += Math.min(chunk, total - i * chunk);
                state = ModelDownloadService.error != null ? "failed" : "partial";
            } else state = ModelDownloadService.error != null ? "failed" : "none";
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

    /** Starts the fast parallel download; it keeps running with the app closed. */
    @PluginMethod
    public void download(PluginCall call) {
        final String url = call.getString("url");
        if (url == null) { call.reject("no_url"); return; }
        JSObject now = query();
        String st = now.getString("state");
        if ("ready".equals(st) || "downloading".equals(st)) { call.resolve(now); return; }
        try {
            long old = prefs().getLong("id", -1);
            if (old >= 0) { try { dm().remove(old); } catch (Exception ignored) {} prefs().edit().remove("id").apply(); }
            if (Build.VERSION.SDK_INT >= 33 && getActivity() != null
                    && ContextCompat.checkSelfPermission(getContext(), "android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(getActivity(), new String[]{"android.permission.POST_NOTIFICATIONS"}, 77);
            }
            Intent i = new Intent(getContext(), ModelDownloadService.class).putExtra("url", url);
            ContextCompat.startForegroundService(getContext(), i);
            JSObject o = new JSObject();
            o.put("ready", false); o.put("state", "downloading"); o.put("loaded", now.optLong("loaded", 0)); o.put("total", now.optLong("total", -1));
            call.resolve(o);
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
