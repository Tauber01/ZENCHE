#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const [, , sourceArgument, outputArgument, harmonyArgument] = process.argv;

if (!sourceArgument || !outputArgument) {
  console.error(
    "Usage: generate-nikon-cloud-presets.mjs <np3-directory> <output-json> [output-ets]",
  );
  process.exit(64);
}

const sourceDirectory = path.resolve(sourceArgument);
const outputPath = path.resolve(outputArgument);
const harmonyPath = harmonyArgument ? path.resolve(harmonyArgument) : null;

function clamp(value, minimum = -100, maximum = 100) {
  return Math.max(minimum, Math.min(maximum, value));
}

function centeredByte(value, unavailableValues = [0x01, 0xff]) {
  if (value === undefined || unavailableValues.includes(value)) return 0;
  return value - 0x80;
}

function parseChunks(buffer) {
  const chunks = new Map();
  for (let offset = 4; offset + 8 <= buffer.length; ) {
    const rawTag = buffer.readUInt32BE(offset);
    const length = buffer.readUInt32BE(offset + 4);
    const dataOffset = offset + 8;
    if (length < 0 || dataOffset + length > buffer.length) break;
    const tag = rawTag >= 0x100 ? rawTag >>> 8 : 0x10000 + rawTag;
    chunks.set(tag, buffer.subarray(dataOffset, dataOffset + length));
    offset = dataOffset + length;
  }
  return chunks;
}

function embeddedName(chunks, fallback) {
  const data = chunks.get(2);
  if (!data) return fallback;
  const zero = data.indexOf(0);
  const value = data.subarray(0, zero < 0 ? data.length : zero)
    .toString("utf8")
    .trim();
  return value || fallback;
}

function toneCurve(chunks) {
  const data = chunks.get(0x10002);
  // A tag 0x00000002 follows the standard chunks in files that carry Nikon's
  // 256-sample custom tone curve. Its 64-byte header is followed by 256 BE
  // samples.
  if (!data || data.length < 576 || data.subarray(0, 2).toString("ascii") !== "I0") {
    return [];
  }
  const points = [];
  for (let point = 0; point <= 16; point += 1) {
    const sample = Math.round((point / 16) * 255);
    const offset = 64 + sample * 2;
    points.push(Number((data.readUInt16BE(offset) / 32767).toFixed(6)));
  }
  return points;
}

function parsePreset(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.subarray(0, 4).toString("binary") !== "NCP\0") {
    throw new Error(`Not an NCP/NP3 file: ${filePath}`);
  }
  const chunks = parseChunks(buffer);
  const filename = path.basename(filePath);
  const name = embeddedName(chunks, path.basename(filename, path.extname(filename)));
  const control = (tag) => centeredByte(chunks.get(tag)?.[0]);
  const blender = chunks.get(0x1f) ?? Buffer.alloc(24, 0x80);
  const mixer = Array.from({ length: 8 }, (_, index) => ({
    hue: centeredByte(blender[index * 3], []),
    chroma: centeredByte(blender[index * 3 + 1], []),
    brightness: centeredByte(blender[index * 3 + 2], []),
  }));
  const grading = chunks.get(0x20) ?? Buffer.alloc(20, 0x80);
  const gradePoint = (offset) => ({
    x: clamp(Math.round(centeredByte(grading[offset]) * 0.75)),
    y: clamp(Math.round(centeredByte(grading[offset + 1]) * 0.75)),
  });
  const curve = toneCurve(chunks);
  const digest = crypto
    .createHash("sha256")
    .update(filename)
    .update(buffer)
    .digest("hex")
    .slice(0, 12);

  return {
    id: `np3-${digest}`,
    name,
    filename,
    sourceBytes: buffer.length,
    hasCustomToneCurve: curve.length > 0,
    tone: {
      contrast: clamp(control(0x19)),
      highlights: clamp(control(0x1a)),
      shadows: clamp(control(0x1b)),
      whites: clamp(control(0x1c)),
      blacks: clamp(control(0x1d)),
      saturation: clamp(control(0x1e)),
      texture: clamp(control(0x06) * 3),
      clarity: clamp(control(0x07) * 4),
      sharpening: clamp(Math.max(0, control(0x06) * 4), 0, 100),
    },
    grading: {
      // Flexible Color stores four values per tonal region. The app maps the
      // first two chroma axes into its native three-way wheels for preview.
      gain: gradePoint(0),
      gamma: gradePoint(4),
      lift: gradePoint(8),
    },
    mixer,
    toneCurve: curve,
  };
}

const files = fs
  .readdirSync(sourceDirectory, { withFileTypes: true })
  .filter((entry) => entry.isFile() && /\.np3$/i.test(entry.name))
  .map((entry) => path.join(sourceDirectory, entry.name))
  .sort((left, right) =>
    path.basename(left).localeCompare(path.basename(right), "en", {
      sensitivity: "base",
      numeric: true,
    }),
  );

if (files.length === 0) {
  throw new Error(`No NP3 files found in ${sourceDirectory}`);
}

