package com.tauber.nikonlink;

import android.graphics.Bitmap;
import android.graphics.Color;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

final class CubeLut {
    private final String title;
    private final int size;
    private final float[] values;
    private final float[] domainMin;
    private final float[] domainMax;

    private CubeLut(
            String title,
            int size,
            float[] values,
            float[] domainMin,
            float[] domainMax) {
        this.title = title;
        this.size = size;
        this.values = values;
        this.domainMin = domainMin;
        this.domainMax = domainMax;
    }

    static CubeLut parse(InputStream stream, String fallbackName) throws Exception {
        if (stream == null) throw new Exception("无法读取这个 LUT 文件。");
        String title = fallbackName == null ? "自定义 LUT" : fallbackName;
        int size = 0;
        float[] domainMin = new float[]{0f, 0f, 0f};
        float[] domainMax = new float[]{1f, 1f, 1f};
        List<Float> samples = new ArrayList<>();

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String rawLine;
            while ((rawLine = reader.readLine()) != null) {
                String line = rawLine.split("#", 2)[0].trim();
                if (line.isEmpty()) continue;
                String[] fields = line.split("\\s+");
                String command = fields[0].toUpperCase(Locale.ROOT);
                switch (command) {
                    case "TITLE":
                        title = line.substring(fields[0].length()).trim().replace("\"", "");
                        break;
                    case "LUT_1D_SIZE":
                        throw new Exception("当前只支持 3D .cube LUT。");
                    case "LUT_3D_SIZE":
                        if (fields.length != 2) throw new Exception("LUT_3D_SIZE 设置无效。");
                        size = Integer.parseInt(fields[1]);
                        if (size < 2 || size > 64) {
                            throw new Exception("LUT_3D_SIZE 必须在 2 到 64 之间。");
                        }
                        break;
                    case "DOMAIN_MIN":
                        domainMin = parseVector(fields);
                        break;
                    case "DOMAIN_MAX":
                        domainMax = parseVector(fields);
                        break;
                    default:
                        if (fields.length != 3) continue;
                        samples.add(Float.parseFloat(fields[0]));
                        samples.add(Float.parseFloat(fields[1]));
                        samples.add(Float.parseFloat(fields[2]));
                        break;
                }
            }
        }

        if (size == 0) throw new Exception("文件缺少有效的 LUT_3D_SIZE。");
        int expected = size * size * size * 3;
        if (samples.size() != expected) {
            throw new Exception(
                    "LUT 数据不完整：需要 " + (expected / 3)
                            + " 组颜色，实际读取到 " + (samples.size() / 3) + " 组。");
        }
        for (Float sample : samples) {
            if (sample == null || !Float.isFinite(sample)) {
                throw new Exception("LUT 包含无法使用的颜色数值。");
            }
        }
        for (int channel = 0; channel < 3; channel++) {
            if (!Float.isFinite(domainMin[channel])
                    || !Float.isFinite(domainMax[channel])
                    || domainMax[channel] <= domainMin[channel]) {
                throw new Exception("LUT 的 DOMAIN_MIN / DOMAIN_MAX 设置无效。");
            }
        }
        float[] values = new float[expected];
        for (int index = 0; index < expected; index++) values[index] = samples.get(index);
        return new CubeLut(title.isEmpty() ? fallbackName : title, size, values, domainMin, domainMax);
    }

    String getTitle() {
        return title;
    }

    Bitmap apply(Bitmap source) {
        int sourceWidth = source.getWidth();
        int sourceHeight = source.getHeight();
        double scale = Math.min(1.0, 720.0 / Math.max(sourceWidth, sourceHeight));
        int width = Math.max(1, (int) Math.round(sourceWidth * scale));
        int height = Math.max(1, (int) Math.round(sourceHeight * scale));
        Bitmap working = scale < 1.0
                ? Bitmap.createScaledBitmap(source, width, height, true)
                : source;
        int[] pixels = new int[width * height];
        working.getPixels(pixels, 0, width, 0, 0, width, height);

        int maximum = size - 1;
        for (int index = 0; index < pixels.length; index++) {
            int color = pixels[index];
            float red = normalize(Color.red(color) / 255f, 0);
            float green = normalize(Color.green(color) / 255f, 1);
            float blue = normalize(Color.blue(color) / 255f, 2);
            int redIndex = Math.round(red * maximum);
            int greenIndex = Math.round(green * maximum);
            int blueIndex = Math.round(blue * maximum);
            int cubeIndex = ((blueIndex * size + greenIndex) * size + redIndex) * 3;
            pixels[index] = Color.argb(
                    Color.alpha(color),
                    channel(values[cubeIndex]),
                    channel(values[cubeIndex + 1]),
                    channel(values[cubeIndex + 2]));
        }

        Bitmap output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        output.setPixels(pixels, 0, width, 0, 0, width, height);
        if (working != source) working.recycle();
        return output;
    }

    private float normalize(float value, int channel) {
        float normalized = (value - domainMin[channel]) / (domainMax[channel] - domainMin[channel]);
        return Math.max(0f, Math.min(1f, normalized));
    }

    private static int channel(float value) {
        return Math.max(0, Math.min(255, Math.round(value * 255f)));
    }

    private static float[] parseVector(String[] fields) throws Exception {
        if (fields.length != 4) throw new Exception("LUT 的颜色域设置无效。");
        return new float[]{
                Float.parseFloat(fields[1]),
                Float.parseFloat(fields[2]),
                Float.parseFloat(fields[3])
        };
    }
}
