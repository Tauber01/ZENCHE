package com.tauber.nikonlink;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

final class CaptureWorkflow {
    static final class Configuration {
        String name = "未命名会话";
        String namingTemplate = "{session}_{date}_{counter}";
        String creator = "";
        String rights = "";
        int rating;
        boolean dualBackupEnabled = true;
    }

    private static final String PREFERENCES = "zenche-capture-workflow";
    private final File rootDirectory;
    private final SharedPreferences preferences;
    private Configuration configuration = new Configuration();
    private boolean active;
    private int counter = 1;
    private String status = "尚未开始拍摄会话";

    CaptureWorkflow(Context context, File rootDirectory) {
        this.rootDirectory = rootDirectory;
        preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
        load();
    }

    synchronized Configuration configuration() {
        Configuration copy = new Configuration();
        copy.name = configuration.name;
        copy.namingTemplate = configuration.namingTemplate;
        copy.creator = configuration.creator;
        copy.rights = configuration.rights;
        copy.rating = configuration.rating;
        copy.dualBackupEnabled = configuration.dualBackupEnabled;
        return copy;
    }

    synchronized boolean isActive() {
        return active;
    }

    synchronized String status() {
        return status;
    }

    synchronized void begin(Configuration requested) throws Exception {
        configuration = normalize(requested);
        active = true;
        counter = 1;
        ensureDirectories();
        persist();
        status = "会话进行中 · " + configuration.name;
    }

    synchronized void end() {
        active = false;
        persist();
        status = "拍摄会话已结束";
    }

    synchronized String reserveBaseName(String cameraName) {
        String stamp = new SimpleDateFormat(
                "yyyyMMdd_HHmmss",
                Locale.CHINA).format(new Date());
        String value = configuration.namingTemplate
                .replace("{session}", configuration.name)
                .replace("{date}", stamp)
                .replace("{counter}", String.format(Locale.ROOT, "%04d", counter))
                .replace("{camera}", cameraName == null ? "Camera" : cameraName);
        counter++;
        persist();
        return sanitize(value);
    }

    synchronized File store(
            byte[] bytes,
            String originalFilename,
            String cameraName,
            String reservedBaseName) throws Exception {
        return store(
                bytes,
                originalFilename,
                cameraName,
                reservedBaseName,
                null);
    }

    synchronized File store(
            byte[] bytes,
            String originalFilename,
            String cameraName,
            String reservedBaseName,
            LocationTaggingController.Snapshot location) throws Exception {
        ensureDirectories();
        String extension = extension(originalFilename);
        String base = reservedBaseName == null
                ? reserveBaseName(cameraName)
                : sanitize(reservedBaseName);
        File destination = uniqueFile(primaryDirectory(), base, extension);
        try (FileOutputStream output = new FileOutputStream(destination)) {
            output.write(bytes);
            output.getFD().sync();
        }
        finalizeFile(destination, location);
        status = "已写入会话 · " + destination.getName();
        return destination;
    }

    synchronized File importFile(
            InputStream input,
            String originalFilename,
            String cameraName,
            String reservedBaseName) throws Exception {
        ensureDirectories();
        String extension = extension(originalFilename);
        String base = reservedBaseName == null
                ? reserveBaseName(cameraName)
                : sanitize(reservedBaseName);
        File destination = uniqueFile(primaryDirectory(), base, extension);
        try (FileOutputStream output = new FileOutputStream(destination)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            long total = 0;
            while ((count = input.read(buffer)) >= 0) {
                if (count == 0) continue;
                output.write(buffer, 0, count);
                total += count;
            }
            if (total == 0) {
                destination.delete();
                throw new Exception("所选文件为空。");
            }
            output.getFD().sync();
        }
        finalizeFile(destination, null);
        status = "已写入会话 · " + destination.getName();
        return destination;
    }

    synchronized File reserveExternalRecording(
            String cameraName,
            String extension) throws Exception {
        ensureDirectories();
        String normalized = extension == null
                ? "avi"
                : extension.replace(".", "").toLowerCase(Locale.ROOT);
        if (!"avi".equals(normalized)) normalized = "avi";
        return uniqueFile(
                primaryDirectory(),
                reserveBaseName(cameraName),
                normalized);
    }

