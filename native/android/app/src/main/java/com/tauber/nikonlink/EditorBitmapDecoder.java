package com.tauber.nikonlink;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;

import java.io.BufferedInputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

/** Decodes editor sources with their JPEG EXIF orientation normalized. */
final class EditorBitmapDecoder {
    private static final int JPEG_START = 0xffd8;
    private static final int JPEG_END = 0xd9;
    private static final int JPEG_SCAN = 0xda;
    private static final int APP1 = 0xe1;
    private static final int ORIENTATION_TAG = 0x0112;

    private EditorBitmapDecoder() {}

    static Bitmap decode(File file, int maximumDimension) {
        if (file == null || maximumDimension <= 0) return null;
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null;
        int sampleSize = 1;
        while (Math.max(
                bounds.outWidth / sampleSize,
                bounds.outHeight / sampleSize) > maximumDimension) {
            sampleSize *= 2;
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sampleSize;
        options.inPreferredConfig = Bitmap.Config.ARGB_8888;
        Bitmap decoded = BitmapFactory.decodeFile(file.getAbsolutePath(), options);
        if (decoded == null) return null;
        int orientation = jpegExifOrientation(file);
        if (orientation == 1) return decoded;
        Matrix matrix = orientationMatrix(orientation);
        try {
            Bitmap normalized = Bitmap.createBitmap(
                    decoded,
                    0,
                    0,
                    decoded.getWidth(),
                    decoded.getHeight(),
                    matrix,
                    true);
            if (normalized != decoded) decoded.recycle();
            return normalized;
        } catch (RuntimeException error) {
            decoded.recycle();
            return null;
        }
    }

    private static Matrix orientationMatrix(int orientation) {
        Matrix matrix = new Matrix();
        switch (orientation) {
            case 2: // mirror horizontally
                matrix.setValues(new float[]{-1, 0, 0, 0, 1, 0, 0, 0, 1});
                break;
            case 3: // rotate 180
                matrix.setValues(new float[]{-1, 0, 0, 0, -1, 0, 0, 0, 1});
                break;
            case 4: // mirror vertically
                matrix.setValues(new float[]{1, 0, 0, 0, -1, 0, 0, 0, 1});
                break;
            case 5: // transpose
                matrix.setValues(new float[]{0, 1, 0, 1, 0, 0, 0, 0, 1});
                break;
            case 6: // rotate 90 clockwise
                matrix.setValues(new float[]{0, -1, 0, 1, 0, 0, 0, 0, 1});
                break;
            case 7: // transverse
                matrix.setValues(new float[]{0, -1, 0, -1, 0, 0, 0, 0, 1});
                break;
            case 8: // rotate 270 clockwise
                matrix.setValues(new float[]{0, 1, 0, -1, 0, 0, 0, 0, 1});
                break;
            default:
                break;
        }
        return matrix;
    }

    private static int jpegExifOrientation(File file) {
        try (DataInputStream input = new DataInputStream(
                new BufferedInputStream(new FileInputStream(file)))) {
            if (input.readUnsignedShort() != JPEG_START) return 1;
            while (true) {
                int prefix;
                do {
                    prefix = input.readUnsignedByte();
                } while (prefix != 0xff);
                int marker;
                do {
                    marker = input.readUnsignedByte();
                } while (marker == 0xff);
                if (marker == JPEG_END || marker == JPEG_SCAN) return 1;
                int length = input.readUnsignedShort();
                if (length < 2) return 1;
                int payloadLength = length - 2;
                if (marker != APP1) {
                    skipFully(input, payloadLength);
                    continue;
                }
                byte[] payload = new byte[payloadLength];
                input.readFully(payload);
                int orientation = parseExifOrientation(payload);
                if (orientation >= 1 && orientation <= 8) return orientation;
            }
        } catch (IOException | RuntimeException ignored) {
            return 0;
        }
    }

    private static int parseExifOrientation(byte[] payload) {
        if (payload.length < 14
                || payload[0] != 'E'
                || payload[1] != 'x'
                || payload[2] != 'i'
                || payload[3] != 'f'
                || payload[4] != 0
                || payload[5] != 0) {
            return 1;
        }
        int tiff = 6;
        boolean littleEndian;
        if (payload[tiff] == 'I' && payload[tiff + 1] == 'I') {
            littleEndian = true;
        } else if (payload[tiff] == 'M' && payload[tiff + 1] == 'M') {
            littleEndian = false;
        } else {
            return 0;
        }
        if (unsignedShort(payload, tiff + 2, littleEndian) != 42) return 0;
        long ifdOffset = unsignedInt(payload, tiff + 4, littleEndian);
        long ifdLong = tiff + ifdOffset;
        if (ifdLong < tiff || ifdLong + 2 > payload.length) return 0;
        int ifd = (int) ifdLong;
        int entries = unsignedShort(payload, ifd, littleEndian);
        for (int index = 0; index < entries; index++) {
            long entryLong = (long) ifd + 2L + index * 12L;
            if (entryLong < 0 || entryLong + 12 > payload.length) return 0;
            int entry = (int) entryLong;
            if (unsignedShort(payload, entry, littleEndian) != ORIENTATION_TAG) {
                continue;
            }
            int type = unsignedShort(payload, entry + 2, littleEndian);
            long count = unsignedInt(payload, entry + 4, littleEndian);
            if (type != 3 || count != 1) return 0;
            int orientation = unsignedShort(payload, entry + 8, littleEndian);
            return orientation >= 1 && orientation <= 8 ? orientation : 0;
        }
        return 0;
    }

    private static int unsignedShort(byte[] data, int offset, boolean littleEndian) {
        if (offset < 0 || offset + 2 > data.length) return -1;
        int first = data[offset] & 0xff;
        int second = data[offset + 1] & 0xff;
        return littleEndian ? first | second << 8 : first << 8 | second;
    }

    private static long unsignedInt(byte[] data, int offset, boolean littleEndian) {
        if (offset < 0 || offset + 4 > data.length) return -1;
        long b0 = data[offset] & 0xffL;
        long b1 = data[offset + 1] & 0xffL;
        long b2 = data[offset + 2] & 0xffL;
        long b3 = data[offset + 3] & 0xffL;
        return littleEndian
                ? b0 | b1 << 8 | b2 << 16 | b3 << 24
                : b0 << 24 | b1 << 16 | b2 << 8 | b3;
    }

    private static void skipFully(DataInputStream input, int count) throws IOException {
        int remaining = count;
        while (remaining > 0) {
            int skipped = input.skipBytes(remaining);
            if (skipped <= 0) {
                input.readUnsignedByte();
                skipped = 1;
            }
            remaining -= skipped;
        }
    }
}
