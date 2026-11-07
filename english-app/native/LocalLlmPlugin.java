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
import java.io.OutputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Runs the bundled Gemma model fully on the phone (no internet). */
@CapacitorPlugin(name = "LocalLlm")
public class LocalLlmPlugin extends Plugin {
    private static final String NAME = "gemma3-1b-it-int4.task";
    private LlmInference llm;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    private File modelFile() { return new File(getContext().getFilesDir(), NAME); }

    private void copyModelIfNeeded() throws Exception {
        File f = modelFile();
        long expected;
        try (InputStream probe = getContext().getAssets().openFd("model/" + NAME).createInputStream()) {
            expected = getContext().getAssets().openFd("model/" + NAME).getLength();
        } catch (Exception e) { expected = -1; }
        if (f.exists() && (expected < 0 ? f.length() > 100_000_000L : f.length() == expected)) return;
        File tmp = new File(f.getPath() + ".tmp");
        try (InputStream in = getContext().getAssets().open("model/" + NAME);
             OutputStream out = new FileOutputStream(tmp)) {
            byte[] buf = new byte[1 << 20];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
        if (f.exists()) f.delete();
        if (!tmp.renameTo(f)) throw new Exception("could not save model");
    }

    @PluginMethod
    public void load(PluginCall call) {
        worker.execute(() -> {
            try {
                if (llm == null) {
                    copyModelIfNeeded();
                    LlmInference.LlmInferenceOptions opts = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(modelFile().getAbsolutePath())
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
