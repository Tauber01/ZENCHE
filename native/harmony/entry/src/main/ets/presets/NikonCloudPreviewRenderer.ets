import {
  NikonCloudColorMix,
  NikonCloudPreset
} from './NikonCloudPreview';

const MIXER_ANCHORS: Array<number> = [0, 30, 60, 120, 180, 240, 280, 330];

// Device-side SDR approximation for display-only photo and video monitoring.
// The capture and recording paths consume the original frame before this runs.
export function applyNikonCloudPreviewEffect(
  preset: NikonCloudPreset,
  channels: Array<number>,
  hsl: Array<number>
): void {
  let red: number = clamp(channels[0]);
  let green: number = clamp(channels[1]);
  let blue: number = clamp(channels[2]);
  let luma: number = clamp(red * 0.2126 + green * 0.7152 + blue * 0.0722);
  const contrast: number = 1 + preset.tone.contrast / 120;
  red = (red - 0.5) * contrast + 0.5;
  green = (green - 0.5) * contrast + 0.5;
  blue = (blue - 0.5) * contrast + 0.5;

  const shadows: number = Math.pow(1 - luma, 2);
  const midtones: number = 1 - Math.abs(luma * 2 - 1);
  const highlights: number = Math.pow(luma, 2);
  const tonalShift: number =
    preset.tone.shadows / 400 * shadows +
    preset.tone.highlights / 400 * highlights +
    preset.tone.blacks / 500 * Math.pow(1 - luma, 4) +
    preset.tone.whites / 500 * Math.pow(luma, 4);
  red += tonalShift;
  green += tonalShift;
  blue += tonalShift;

  luma = clamp(red * 0.2126 + green * 0.7152 + blue * 0.0722);
  const saturation: number = Math.max(0, 1 + preset.tone.saturation / 100);
  red = luma + (red - luma) * saturation;
  green = luma + (green - luma) * saturation;
  blue = luma + (blue - luma) * saturation;

  const gradeX: number =
    preset.grading.liftX / 800 * shadows +
    preset.grading.gammaX / 800 * midtones +
    preset.grading.gainX / 800 * highlights;
  const gradeY: number =
    preset.grading.liftY / 800 * shadows +
    preset.grading.gammaY / 800 * midtones +
    preset.grading.gainY / 800 * highlights;
  red += gradeX - gradeY * 0.5;
  green += gradeY - gradeX * 0.5;
  blue -= (gradeX + gradeY) * 0.5;

  channels[0] = preset.toneCurve.length > 1
    ? curveValue(preset.toneCurve, clamp(red)) : clamp(red);
  channels[1] = preset.toneCurve.length > 1
    ? curveValue(preset.toneCurve, clamp(green)) : clamp(green);
  channels[2] = preset.toneCurve.length > 1
    ? curveValue(preset.toneCurve, clamp(blue)) : clamp(blue);
  applyColorMixer(preset, channels, hsl);
}

function applyColorMixer(
  preset: NikonCloudPreset,
  channels: Array<number>,
  hsl: Array<number>
): void {
  if (preset.mixer.length !== 8) return;
  rgbToHsl(channels[0], channels[1], channels[2], hsl);
  let totalWeight: number = 0;
  let hueShift: number = 0;
  let chromaShift: number = 0;
  let brightnessShift: number = 0;
  for (let index: number = 0; index < MIXER_ANCHORS.length; index++) {
    const direct: number = Math.abs(hsl[0] - MIXER_ANCHORS[index]);
    const distance: number = Math.min(direct, 360 - direct);
    const weight: number = Math.max(0, 1 - distance / 60);
    const mix: NikonCloudColorMix = preset.mixer[index];
    totalWeight += weight;
    hueShift += mix.hue * weight;
    chromaShift += mix.chroma * weight;
    brightnessShift += mix.brightness * weight;
  }
  if (totalWeight > 0) {
    hsl[0] = (hsl[0] + hueShift / totalWeight * 0.5) % 360;
    if (hsl[0] < 0) hsl[0] += 360;
    hsl[1] = clamp(hsl[1] * (1 + chromaShift / totalWeight / 64));
    hsl[2] = clamp(hsl[2] + brightnessShift / totalWeight / 255);
  }
  hslToRgb(hsl[0], hsl[1], hsl[2], channels);
}

function curveValue(curve: Array<number>, input: number): number {
  const scaled: number = input * (curve.length - 1);
  const lower: number = Math.min(
    curve.length - 1,
    Math.max(0, Math.floor(scaled))
  );
  const upper: number = Math.min(curve.length - 1, lower + 1);
  const amount: number = scaled - lower;
  return clamp(curve[lower] + (curve[upper] - curve[lower]) * amount);
}

function rgbToHsl(
  red: number,
  green: number,
  blue: number,
  output: Array<number>
): void {
  const maximum: number = Math.max(red, green, blue);
  const minimum: number = Math.min(red, green, blue);
  const delta: number = maximum - minimum;
  const lightness: number = (maximum + minimum) / 2;
  if (delta < 0.000001) {
    output[0] = 0;
    output[1] = 0;
    output[2] = lightness;
    return;
  }
  const saturation: number = delta / Math.max(
    0.000001,
    1 - Math.abs(2 * lightness - 1)
  );
  let hue: number;
  if (maximum === red) hue = 60 * (((green - blue) / delta) % 6);
  else if (maximum === green) hue = 60 * ((blue - red) / delta + 2);
  else hue = 60 * ((red - green) / delta + 4);
  if (hue < 0) hue += 360;
  output[0] = hue;
  output[1] = saturation;
  output[2] = lightness;
}

function hslToRgb(
  hue: number,
  saturation: number,
  lightness: number,
  output: Array<number>
): void {
  const chroma: number = (1 - Math.abs(2 * lightness - 1)) * saturation;
  const sector: number = hue / 60;
  const secondary: number = chroma * (1 - Math.abs(sector % 2 - 1));
  let red: number;
  let green: number;
  let blue: number;
  if (sector < 1) { red = chroma; green = secondary; blue = 0; }
  else if (sector < 2) { red = secondary; green = chroma; blue = 0; }
  else if (sector < 3) { red = 0; green = chroma; blue = secondary; }
  else if (sector < 4) { red = 0; green = secondary; blue = chroma; }
  else if (sector < 5) { red = secondary; green = 0; blue = chroma; }
  else { red = chroma; green = 0; blue = secondary; }
  const match: number = lightness - chroma / 2;
  output[0] = clamp(red + match);
  output[1] = clamp(green + match);
  output[2] = clamp(blue + match);
}

function clamp(value: number): number {
  return Math.max(0, Math.min(1, value));
}
