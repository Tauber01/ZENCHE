package com.tauber.nikonlink;

import android.Manifest;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.provider.Settings;

import java.io.File;
import java.io.FileInputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Permission-safe bridge between the system photo picker and ZENCHE's editor.
 * A picked asset is always copied into the app library before it can be edited;
 * an exported result is always inserted as a new system-library asset.
 */
final class SystemPhotoEditBridge {
    private static final long MAX_IMPORT_BYTES = 64L * 1024L * 1024L;

    private SystemPhotoEditBridge() {}

    static Intent pickerIntent() {
        Intent intent;
        if (Build.VERSION.SDK_INT >= 33) {
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
        } else {
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                            | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        }
        intent.setType("image/*");
        return intent;
    }

    static Intent permissionSettingsIntent(Context context) {
        return new Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + context.getPackageName()));
    }

    static boolean needsLegacyWritePermission(Context context) {
        return Build.VERSION.SDK_INT <= 28
                && context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        != PackageManager.PERMISSION_GRANTED;
    }

    static File importEditableCopy(
            Context context,
            CaptureWorkflow workflow,
            Uri sourceUri) throws Exception {
        ContentResolver resolver = context.getContentResolver();
        long reportedSize = contentSize(resolver, sourceUri);
        if (reportedSize > MAX_IMPORT_BYTES) {
            throw new IllegalArgumentException("系统照片超过 64 MB 导入上限");
        }
        String sourceName = displayName(resolver, sourceUri);
        if (sourceName == null || sourceName.trim().isEmpty()) {
            sourceName = "system-photo.jpg";
        }
        try (InputStream input = resolver.openInputStream(sourceUri)) {
            if (input == null) {
                throw new IllegalStateException("无法读取所选系统照片");
            }
            return workflow.importFile(
                    new SizeLimitedInputStream(input, MAX_IMPORT_BYTES),
                    sourceName,
                    "System Album Editor",
                    workflow.reserveBaseName("System Album Editor"));
        }
    }

    static Uri saveNewCopy(Context context, File editedFile) throws Exception {
        if (editedFile == null || !editedFile.isFile() || editedFile.length() == 0) {
            throw new IllegalArgumentException("没有可保存的编辑结果");
        }
        if (needsLegacyWritePermission(context)) {
            throw new SecurityException("需要照片写入权限；请在系统设置中允许后重试");
        }

        String extension = extension(editedFile.getName());
        String mimeType = mimeType(extension);
        String displayName = "ZENCHE_edited_"
                + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date())
                + "." + extension;
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, displayName);
        values.put(MediaStore.Images.Media.MIME_TYPE, mimeType);
        if (Build.VERSION.SDK_INT >= 29) {
            values.put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/ZENCHE");
            values.put(MediaStore.Images.Media.IS_PENDING, 1);
        }

        ContentResolver resolver = context.getContentResolver();
        Uri destination = resolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values);
        if (destination == null) {
            throw new IllegalStateException("系统相册未创建目标文件");
        }
        boolean published = false;
        try {
            try (InputStream input = new FileInputStream(editedFile);
                 OutputStream output = resolver.openOutputStream(destination, "w")) {
                if (output == null) {
                    throw new IllegalStateException("无法写入系统相册");
                }
                byte[] buffer = new byte[64 * 1024];
                int count;
                long total = 0;
                while ((count = input.read(buffer)) >= 0) {
                    if (count == 0) continue;
                    output.write(buffer, 0, count);
                    total += count;
                }
                output.flush();
                if (total == 0) {
                    throw new IllegalStateException("编辑结果为空");
                }
            }
            if (Build.VERSION.SDK_INT >= 29) {
                ContentValues ready = new ContentValues();
                ready.put(MediaStore.Images.Media.IS_PENDING, 0);
                if (resolver.update(destination, ready, null, null) <= 0) {
                    throw new IllegalStateException("系统相册未发布编辑副本");
                }
            }
            published = true;
            return destination;
        } finally {
            if (!published) {
                resolver.delete(destination, null, null);
            }
        }
    }

    private static String displayName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(
                uri,
                new String[]{OpenableColumns.DISPLAY_NAME},
                null,
                null,
                null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (column >= 0) return cursor.getString(column);
            }
        } catch (RuntimeException ignored) {
        }
        return uri.getLastPathSegment();
    }

    private static long contentSize(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(
                uri,
                new String[]{OpenableColumns.SIZE},
                null,
                null,
                null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int column = cursor.getColumnIndex(OpenableColumns.SIZE);
                if (column >= 0 && !cursor.isNull(column)) {
                    return cursor.getLong(column);
                }
            }
        } catch (RuntimeException ignored) {
        }
        return -1;
    }

    /** Enforces the limit even when a provider omits or lies about SIZE. */
    private static final class SizeLimitedInputStream extends FilterInputStream {
        private final long limit;
        private long total;

        SizeLimitedInputStream(InputStream input, long limit) {
            super(input);
            this.limit = limit;
        }

        @Override
        public int read() throws IOException {
            int value = super.read();
            if (value >= 0) {
                total++;
                enforceLimit();
            }
            return value;
        }

        @Override
        public int read(byte[] buffer, int offset, int length) throws IOException {
            int count = super.read(buffer, offset, length);
            if (count > 0) {
                total += count;
                enforceLimit();
            }
            return count;
        }

        private void enforceLimit() throws IOException {
            if (total > limit) {
                throw new IOException("系统照片超过 64 MB 导入上限");
            }
        }
    }

    private static String extension(String filename) {
        String lower = filename.toLowerCase(Locale.US);
        int dot = lower.lastIndexOf('.');
        String value = dot >= 0 ? lower.substring(dot + 1) : "jpg";
        switch (value) {
            case "jpeg":
            case "png":
            case "heic":
            case "heif":
            case "tif":
            case "tiff":
                return value;
            default:
                return "jpg";
        }
    }

    private static String mimeType(String extension) {
        switch (extension) {
            case "png": return "image/png";
            case "heic":
            case "heif": return "image/heic";
            case "tif":
            case "tiff": return "image/tiff";
            default: return "image/jpeg";
        }
    }
}
