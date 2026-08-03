package com.tauber.nikonlink;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/** Standard PTP datasets used by the camera-card browser. */
final class CameraStorage {
    static final class Volume {
        final long id;
        final String name;
        final long capacityBytes;
        final long freeBytes;
        final long freeImages;
        final boolean readOnly;

        Volume(
                long id,
                String name,
                long capacityBytes,
                long freeBytes,
                long freeImages,
                boolean readOnly) {
            this.id = id;
            this.name = name;
            this.capacityBytes = capacityBytes;
            this.freeBytes = freeBytes;
            this.freeImages = freeImages;
            this.readOnly = readOnly;
        }
    }

    static final class Item {
        final long handle;
        final long storageId;
        final int format;
        final String filename;
        final long sizeBytes;
        final int width;
        final int height;
        final String capturedAt;
        final boolean protectedObject;

        Item(
                long handle,
                long storageId,
                int format,
                String filename,
                long sizeBytes,
                int width,
                int height,
                String capturedAt,
                boolean protectedObject) {
            this.handle = handle;
            this.storageId = storageId;
            this.format = format;
            this.filename = filename;
            this.sizeBytes = sizeBytes;
            this.width = width;
            this.height = height;
            this.capturedAt = capturedAt;
            this.protectedObject = protectedObject;
        }

        boolean isVideo() {
            String lower = filename.toLowerCase(Locale.ROOT);
            return lower.endsWith(".mov") || lower.endsWith(".mp4")
                    || lower.endsWith(".avi") || lower.endsWith(".m4v")
                    || lower.endsWith(".mts") || lower.endsWith(".m2ts");
        }
    }

    static final class Snapshot {
        final List<Volume> volumes;
        final List<Item> items;

        Snapshot(List<Volume> volumes, List<Item> items) {
            this.volumes = Collections.unmodifiableList(new ArrayList<>(volumes));
            this.items = Collections.unmodifiableList(new ArrayList<>(items));
        }

        long capacityBytes() {
            long result = 0;
            for (Volume volume : volumes) result = saturatingAdd(result, volume.capacityBytes);
            return result;
        }

        long freeBytes() {
            long result = 0;
            for (Volume volume : volumes) result = saturatingAdd(result, volume.freeBytes);
            return result;
        }
    }

    static List<Long> parseStorageIds(byte[] data) {
        if (data == null || data.length < 4) return Collections.emptyList();
        int count = safeCount(u32(data, 0), data.length - 4, 4);
        List<Long> result = new ArrayList<>(count);
        for (int index = 0; index < count; index++) {
            result.add(u32(data, 4 + index * 4));
        }
        return result;
    }

    static List<Long> parseObjectHandles(byte[] data) {
        return parseStorageIds(data);
    }

    static Volume parseStorageInfo(long storageId, byte[] data) {
        if (data == null || data.length < 26) {
            return new Volume(storageId, storageLabel(storageId), 0, 0, 0, false);
        }
        int accessCapability = u16(data, 4);
        long capacity = u64Saturated(data, 6);
        long free = u64Saturated(data, 14);
        long freeImages = u32(data, 22);
        PtpString description = ptpString(data, 26);
        PtpString label = ptpString(data, description.nextOffset);
        String name = !label.value.isEmpty()
                ? label.value
                : !description.value.isEmpty() ? description.value : storageLabel(storageId);
        return new Volume(
                storageId,
                name,
                capacity,
                free,
                freeImages,
                accessCapability != 0);
    }

    static Item parseObjectInfo(long handle, byte[] data) {
        if (data == null || data.length < 52) return null;
        long storageId = u32(data, 0);
        int format = u16(data, 4);
        boolean protectedObject = u16(data, 6) != 0;
        long size = u32(data, 8);
        int width = saturatedInt(u32(data, 26));
        int height = saturatedInt(u32(data, 30));
        int associationType = u16(data, 42);
        PtpString filename = ptpString(data, 52);
        PtpString capturedAt = ptpString(data, filename.nextOffset);
        if (associationType != 0 || filename.value.isEmpty()) return null;
        return new Item(
                handle,
                storageId,
                format,
                filename.value,
                size,
                width,
                height,
                displayDate(capturedAt.value),
                protectedObject);
    }

    static boolean isAssociation(byte[] data) {
        return data != null && data.length >= 52 && u16(data, 42) != 0;
    }

    private static String displayDate(String value) {
        if (value == null || value.length() < 8) return "—";
        String date = value.substring(0, 4) + "-" + value.substring(4, 6)
                + "-" + value.substring(6, 8);
        if (value.length() >= 15 && value.charAt(8) == 'T') {
            date += " " + value.substring(9, 11) + ":" + value.substring(11, 13)
                    + ":" + value.substring(13, 15);
        }
        return date;
    }

    private static String storageLabel(long id) {
        return String.format(Locale.ROOT, "存储卡 %08X", id);
    }

    private static int u16(byte[] data, int offset) {
        if (offset < 0 || offset + 2 > data.length) return 0;
        return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
    }

    private static long u32(byte[] data, int offset) {
        if (offset < 0 || offset + 4 > data.length) return 0;
        return (data[offset] & 0xffL)
                | ((data[offset + 1] & 0xffL) << 8)
                | ((data[offset + 2] & 0xffL) << 16)
                | ((data[offset + 3] & 0xffL) << 24);
    }

    private static long u64Saturated(byte[] data, int offset) {
        long low = u32(data, offset);
        long high = u32(data, offset + 4);
        if (high > 0x7fff_ffffL) return Long.MAX_VALUE;
        long value = (high << 32) | low;
        return value < 0 ? Long.MAX_VALUE : value;
    }

    private static PtpString ptpString(byte[] data, int offset) {
        if (offset < 0 || offset >= data.length) return new PtpString("", data.length);
        int charactersIncludingNull = data[offset] & 0xff;
        if (charactersIncludingNull == 0) return new PtpString("", offset + 1);
        int byteCount = Math.max(0, (charactersIncludingNull - 1) * 2);
        int available = Math.max(0, Math.min(byteCount, data.length - offset - 1));
        available -= available % 2;
        String value = new String(data, offset + 1, available, StandardCharsets.UTF_16LE);
        int next = Math.min(data.length, offset + 1 + charactersIncludingNull * 2);
        return new PtpString(value, next);
    }

    private static int safeCount(long requested, int availableBytes, int stride) {
        return (int) Math.min(Math.min(requested, Integer.MAX_VALUE), availableBytes / stride);
    }

    private static int saturatedInt(long value) {
        return value > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) value;
    }

    private static long saturatingAdd(long left, long right) {
        if (right > 0 && left > Long.MAX_VALUE - right) return Long.MAX_VALUE;
        return left + right;
    }

    private static final class PtpString {
        final String value;
        final int nextOffset;

        PtpString(String value, int nextOffset) {
            this.value = value;
            this.nextOffset = nextOffset;
        }
    }

    private CameraStorage() {}
}
