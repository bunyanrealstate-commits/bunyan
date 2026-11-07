package com.bunyan.english;

import android.Manifest;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import java.util.ArrayList;

/** In-app speech recognition (no Google popup) with live partial text and clear error codes. */
@CapacitorPlugin(name = "Hear", permissions = { @Permission(strings = { Manifest.permission.RECORD_AUDIO }, alias = "mic") })
public class HearPlugin extends Plugin {
    private SpeechRecognizer rec;
    private PluginCall pending;
    private String lastPartial = "";
    private boolean triedDefault = false;
    private final Handler main = new Handler(Looper.getMainLooper());
    private long lastLevel = 0;

    @PluginMethod
    public void start(PluginCall call) {
        if (getPermissionState("mic") != PermissionState.GRANTED) { requestPermissionForAlias("mic", call, "micGranted"); return; }
        begin(call, false);
    }

    @PermissionCallback
    private void micGranted(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) begin(call, false);
        else call.reject("permission", "9");
    }

    private ComponentName googleService() {
        ComponentName c = new ComponentName("com.google.android.googlequicksearchbox", "com.google.android.voicesearch.serviceapi.GoogleRecognitionService");
        try { getContext().getPackageManager().getServiceInfo(c, 0); return c; } catch (PackageManager.NameNotFoundException e) { return null; }
    }

    private void begin(PluginCall call, boolean useDefault) {
        if (pending != null) { try { pending.reject("busy", "8"); } catch (Exception ignored) {} }
        pending = call;
        call.setKeepAlive(true);
        lastPartial = "";
        triedDefault = useDefault;
        final String lang = call.getString("lang", "en-US");
        main.post(() -> {
            try {
                destroy();
                ComponentName g = useDefault ? null : googleService();
                rec = g != null ? SpeechRecognizer.createSpeechRecognizer(getContext(), g) : SpeechRecognizer.createSpeechRecognizer(getContext());
                rec.setRecognitionListener(listener);
                Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang);
                i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
                i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
                i.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getContext().getPackageName());
                i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L);
                i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L);
                rec.startListening(i);
                notifyListeners("state", new JSObject().put("state", "listening"));
            } catch (Throwable e) {
                done(null, "5", String.valueOf(e.getMessage()));
            }
        });
    }

    @PluginMethod
    public void stop(PluginCall call) {
        main.post(() -> { try { if (rec != null) rec.stopListening(); } catch (Exception ignored) {} });
        call.resolve();
    }

    @PluginMethod
    public void cancel(PluginCall call) {
        main.post(() -> { destroy(); if (pending != null) { PluginCall p = pending; pending = null; p.reject("cancelled", "0"); p.setKeepAlive(false); } });
        call.resolve();
    }

    private void destroy() { try { if (rec != null) { rec.cancel(); rec.destroy(); } } catch (Exception ignored) {} rec = null; }

    private void done(String text, String code, String msg) {
        PluginCall p = pending;
        pending = null;
        main.post(this::destroy);
        notifyListeners("state", new JSObject().put("state", "stopped"));
        if (p == null) return;
        p.setKeepAlive(false);
        if (text != null && !text.isEmpty()) p.resolve(new JSObject().put("text", text));
        else p.reject(msg == null ? "error " + code : msg, code);
    }

    private String first(Bundle b) {
        ArrayList<String> r = b == null ? null : b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return (r != null && !r.isEmpty() && r.get(0) != null) ? r.get(0) : "";
    }

    private final RecognitionListener listener = new RecognitionListener() {
        @Override public void onReadyForSpeech(Bundle params) { notifyListeners("state", new JSObject().put("state", "ready")); }
        @Override public void onBeginningOfSpeech() { notifyListeners("state", new JSObject().put("state", "speaking")); }
        @Override public void onRmsChanged(float rms) {
            long now = System.currentTimeMillis();
            if (now - lastLevel > 120) { lastLevel = now; notifyListeners("level", new JSObject().put("rms", (Object) Double.valueOf(rms))); }
        }
        @Override public void onBufferReceived(byte[] buffer) {}
        @Override public void onEndOfSpeech() { notifyListeners("state", new JSObject().put("state", "processing")); }
        @Override public void onError(int error) {
            // Google service missing or broken on this phone: try the phone's default recognizer once.
            if (!triedDefault && (error == SpeechRecognizer.ERROR_CLIENT || error == 10 || error == 11 || error == 12 || error == 13) && pending != null) {
                PluginCall p = pending; pending = null; begin(p, true); return;
            }
            if (!lastPartial.isEmpty() && (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT || error == SpeechRecognizer.ERROR_CLIENT)) { done(lastPartial, null, null); return; }
            done(null, String.valueOf(error), "error " + error);
        }
        @Override public void onResults(Bundle results) { String t = first(results); done(t.isEmpty() ? lastPartial : t, "7", "no match"); }
        @Override public void onPartialResults(Bundle partial) {
            String t = first(partial);
            if (!t.isEmpty()) { lastPartial = t; notifyListeners("partial", new JSObject().put("text", t)); }
        }
        @Override public void onEvent(int eventType, Bundle params) {}
    };
}
