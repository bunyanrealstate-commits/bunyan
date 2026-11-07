package com.bunyan.english;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Runs Gemma fully on the phone. The model is fetched once into app storage, then no internet is needed. */
@CapacitorPlugin(name = "LocalLlm")
public class LocalLlmPlugin extends Plugin {
    private static final String NAME = "gemma3-1b-it-int4.task";
    private static final long MIN_SIZE = 400_000_000L;
    private LlmInference llm;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final ExecutorService net = Executors.newSingleThreadExecutor();
    private volatile boolean downloading = false;

    private File modelFile() { return new File(getContext().getFilesDir(), NAME); }

    @PluginMethod
    public void status(PluginCall call) {
        File f = modelFile();
        File tmp = new File(f.getPath() + ".part");
        JSObject o = new JSObject();
        o.put("ready", f.exists() && f.length() > MIN_SIZE);
        o.put("partial", tmp.exists() ? tmp.length() : 0);
        o.put("downloading", downloading);
        o.put("loaded", llm != null);
        call.resolve(o);
    }

    @PluginMethod
    public void download(PluginCall call) {
        final String url = call.getString("url");
        if (url == null) { call.reject("no_url"); return; }
        if (downloading) { call.reject("busy"); return; }
        downloading = true;
        net.execute(() -> {
            File f = modelFile();
            File tmp = new File(f.getPath() + ".part");
            try {
                long have = tmp.exists() ? tmp.length() : 0;
                String u = url;
                HttpURLConnection c = null;
                for (int i = 0; i < 6; i++) {
                    c = (HttpURLConnection) new URL(u).openConnection();
                    c.setInstanceFollowRedirects(false);
                    c.setConnectTimeout(20000);
                    c.setReadTimeout(60000);
                    if (have > 0) c.setRequestProperty("Range", "bytes=" + have + "-");
                    int code = c.getResponseCode();
                    if (code >= 300 && code < 400) { u = new URL(new URL(u), c.getHeaderField("Location")).toString(); c.disconnect(); continue; }
                    break;
                }
                int code = c.getResponseCode();
                if (code != 200 && code != 206) throw new Exception("HTTP " + code);
                boolean append = code == 206;
                if (!append) have = 0;
                long len = c.getContentLengthLong();
                long total = len > 0 ? have + len : -1;
                long done = have, lastSent = 0;
                try (InputStream in = c.getInputStream(); FileOutputStream out = new FileOutputStream(tmp, append)) {
                    byte[] buf = new byte[1 << 16];
                    int n;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                        done += n;
                        if (done - lastSent > 2_000_000L) {
                            lastSent = done;
                            JSObject p = new JSObject();
                            p.put("loaded", done); p.put("total", total);
                            notifyListeners("progress", p);
                        }
                    }
                }
                if (tmp.length() < MIN_SIZE) throw new Exception("incomplete");
                if (f.exists()) f.delete();
                if (!tmp.renameTo(f)) throw new Exception("rename");
                downloading = false;
                call.resolve();
            } catch (Throwable e) {
                downloading = false;
                call.reject(String.valueOf(e.getMessage()));
            }
        });
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
