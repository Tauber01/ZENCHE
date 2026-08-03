package com.tauber.nikonlink;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class NikonCloudPreview {
    static final class Tone {
        final int contrast;
        final int highlights;
        final int shadows;
        final int whites;
        final int blacks;
        final int saturation;
        final int texture;
        final int clarity;
        final int sharpening;

        Tone(JSONObject json) {
            contrast = json.optInt("contrast");
            highlights = json.optInt("highlights");
            shadows = json.optInt("shadows");
            whites = json.optInt("whites");
            blacks = json.optInt("blacks");
            saturation = json.optInt("saturation");
            texture = json.optInt("texture");
            clarity = json.optInt("clarity");
            sharpening = json.optInt("sharpening");
        }
    }

    static final class GradePoint {
        final int x;
        final int y;

        GradePoint(JSONObject json) {
            x = json.optInt("x");
            y = json.optInt("y");
        }
    }

    static final class Grading {
        final GradePoint lift;
        final GradePoint gamma;
        final GradePoint gain;

        Grading(JSONObject json) {
            lift = new GradePoint(json.optJSONObject("lift"));
            gamma = new GradePoint(json.optJSONObject("gamma"));
            gain = new GradePoint(json.optJSONObject("gain"));
        }
    }

    static final class ColorMix {
        final int hue;
        final int chroma;
        final int brightness;

        ColorMix(JSONObject json) {
            hue = json.optInt("hue");
            chroma = json.optInt("chroma");
            brightness = json.optInt("brightness");
        }
    }

    static final class Preset {
        private static final double[] MIXER_ANCHORS =
                {0, 30, 60, 120, 180, 240, 280, 330};
        final String id;
        final String name;
        final String filename;
        final boolean hasCustomToneCurve;
        final Tone tone;
        final Grading grading;
        final List<ColorMix> mixer;
        final List<Double> toneCurve;

        Preset(JSONObject json) {
            id = json.optString("id");
            name = json.optString("name");
            filename = json.optString("filename");
            hasCustomToneCurve = json.optBoolean("hasCustomToneCurve");
            tone = new Tone(json.optJSONObject("tone"));
            grading = new Grading(json.optJSONObject("grading"));
            ArrayList<ColorMix> colorMixer = new ArrayList<>();
            JSONArray mixerArray = json.optJSONArray("mixer");
            if (mixerArray != null) {
                for (int index = 0; index < mixerArray.length(); index++) {
                    JSONObject item = mixerArray.optJSONObject(index);
                    if (item != null) colorMixer.add(new ColorMix(item));
                }
            }
            mixer = Collections.unmodifiableList(colorMixer);
            ArrayList<Double> curve = new ArrayList<>();
            JSONArray curveArray = json.optJSONArray("toneCurve");
            if (curveArray != null) {
                for (int index = 0; index < curveArray.length(); index++) {
                    curve.add(curveArray.optDouble(index));
                }
            }
            toneCurve = Collections.unmodifiableList(curve);
        }

        void applyColorMixer(double[] channels, double[] hsl) {
            if (channels.length < 3 || hsl.length < 3 || mixer.size() != 8) {
                return;
            }
            rgbToHsl(
                    clamp(channels[0]),
                    clamp(channels[1]),
                    clamp(channels[2]),
                    hsl);
            double totalWeight = 0;
            double hueShift = 0;
            double chromaShift = 0;
            double brightnessShift = 0;
            for (int index = 0; index < MIXER_ANCHORS.length; index++) {
                double direct = Math.abs(hsl[0] - MIXER_ANCHORS[index]);
                double distance = Math.min(direct, 360 - direct);
                double weight = Math.max(0, 1 - distance / 60);
                ColorMix item = mixer.get(index);
                totalWeight += weight;
                hueShift += item.hue * weight;
                chromaShift += item.chroma * weight;
                brightnessShift += item.brightness * weight;
            }
            if (totalWeight > 0) {
                hsl[0] = (hsl[0] + hueShift / totalWeight * .5) % 360;
                if (hsl[0] < 0) hsl[0] += 360;
                hsl[1] = clamp(
                        hsl[1] * (1 + chromaShift / totalWeight / 64));
                hsl[2] = clamp(
                        hsl[2] + brightnessShift / totalWeight / 255);
            }
            hslToRgb(hsl[0], hsl[1], hsl[2], channels);
        }

        void applyPreviewEffect(double[] channels, double[] hsl) {
            if (channels.length < 3 || hsl.length < 3) return;
            double red = clamp(channels[0]);
            double green = clamp(channels[1]);
            double blue = clamp(channels[2]);
            double luma = clamp(
                    red * .2126 + green * .7152 + blue * .0722);
            double contrast = 1 + tone.contrast / 120.0;
            red = (red - .5) * contrast + .5;
            green = (green - .5) * contrast + .5;
            blue = (blue - .5) * contrast + .5;

            double shadows = Math.pow(1 - luma, 2);
            double midtones = 1 - Math.abs(luma * 2 - 1);
            double highlights = Math.pow(luma, 2);
            double tonalShift = tone.shadows / 400.0 * shadows
                    + tone.highlights / 400.0 * highlights
                    + tone.blacks / 500.0 * Math.pow(1 - luma, 4)
                    + tone.whites / 500.0 * Math.pow(luma, 4);
            red += tonalShift;
            green += tonalShift;
            blue += tonalShift;

            luma = clamp(red * .2126 + green * .7152 + blue * .0722);
            double saturation = Math.max(0, 1 + tone.saturation / 100.0);
            red = luma + (red - luma) * saturation;
            green = luma + (green - luma) * saturation;
            blue = luma + (blue - luma) * saturation;

            double gradeX = grading.lift.x / 800.0 * shadows
                    + grading.gamma.x / 800.0 * midtones
                    + grading.gain.x / 800.0 * highlights;
            double gradeY = grading.lift.y / 800.0 * shadows
                    + grading.gamma.y / 800.0 * midtones
                    + grading.gain.y / 800.0 * highlights;
            red += gradeX - gradeY * .5;
            green += gradeY - gradeX * .5;
            blue -= (gradeX + gradeY) * .5;

            channels[0] = toneCurve.size() > 1
                    ? curveValue(clamp(red)) : clamp(red);
            channels[1] = toneCurve.size() > 1
                    ? curveValue(clamp(green)) : clamp(green);
            channels[2] = toneCurve.size() > 1
                    ? curveValue(clamp(blue)) : clamp(blue);
            applyColorMixer(channels, hsl);
        }

        private double curveValue(double input) {
            double scaled = input * (toneCurve.size() - 1);
            int lower = Math.min(
                    toneCurve.size() - 1,
                    Math.max(0, (int) Math.floor(scaled)));
            int upper = Math.min(toneCurve.size() - 1, lower + 1);
            double amount = scaled - lower;
            return clamp(toneCurve.get(lower)
                    + (toneCurve.get(upper) - toneCurve.get(lower)) * amount);
        }
    }

    private NikonCloudPreview() {
    }

    static List<Preset> load(Context context) {
        ArrayList<Preset> result = new ArrayList<>();
        try (InputStream stream = context.getAssets().open(
                "nikon-cloud-presets.json");
             BufferedReader reader = new BufferedReader(new InputStreamReader(
                     stream,
                     StandardCharsets.UTF_8))) {
            StringBuilder text = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) text.append(line);
            JSONArray presets = new JSONObject(text.toString())
                    .optJSONArray("presets");
            if (presets != null) {
                for (int index = 0; index < presets.length(); index++) {
                    JSONObject item = presets.optJSONObject(index);
                    if (item != null) result.add(new Preset(item));
                }
            }
        } catch (Exception ignored) {
            return Collections.emptyList();
        }
        return Collections.unmodifiableList(result);
    }

    private static void rgbToHsl(
            double red,
            double green,
            double blue,
            double[] output) {
        double maximum = Math.max(red, Math.max(green, blue));
        double minimum = Math.min(red, Math.min(green, blue));
        double delta = maximum - minimum;
        double lightness = (maximum + minimum) / 2;
        if (delta < .000001) {
            output[0] = 0;
            output[1] = 0;
            output[2] = lightness;
            return;
        }
        double saturation = delta / Math.max(
                .000001,
                1 - Math.abs(2 * lightness - 1));
        double hue;
        if (maximum == red) {
            hue = 60 * (((green - blue) / delta) % 6);
        } else if (maximum == green) {
            hue = 60 * ((blue - red) / delta + 2);
        } else {
            hue = 60 * ((red - green) / delta + 4);
        }
        if (hue < 0) hue += 360;
        output[0] = hue;
        output[1] = saturation;
        output[2] = lightness;
    }

    private static void hslToRgb(
            double hue,
            double saturation,
            double lightness,
            double[] output) {
        double chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
        double sector = hue / 60;
        double secondary = chroma * (1 - Math.abs(sector % 2 - 1));
        double red;
        double green;
        double blue;
        if (sector < 1) {
            red = chroma; green = secondary; blue = 0;
        } else if (sector < 2) {
            red = secondary; green = chroma; blue = 0;
        } else if (sector < 3) {
            red = 0; green = chroma; blue = secondary;
        } else if (sector < 4) {
            red = 0; green = secondary; blue = chroma;
        } else if (sector < 5) {
            red = secondary; green = 0; blue = chroma;
        } else {
            red = chroma; green = 0; blue = secondary;
        }
        double match = lightness - chroma / 2;
        output[0] = clamp(red + match);
        output[1] = clamp(green + match);
        output[2] = clamp(blue + match);
    }

    private static double clamp(double value) {
        return Math.max(0, Math.min(1, value));
    }
}
