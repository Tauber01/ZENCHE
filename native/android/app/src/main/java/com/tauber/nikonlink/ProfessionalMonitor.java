package com.tauber.nikonlink;

import android.graphics.Bitmap;
import android.graphics.Color;

final class ProfessionalMonitor {
    static final class Result {
        final Bitmap image;
        final String redHistogram;
        final String greenHistogram;
        final String blueHistogram;
        final String waveform;
        final String vectorscope;
        final int peakingCoverage;

        Result(
                Bitmap image,
                String redHistogram,
                String greenHistogram,
                String blueHistogram,
                String waveform,
                String vectorscope,
                int peakingCoverage) {
            this.image = image;
            this.redHistogram = redHistogram;
            this.greenHistogram = greenHistogram;
            this.blueHistogram = blueHistogram;
            this.waveform = waveform;
            this.vectorscope = vectorscope;
            this.peakingCoverage = peakingCoverage;
        }
    }

    private static final int SCOPE_COLUMNS = 64;
    private static final int SCOPE_ROWS = 48;
    private static final char[] HEX = "0123456789ABCDEF".toCharArray();

    static Result process(
            Bitmap source,
            boolean focusPeaking,
            boolean falseColor,
            NikonCloudPreview.Preset nikonCloudPreset) {
        int sourceWidth = source.getWidth();
        int sourceHeight = source.getHeight();
        double scale = Math.min(1.0, 640.0 / Math.max(sourceWidth, sourceHeight));
        int width = Math.max(1, (int) Math.round(sourceWidth * scale));
        int height = Math.max(1, (int) Math.round(sourceHeight * scale));
        Bitmap working = scale < 1
                ? Bitmap.createScaledBitmap(source, width, height, true)
                : source;
        int[] pixels = new int[width * height];
        int[] luma = focusPeaking ? new int[width * height] : null;
        int[] red = scopeBuffer();
        int[] green = scopeBuffer();
        int[] blue = scopeBuffer();
        int[] lumaScope = scopeBuffer();
        int[] cbScope = scopeBuffer();
        int[] crScope = scopeBuffer();
        double[] cloudChannels = nikonCloudPreset == null
                ? null : new double[3];
        double[] cloudHsl = nikonCloudPreset == null
                ? null : new double[3];
        working.getPixels(pixels, 0, width, 0, 0, width, height);

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int index = y * width + x;
                int color = pixels[index];
                int r = Color.red(color);
                int g = Color.green(color);
                int b = Color.blue(color);
                if (nikonCloudPreset != null) {
                    cloudChannels[0] = r / 255.0;
                    cloudChannels[1] = g / 255.0;
                    cloudChannels[2] = b / 255.0;
                    nikonCloudPreset.applyPreviewEffect(
                            cloudChannels,
                            cloudHsl);
                    r = clamp8((int) Math.round(cloudChannels[0] * 255));
                    g = clamp8((int) Math.round(cloudChannels[1] * 255));
                    b = clamp8((int) Math.round(cloudChannels[2] * 255));
                    pixels[index] = Color.rgb(r, g, b);
                }
                int value = (54 * r + 183 * g + 19 * b) >> 8;
                if (luma != null) luma[index] = value;
                int column = Math.min(SCOPE_COLUMNS - 1, x * SCOPE_COLUMNS / Math.max(1, width));
                accumulate(red, column, r);
                accumulate(green, column, g);
                accumulate(blue, column, b);
                accumulate(lumaScope, column, value);
                int cb = clamp8(128 + ((-29 * r - 99 * g + 128 * b) >> 8));
                int cr = clamp8(128 + ((128 * r - 116 * g - 12 * b) >> 8));
                accumulate(cbScope, column, cb);
                accumulate(crScope, column, cr);
                if (falseColor) {
                    pixels[index] = falseColor(value);
                }
            }
        }

        int peakingPixels = 0;
        if (focusPeaking && width > 2 && height > 2) {
            for (int y = 1; y < height - 1; y++) {
                for (int x = 1; x < width - 1; x++) {
                    int index = y * width + x;
                    int horizontal = Math.abs(luma[index - 1] - luma[index + 1]);
                    int vertical = Math.abs(
                            luma[index - width] - luma[index + width]);
                    if (horizontal + vertical > 72) {
                        pixels[index] = Color.rgb(255, 38, 205);
                        peakingPixels++;
                    }
                }
            }
        }
        Bitmap output;
        if (focusPeaking || falseColor || nikonCloudPreset != null) {
            output = Bitmap.createBitmap(
                    pixels,
                    width,
                    height,
                    Bitmap.Config.ARGB_8888);
            if (working != source) working.recycle();
        } else {
            output = working;
        }
        return new Result(
                output,
                densityMap(red),
                densityMap(green),
                densityMap(blue),
                densityMap(lumaScope),
                densityMap(cbScope) + "|" + densityMap(crScope),
                (int) Math.round(
                        peakingPixels * 100.0 / Math.max(1, width * height)));
    }

    private static int[] scopeBuffer() {
        return new int[SCOPE_COLUMNS * SCOPE_ROWS];
    }

    private static void accumulate(int[] buffer, int column, int value) {
        int row = SCOPE_ROWS - 1 - clamp8(value) * (SCOPE_ROWS - 1) / 255;
        buffer[row * SCOPE_COLUMNS + column]++;
    }

    private static int clamp8(int value) {
        return Math.min(255, Math.max(0, value));
    }

    private static int falseColor(int luma) {
        if (luma < 32) return Color.rgb(18, 24, 150);
        if (luma < 64) return Color.rgb(0, 150, 255);
        if (luma < 112) return Color.rgb(32, 205, 120);
        if (luma < 160) return Color.rgb(126, 126, 126);
        if (luma < 208) return Color.rgb(255, 205, 20);
        if (luma < 240) return Color.rgb(255, 92, 32);
        return Color.rgb(255, 32, 56);
    }

    private static String densityMap(int[] values) {
        int maximum = 1;
        for (int value : values) maximum = Math.max(maximum, value);
        double divisor = Math.log1p(maximum);
        StringBuilder result = new StringBuilder(8 + values.length);
        result.append('S').append(SCOPE_COLUMNS).append('x').append(SCOPE_ROWS).append(':');
        for (int value : values) {
            int level = (int) Math.round(Math.log1p(value) / divisor * 15);
            result.append(HEX[Math.min(15, Math.max(0, level))]);
        }
        return result.toString();
    }
}
