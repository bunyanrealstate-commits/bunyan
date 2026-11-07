package com.bunyan.english;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

import java.io.File;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Downloads the AI model with several parallel connections (much faster than one),
 * as a foreground service so it keeps going with the app closed. Finished parts are
 * remembered, so a stopped download resumes where it left off.
 */
public class ModelDownloadService extends Service {
    public static final String NAME = "gemma3-1b-it-int4.task";
    private static final int THREADS = 8;
    private static final long CHUNK = 8L * 1024 * 1024;
    private static final String CH = "model_dl";
    private static final int NID = 4471;

    public static volatile boolean running = false;
    public static volatile String error = null;
    public static final AtomicLong loaded = new AtomicLong(0);
    public static volatile long total = -1;

    private volatile String resolved;
    private final AtomicBoolean failed = new AtomicBoolean(false);

    static File ext(Context c) { return new File(c.getExternalFilesDir(null), NAME); }
    static File part(Context c) { return new File(c.getExternalFilesDir(null), NAME + ".part"); }
    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("llm", Context.MODE_PRIVATE); }

    @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (running) return START_NOT_STICKY;
        final String url = intent != null ? intent.getStringExtra("url") : prefs(this).getString("url", null);
        if (url == null) { stopSelf(); return START_NOT_STICKY; }
        prefs(this).edit().putString("url", url).apply();
        running = true; error = null; failed.set(false);
        startFg(notif("بيبدأ التحميل…", 0, true));
        new Thread(() -> run(url)).start();
        return START_NOT_STICKY;
    }

    private void startFg(Notification n) {
        if (Build.VERSION.SDK_INT >= 29) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        else startForeground(NID, n);
    }

    private Notification notif(String text, int pct, boolean ongoing) {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CH) == null) {
            NotificationChannel ch = new NotificationChannel(CH, "تحميل عقل صاحبك", NotificationManager.IMPORTANCE_LOW);
            nm.createNotificationChannel(ch);
        }
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, CH) : new Notification.Builder(this);
        b.setSmallIcon(android.R.drawable.stat_sys_download)
         .setContentTitle("عقل صاحبك — مدرّب الإنجليزي")
         .setContentText(text)
         .setOnlyAlertOnce(true)
         .setOngoing(ongoing);
        if (ongoing) b.setProgress(100, pct, pct <= 0);
        else b.setSmallIcon(android.R.drawable.stat_sys_download_done);
        android.content.Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (open != null) b.setContentIntent(android.app.PendingIntent.getActivity(this, 0, open, android.app.PendingIntent.FLAG_IMMUTABLE));
        return b.build();
    }

    private String resolve(String u) throws Exception {
        for (int i = 0; i < 8; i++) {
            HttpURLConnection c = (HttpURLConnection) new URL(u).openConnection();
            c.setInstanceFollowRedirects(false);
            c.setConnectTimeout(20000);
            c.setReadTimeout(30000);
            c.setRequestProperty("Range", "bytes=0-0");
            int code = c.getResponseCode();
            if (code >= 300 && code < 400) { u = new URL(new URL(u), c.getHeaderField("Location")).toString(); c.disconnect(); continue; }
            if (code == 206) {
                String cr = c.getHeaderField("Content-Range");
                if (cr != null && cr.contains("/")) total = Long.parseLong(cr.substring(cr.lastIndexOf('/') + 1).trim());
            } else if (code == 200) {
                total = c.getContentLengthLong();
            } else throw new Exception("HTTP " + code);
            c.disconnect();
            return u;
        }
        throw new Exception("too many redirects");
    }

    private void run(String url) {
        try {
            resolved = resolve(url);
            if (total <= 0) throw new Exception("size unknown");
            final int n = (int) ((total + CHUNK - 1) / CHUNK);
            SharedPreferences p = prefs(this);
            String doneMap = p.getString("chunks", "");
            if (p.getLong("total", -1) != total || doneMap.length() != n || !part(this).exists()) {
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < n; i++) sb.append('0');
                doneMap = sb.toString();
                if (part(this).exists()) part(this).delete();
                p.edit().putLong("total", total).putString("chunks", doneMap).apply();
            }
            try (RandomAccessFile raf = new RandomAccessFile(part(this), "rw")) { raf.setLength(total); }
            final char[] map = doneMap.toCharArray();
            long have = 0;
            for (int i = 0; i < n; i++) if (map[i] == '1') have += Math.min(CHUNK, total - i * CHUNK);
            loaded.set(have);

            ExecutorService pool = Executors.newFixedThreadPool(THREADS);
            for (int i = 0; i < n; i++) {
                if (map[i] == '1') continue;
                final int idx = i;
                pool.execute(() -> {
                    if (failed.get()) return;
                    if (fetchChunk(idx)) {
                        synchronized (map) {
                            map[idx] = '1';
                            prefs(this).edit().putString("chunks", new String(map)).apply();
                        }
                    } else failed.set(true);
                });
            }
            pool.shutdown();
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            long lastL = loaded.get(), lastT = System.currentTimeMillis();
            String speed = "";
            while (!pool.awaitTermination(1, TimeUnit.SECONDS)) {
                long now = System.currentTimeMillis(), l = loaded.get();
                if (now - lastT >= 2000) {
                    speed = " · " + String.format(java.util.Locale.US, "%.1f", (l - lastL) / 1048576.0 / ((now - lastT) / 1000.0)) + " MB/s";
                    lastL = l; lastT = now;
                }
                int pct = (int) (l * 100 / total);
                nm.notify(NID, notif((l / 1048576) + " / " + (total / 1048576) + " MB (" + pct + "%)" + speed, pct, true));
            }
            if (failed.get()) throw new Exception("network");
            File f = ext(this);
            if (f.exists()) f.delete();
            if (!part(this).renameTo(f)) throw new Exception("rename");
            prefs(this).edit().putBoolean("ready", true).remove("chunks").remove("total").apply();
            finish("صاحبك جاهز — افتح المحادثة", null);
        } catch (Throwable e) {
            finish("التحميل وقف — افتح التطبيق واضغط كمّل", String.valueOf(e.getMessage()));
        }
    }

    private boolean fetchChunk(int idx) {
        long start = idx * CHUNK, end = Math.min(total, start + CHUNK) - 1;
        for (int attempt = 0; attempt < 6 && !failed.get(); attempt++) {
            long got = 0;
            try {
                HttpURLConnection c = (HttpURLConnection) new URL(resolved).openConnection();
                c.setConnectTimeout(20000);
                c.setReadTimeout(30000);
                c.setRequestProperty("Range", "bytes=" + start + "-" + end);
                int code = c.getResponseCode();
                if (code == 403 || code == 401 || code == 410) { resolved = resolve(prefs(this).getString("url", resolved)); throw new Exception("expired"); }
                if (code != 206) throw new Exception("HTTP " + code);
                try (InputStream in = c.getInputStream(); RandomAccessFile raf = new RandomAccessFile(part(this), "rw")) {
                    raf.seek(start);
                    byte[] buf = new byte[1 << 16];
                    int r;
                    while ((r = in.read(buf)) > 0) { raf.write(buf, 0, r); got += r; loaded.addAndGet(r); }
                }
                if (got == end - start + 1) return true;
                throw new Exception("short");
            } catch (Throwable e) {
                loaded.addAndGet(-got);
                try { Thread.sleep(1500L * (attempt + 1)); } catch (InterruptedException ignored) {}
            }
        }
        return false;
    }

    private void finish(String text, String err) {
        error = err;
        running = false;
        stopForeground(true);
        ((NotificationManager) getSystemService(NOTIFICATION_SERVICE)).notify(NID + 1, notif(text, 100, false));
        stopSelf();
    }
}
