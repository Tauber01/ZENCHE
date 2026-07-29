package com.tauber.nikonlink;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Pattern;

final class DiagnosticLogger {
    private static final String TAG = "NikonLink";
    private static final String ISSUE_URL =
            "https://github.com/Tauber01/NikonLink/issues/new";
    private static final long MAX_FILE_BYTES = 5L * 1024L * 1024L;
    private static final long RETENTION_MILLIS = 14L * 24L * 60L * 60L * 1000L;
    private static final int ISSUE_LOG_LIMIT = 2_500;

    private final Context context;
    private final File directory;
    private final String sessionId =
            UUID.randomUUID().toString().substring(0, 8);

    DiagnosticLogger(Context context) {
        this.context = context.getApplicationContext();
        File base = this.context.getExternalFilesDir(null);
        if (base == null) base = this.context.getFilesDir();
        directory = new File(base, "logs");
        if (!directory.exists() && !directory.mkdirs()) {
            Log.e(TAG, "Unable to create diagnostic log directory");
        }
        removeExpiredLogs();
    }

    File getDirectory() {
        return directory;
    }

    void startSession() {
        info(
                "app",
                "会话启动；版本=" + appVersion()
                        + "；系统=Android " + Build.VERSION.RELEASE
                        + " (API " + Build.VERSION.SDK_INT + ")"
                        + "；设备=" + Build.MANUFACTURER + " " + Build.MODEL);
    }

    void endSession() {
        info("app", "会话结束");
    }

    void debug(String category, String message) {
        write("DEBUG", category, message);
    }

    void info(String category, String message) {
        write("INFO", category, message);
    }

    void warning(String category, String message) {
        write("WARN", category, message);
    }

    void error(String category, String message) {
        write("ERROR", category, message);
    }

    Uri githubIssueUri() {
        String body = "## 问题描述\n\n请描述发生了什么，以及如何复现。\n\n"
                + "## 环境\n\n"
                + "- 平台：Android " + Build.VERSION.RELEASE
                + "（API " + Build.VERSION.SDK_INT + "）\n"
                + "- 设备：" + redact(Build.MANUFACTURER + " " + Build.MODEL) + "\n"
                + "- Nikon Link：" + appVersion() + "\n"
                + "- 会话：" + sessionId + "\n\n"
                + "## 最近诊断日志（已脱敏）\n\n```text\n"
                + recentText(ISSUE_LOG_LIMIT)
                + "\n```\n\n"
                + "> 提交前请检查以上内容；不要填写密码、令牌或相机序列号。";
        return Uri.parse(ISSUE_URL)
                .buildUpon()
                .appendQueryParameter("title", "[Android] ")
                .appendQueryParameter("body", body)
                .build();
    }

    synchronized String recentText(int maxCharacters) {
        File[] candidates = directory.listFiles(
                (parent, name) -> name.toLowerCase(Locale.ROOT).endsWith(".log"));
        if (candidates == null || candidates.length == 0) {
            return "暂无日志。";
        }
        List<File> files = new ArrayList<>(Arrays.asList(candidates));
        files.sort(Comparator.comparingLong(File::lastModified).reversed());

        StringBuilder result = new StringBuilder();
        for (File file : files) {
            if (result.length() >= maxCharacters) break;
            int remaining = maxCharacters - result.length();
            String tail = tail(file, remaining);
            if (!tail.isEmpty()) {
                if (result.length() > 0) result.insert(0, "\n");
                result.insert(0, tail);
            }
        }
        if (result.length() > maxCharacters) {
            return result.substring(result.length() - maxCharacters);
        }
        return result.length() == 0 ? "暂无日志。" : redact(result.toString());
    }

    private synchronized void write(
            String level,
            String category,
            String message) {
        String safeMessage = redact(message == null ? "未知错误" : message);
        String entry = timestamp("yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
                + " [" + level + "]"
                + " [" + sessionId + "]"
                + " [" + singleLine(redact(category)) + "] "
                + limit(safeMessage, 32_768).replace("\n", "\n    ")
                + "\n";
        int priority = "ERROR".equals(level)
                ? Log.ERROR
                : "WARN".equals(level) ? Log.WARN : Log.INFO;
        Log.println(priority, TAG, "[" + category + "] " + safeMessage);

        if (!directory.exists() && !directory.mkdirs()) return;
        File target = currentLogFile();
        if (target.length() >= MAX_FILE_BYTES) {
            File rotated = new File(
                    directory,
                    "NikonLink-" + timestamp("yyyy-MM-dd-HHmmss")
                            + "-" + sessionId + ".log");
            if (!target.renameTo(rotated)) {
                Log.w(TAG, "Unable to rotate diagnostic log");
            }
        }
        try (FileOutputStream output = new FileOutputStream(target, true)) {
            output.write(entry.getBytes(StandardCharsets.UTF_8));
            output.flush();
        } catch (Exception error) {
            Log.e(TAG, "Unable to write diagnostic log", error);
        }
    }

    private File currentLogFile() {
        return new File(
                directory,
                "NikonLink-" + timestamp("yyyy-MM-dd") + ".log");
    }

    private String tail(File file, int maxCharacters) {
        int byteLimit = Math.min(maxCharacters * 4, 32_000);
        try (RandomAccessFile input = new RandomAccessFile(file, "r")) {
            long start = Math.max(0, input.length() - byteLimit);
            input.seek(start);
            byte[] bytes = new byte[(int) (input.length() - start)];
            input.readFully(bytes);
            String text = new String(bytes, StandardCharsets.UTF_8);
            if (start > 0) {
                int newline = text.indexOf('\n');
                if (newline >= 0 && newline + 1 < text.length()) {
                    text = text.substring(newline + 1);
                }
            }
            return text.length() > maxCharacters
                    ? text.substring(text.length() - maxCharacters)
                    : text;
        } catch (Exception ignored) {
            return "";
        }
    }

    private void removeExpiredLogs() {
        File[] files = directory.listFiles(
                (parent, name) -> name.toLowerCase(Locale.ROOT).endsWith(".log"));
        if (files == null) return;
        long cutoff = System.currentTimeMillis() - RETENTION_MILLIS;
        for (File file : files) {
            if (file.lastModified() < cutoff && !file.delete()) {
                Log.w(TAG, "Unable to remove expired diagnostic log");
            }
        }
    }

    private String appVersion() {
        try {
            PackageInfo info = context.getPackageManager()
                    .getPackageInfo(context.getPackageName(), 0);
            long build = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? info.getLongVersionCode()
                    : info.versionCode;
            return info.versionName + " (" + build + ")";
        } catch (Exception ignored) {
            return "unknown";
        }
    }

    private String redact(String value) {
        String result = value;
        result = result.replace(context.getFilesDir().getAbsolutePath(), "<APP_DATA>");
        File external = context.getExternalFilesDir(null);
        if (external != null) {
            result = result.replace(external.getAbsolutePath(), "<APP_FILES>");
        }
        Pattern secrets = Pattern.compile(
                "(?i)((?:token|key|password|secret|serial(?: number)?|"
                        + "serialnumber|username)\\s*[:=]\\s*)\\S+");
        return secrets.matcher(result).replaceAll("$1<REDACTED>");
    }

    private static String singleLine(String value) {
        return value.replaceAll("\\s+", " ");
    }

    private static String limit(String value, int maxCharacters) {
        return value.length() <= maxCharacters
                ? value
                : value.substring(0, maxCharacters);
    }

    private static String timestamp(String pattern) {
        return new SimpleDateFormat(pattern, Locale.US).format(new Date());
    }
}