const presets = files.map(parsePreset);
const manifest = {
  schemaVersion: 1,
  renderer: "zenche-nikon-flexible-color-sdr-preview-v1",
  accuracy: "approximate-sdr-preview",
  sourceFormat: "Nikon NP3 Custom Picture Control",
  presetCount: presets.length,
  presets,
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);

function etsString(value) {
  return JSON.stringify(value)
    .replaceAll("\\u2028", "\\u2028")
    .replaceAll("\\u2029", "\\u2029");
}

function etsPreset(preset) {
  const tone = preset.tone;
  const grade = preset.grading;
  const mixer = preset.mixer
    .map((item) => `new NikonCloudColorMix(${item.hue}, ${item.chroma}, ${item.brightness})`)
    .join(", ");
  const curve = preset.toneCurve.join(", ");
  return [
    "  new NikonCloudPreset(",
    `    ${etsString(preset.id)}, ${etsString(preset.name)}, ${etsString(preset.filename)},`,
    `    new NikonCloudTone(${tone.contrast}, ${tone.highlights}, ${tone.shadows}, ${tone.whites}, ${tone.blacks}, ${tone.saturation}, ${tone.texture}, ${tone.clarity}, ${tone.sharpening}),`,
    `    new NikonCloudGrading(${grade.lift.x}, ${grade.lift.y}, ${grade.gamma.x}, ${grade.gamma.y}, ${grade.gain.x}, ${grade.gain.y}),`,
    `    [${mixer}], [${curve}]`,
    "  )",
  ].join("\n");
}

if (harmonyPath) {
  const harmony = `// Generated by scripts/generate-nikon-cloud-presets.mjs.\n` +
`// Nikon's rendering pipeline is proprietary; these values power a clearly\n` +
`// labelled device-side SDR approximation of the source NP3 controls.\n` +
`export class NikonCloudColorMix {\n` +
`  readonly hue: number;\n` +
`  readonly chroma: number;\n` +
`  readonly brightness: number;\n` +
`  constructor(hue: number, chroma: number, brightness: number) {\n` +
`    this.hue = hue; this.chroma = chroma; this.brightness = brightness;\n` +
`  }\n` +
`}\n\n` +
`export class NikonCloudTone {\n` +
`  readonly contrast: number; readonly highlights: number; readonly shadows: number;\n` +
`  readonly whites: number; readonly blacks: number; readonly saturation: number;\n` +
`  readonly texture: number; readonly clarity: number; readonly sharpening: number;\n` +
`  constructor(\n` +
`    contrast: number, highlights: number, shadows: number,\n` +
`    whites: number, blacks: number, saturation: number,\n` +
`    texture: number, clarity: number, sharpening: number\n` +
`  ) {\n` +
`    this.contrast = contrast; this.highlights = highlights; this.shadows = shadows;\n` +
`    this.whites = whites; this.blacks = blacks; this.saturation = saturation;\n` +
`    this.texture = texture; this.clarity = clarity; this.sharpening = sharpening;\n` +
`  }\n` +
`}\n\n` +
`export class NikonCloudGrading {\n` +
`  readonly liftX: number; readonly liftY: number;\n` +
`  readonly gammaX: number; readonly gammaY: number;\n` +
`  readonly gainX: number; readonly gainY: number;\n` +
`  constructor(\n` +
`    liftX: number, liftY: number, gammaX: number, gammaY: number,\n` +
`    gainX: number, gainY: number\n` +
`  ) {\n` +
`    this.liftX = liftX; this.liftY = liftY; this.gammaX = gammaX;\n` +
`    this.gammaY = gammaY; this.gainX = gainX; this.gainY = gainY;\n` +
`  }\n` +
`}\n\n` +
`export class NikonCloudPreset {\n` +
`  readonly id: string; readonly name: string; readonly filename: string;\n` +
`  readonly tone: NikonCloudTone; readonly grading: NikonCloudGrading;\n` +
`  readonly mixer: Array<NikonCloudColorMix>; readonly toneCurve: Array<number>;\n` +
`  constructor(\n` +
`    id: string, name: string, filename: string, tone: NikonCloudTone,\n` +
`    grading: NikonCloudGrading, mixer: Array<NikonCloudColorMix>,\n` +
`    toneCurve: Array<number>\n` +
`  ) {\n` +
`    this.id = id; this.name = name; this.filename = filename; this.tone = tone;\n` +
`    this.grading = grading; this.mixer = mixer; this.toneCurve = toneCurve;\n` +
`  }\n` +
`}\n\n` +
`export const NIKON_CLOUD_PRESETS: Array<NikonCloudPreset> = [\n` +
    `${presets.map(etsPreset).join(",\n")}\n];\n`;
  fs.mkdirSync(path.dirname(harmonyPath), { recursive: true });
  fs.writeFileSync(harmonyPath, harmony);
}

console.log(`Generated ${presets.length} Nikon cloud presets at ${outputPath}`);
if (harmonyPath) console.log(`Generated HarmonyOS catalog at ${harmonyPath}`);