    synchronized void completeExternalRecording(File recording) throws Exception {
        if (recording == null || !recording.isFile() || recording.length() == 0) {
            throw new Exception("外录文件为空。");
        }
        finalizeFile(recording, null);
        status = "外录已写入会话 · " + recording.getName();
    }

    private void finalizeFile(
            File primary,
            LocationTaggingController.Snapshot location) throws Exception {
        if (!active && location == null) return;
        File sidecar = new File(
                primary.getParentFile(),
                stem(primary.getName()) + ".xmp");
        writeText(sidecar, xmp(primary.getName(), location));
        File backupDirectory = active ? backupDirectory() : null;
        if (active && backupDirectory != null) {
            File backup = new File(backupDirectory, primary.getName());
            copy(primary, backup);
            copy(sidecar, new File(backupDirectory, sidecar.getName()));
        }
        if (!active) return;
        String checksum = sha256(primary);
        File manifest = new File(sessionRoot(), "checksums.sha256");
        try (FileOutputStream output = new FileOutputStream(manifest, true)) {
            output.write(
                    (checksum + "  Primary/" + primary.getName() + "\n")
                            .getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
        }
    }

    private File primaryDirectory() {
        return active ? new File(sessionRoot(), "Primary") : rootDirectory;
    }

    private File backupDirectory() {
        return active && configuration.dualBackupEnabled
                ? new File(sessionRoot(), "Backup")
                : null;
    }

    private File sessionRoot() {
        return new File(
                new File(rootDirectory, "Sessions"),
                sanitize(configuration.name));
    }

    private void ensureDirectories() throws Exception {
        if (!primaryDirectory().exists() && !primaryDirectory().mkdirs()) {
            throw new Exception("无法创建拍摄会话主目录。");
        }
        File backup = backupDirectory();
        if (backup != null && !backup.exists() && !backup.mkdirs()) {
            throw new Exception("无法创建拍摄会话副本目录。");
        }
    }

    private void load() {
        active = preferences.getBoolean("active", false);
        counter = Math.max(1, preferences.getInt("counter", 1));
        String stored = preferences.getString("configuration", "");
        if (stored != null && !stored.isEmpty()) {
            try {
                JSONObject json = new JSONObject(stored);
                configuration.name = json.optString("name", configuration.name);
                configuration.namingTemplate = json.optString(
                        "namingTemplate",
                        configuration.namingTemplate);
                configuration.creator = json.optString("creator", "");
                configuration.rights = json.optString("rights", "");
                configuration.rating = json.optInt("rating", 0);
                configuration.dualBackupEnabled = json.optBoolean(
                        "dualBackupEnabled",
                        true);
            } catch (Exception ignored) {
            }
        }
        if (active) {
            try {
                ensureDirectories();
                status = "会话进行中 · " + configuration.name;
            } catch (Exception error) {
                active = false;
                status = "拍摄会话目录不可用";
            }
        }
    }

    private void persist() {
        JSONObject json = new JSONObject();
        try {
            json.put("name", configuration.name);
            json.put("namingTemplate", configuration.namingTemplate);
            json.put("creator", configuration.creator);
            json.put("rights", configuration.rights);
            json.put("rating", configuration.rating);
            json.put("dualBackupEnabled", configuration.dualBackupEnabled);
        } catch (Exception ignored) {
        }
        preferences.edit()
                .putBoolean("active", active)
                .putInt("counter", counter)
                .putString("configuration", json.toString())
                .apply();
    }

    private static Configuration normalize(Configuration value) {
        Configuration result = new Configuration();
        result.name = value.name == null || value.name.trim().isEmpty()
                ? "未命名会话"
                : value.name.trim();
        result.namingTemplate = value.namingTemplate == null
                ? "{session}_{date}_{counter}"
                : value.namingTemplate.trim();
        if (!result.namingTemplate.contains("{counter}")) {
            result.namingTemplate += "_{counter}";
        }
        result.creator = value.creator == null ? "" : value.creator.trim();
        result.rights = value.rights == null ? "" : value.rights.trim();
        result.rating = Math.max(0, Math.min(5, value.rating));
        result.dualBackupEnabled = value.dualBackupEnabled;
        return result;
    }

    private String xmp(
            String filename,
            LocationTaggingController.Snapshot location) {
        String gps = location == null ? "" : gpsAttributes(location);
        return "<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n"
                + "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF "
                + "xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">"
                + "<rdf:Description rdf:about=\"\" "
                + "xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" "
                + "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
                + "xmlns:exif=\"http://ns.adobe.com/exif/1.0/\" "
                + "xmp:Rating=\"" + configuration.rating + "\""
                + gps + ">"
                + "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">"
                + xml(configuration.name)
                + "</rdf:li></rdf:Alt></dc:title>"
                + "<dc:creator><rdf:Seq><rdf:li>"
                + xml(configuration.creator)
                + "</rdf:li></rdf:Seq></dc:creator>"
                + "<dc:rights><rdf:Alt><rdf:li xml:lang=\"x-default\">"
                + xml(configuration.rights)
                + "</rdf:li></rdf:Alt></dc:rights>"
                + "<dc:description><rdf:Alt><rdf:li xml:lang=\"x-default\">"
                + xml(filename)
                + "</rdf:li></rdf:Alt></dc:description>"
                + "</rdf:Description></rdf:RDF></x:xmpmeta>\n"
                + "<?xpacket end=\"w\"?>";
    }

    private static String gpsAttributes(
            LocationTaggingController.Snapshot location) {
        int altitude = (int) Math.round(Math.abs(location.altitude) * 100);
        int accuracy = (int) Math.round(Math.max(0, location.accuracy) * 100);
        String date = new SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
                Locale.ROOT).format(new Date(location.timestamp));
        return " exif:GPSLatitude=\""
                + gpsCoordinate(location.latitude, "N", "S")
                + "\" exif:GPSLongitude=\""
                + gpsCoordinate(location.longitude, "E", "W")
                + "\" exif:GPSAltitude=\"" + altitude + "/100\""
                + " exif:GPSAltitudeRef=\""
                + (location.altitude < 0 ? "1" : "0") + "\""
                + " exif:GPSHPositioningError=\"" + accuracy + "/100\""
                + " exif:GPSDateStamp=\"" + date + "\"";
    }

