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

    private static final char[] BARS = "▁▂▃▄▅▆▇█".toCharArray();

    static Result process(
            Bitmap source,
            boolean focusPeaking,
            boolean falseColor) {
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
        int[] red = new int[16];
        int[] green = new int[16];
        int[] blue = new int[16];
        int[] waveformSum = new int[24];
        int[] waveformCount = new int[24];
        int[] hueSum = new int[24];
        int[] hueCount = new int[24];
        working.getPixels(pixels, 0, width, 0, 0, width, height);

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int index = y * width + x;
                int color = pixels[index];
                int r = Color.red(color);
                int g = Color.green(color);
                int b = Color.blue(color);
                int value = (54 * r + 183 * g + 19 * b) >> 8;
                if (luma != null) luma[index] = value;
                red[Math.min(15, r >> 4)]++;
                green[Math.min(15, g >> 4)]++;
                blue[Math.min(15, b >> 4)]++;
                int column = Math.min(23, x * 24 / Math.max(1, width));
                waveformSum[column] += value;
                waveformCount[column]++;
                int maximum = Math.max(r, Math.max(g, b));
                int minimum = Math.min(r, Math.min(g, b));
                int saturation = maximum - minimum;
                if (saturation > 8) {
                    int hue = hueIndex(r, g, b, maximum, saturation);
                    hueSum[hue] += saturation;
                    hueCount[hue]++;
                }
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
        if (focusPeaking || falseColor) {
            output = Bitmap.createBitmap(
                    pixels,
                    width,
                    height,
                    Bitmap.Config.ARGB_8888);
            if (working != source) working.recycle();
        } else {
            output = working;
        }
        int[] waveform = averages(waveformSum, waveformCount);
        int[] vectorscope = averages(hueSum, hueCount);
        return new Result(
                output,
                sparkline(red),
                sparkline(green),
                sparkline(blue),
                sparkline(waveform),
                sparkline(vectorscope),
                (int) Math.round(
                        peakingPixels * 100.0 / Math.max(1, width * height)));
    }

    private static int hueIndex(
            int red,
            int green,
            int blue,
            int maximum,
            int delta) {
        double hue;
        if (maximum == red) {
            hue = (green - blue) / (double) delta;
        } else if (maximum == green) {
            hue = 2 + (blue - red) / (double) delta;
        } else {
            hue = 4 + (red - green) / (double) delta;
        }
        double degrees = (hue * 60) % 360;
        if (degrees < 0) degrees += 360;
        return Math.min(23, (int) (degrees / 15));
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

    private static int[] averages(int[] sums, int[] counts) {
        int[] values = new int[sums.length];
        for (int index = 0; index < sums.length; index++) {
            values[index] = counts[index] == 0 ? 0 : sums[index] / counts[index];
        }
        return values;
    }

    private static String sparkline(int[] values) {
        int maximum = 1;
        for (int value : values) maximum = Math.max(maximum, value);
        StringBuilder result = new StringBuilder(values.length);
        for (int value : values) {
            int index = Math.min(
                    BARS.length - 1,
                    value * (BARS.length - 1) / maximum);
            result.append(BARS[index]);
        }
        return result.toString();
    }
}