    private static String gpsCoordinate(
            double value,
            String positive,
            String negative) {
        double absolute = Math.abs(value);
        int degrees = (int) absolute;
        double minutes = (absolute - degrees) * 60;
        return String.format(
                Locale.ROOT,
                "%d,%.6f%s",
                degrees,
                minutes,
                value >= 0 ? positive : negative);
    }

    private static void copy(File source, File destination) throws Exception {
        try (FileInputStream input = new FileInputStream(source);
             FileOutputStream output = new FileOutputStream(destination)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                if (count > 0) output.write(buffer, 0, count);
            }
            output.getFD().sync();
        }
    }

    private static void writeText(File destination, String value) throws Exception {
        try (FileOutputStream output = new FileOutputStream(destination)) {
            output.write(value.getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
        }
    }

    private static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                if (count > 0) digest.update(buffer, 0, count);
            }
        }
        StringBuilder result = new StringBuilder();
        for (byte value : digest.digest()) {
            result.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        }
        return result.toString();
    }

    private static File uniqueFile(File directory, String base, String extension) {
        File result = new File(directory, base + "." + extension);
        int suffix = 2;
        while (result.exists()) {
            result = new File(directory, base + "_" + suffix + "." + extension);
            suffix++;
        }
        return result;
    }

    private static String extension(String filename) {
        int dot = filename == null ? -1 : filename.lastIndexOf('.');
        String value = dot >= 0 ? filename.substring(dot + 1) : "jpg";
        value = value.replaceAll("[^A-Za-z0-9]", "").toLowerCase(Locale.ROOT);
        return value.isEmpty() ? "jpg" : value;
    }

    private static String stem(String filename) {
        int dot = filename.lastIndexOf('.');
        return dot > 0 ? filename.substring(0, dot) : filename;
    }

    private static String sanitize(String value) {
        String result = value == null
                ? ""
                : value.replaceAll("[\\\\/:?%*|\"<>]", "_").trim();
        if (result.isEmpty()) result = "ZENCHE";
        return result.length() > 120 ? result.substring(0, 120) : result;
    }

    private static String xml(String value) {
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&apos;");
    }
}
