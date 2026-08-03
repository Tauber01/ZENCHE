import { image } from '@kit.ImageKit';
import { NikonCloudPreset } from '../presets/NikonCloudPreview';
import { applyNikonCloudPreviewEffect } from '../presets/NikonCloudPreviewRenderer';

export class ProfessionalMonitorResult {
  readonly pixelMap: image.PixelMap;
  readonly redHistogram: string;
  readonly greenHistogram: string;
  readonly blueHistogram: string;
  readonly waveform: string;
  readonly vectorscope: string;
  readonly peakingCoverage: number;

  constructor(
    pixelMap: image.PixelMap,
    redHistogram: string,
    greenHistogram: string,
    blueHistogram: string,
    waveform: string,
    vectorscope: string,
    peakingCoverage: number
  ) {
    this.pixelMap = pixelMap;
    this.redHistogram = redHistogram;
    this.greenHistogram = greenHistogram;
    this.blueHistogram = blueHistogram;
    this.waveform = waveform;
    this.vectorscope = vectorscope;
    this.peakingCoverage = peakingCoverage;
  }
}

const SCOPE_COLUMNS: number = 64;
const SCOPE_ROWS: number = 48;
const HEX: Array<string> = Array.from('0123456789ABCDEF');

export async function processProfessionalMonitor(
  source: image.PixelMap,
  focusPeaking: boolean,
  falseColorEnabled: boolean,
  nikonCloudPreset?: NikonCloudPreset
): Promise<ProfessionalMonitorResult> {
  const info: image.ImageInfo = await source.getImageInfo();
  const width: number = info.size.width;
  const height: number = info.size.height;
  const buffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
  await source.readPixelsToBuffer(buffer);
  const pixels: Uint8Array = new Uint8Array(buffer);
  const visualProcessing: boolean =
    focusPeaking || falseColorEnabled || nikonCloudPreset !== undefined;
  const sampleStep: number = visualProcessing
    ? 1
    : Math.max(1, Math.floor(Math.max(width, height) / 640));
  const luminance: Uint8Array = new Uint8Array(
    focusPeaking ? width * height : 0
  );
  const red: Array<number> = scopeBuffer();
  const green: Array<number> = scopeBuffer();
  const blue: Array<number> = scopeBuffer();
  const lumaScope: Array<number> = scopeBuffer();
  const cbScope: Array<number> = scopeBuffer();
  const crScope: Array<number> = scopeBuffer();
  const cloudChannels: Array<number> = [0, 0, 0];
  const cloudHsl: Array<number> = [0, 0, 0];

  for (let y: number = 0; y < height; y += sampleStep) {
    for (let x: number = 0; x < width; x += sampleStep) {
      const pixel: number = y * width + x;
      const offset: number = pixel * 4;
      let r: number = pixels[offset];
      let g: number = pixels[offset + 1];
      let b: number = pixels[offset + 2];
      if (nikonCloudPreset !== undefined) {
        cloudChannels[0] = r / 255;
        cloudChannels[1] = g / 255;
        cloudChannels[2] = b / 255;
        applyNikonCloudPreviewEffect(
          nikonCloudPreset,
          cloudChannels,
          cloudHsl
        );
        r = clamp8(Math.round(cloudChannels[0] * 255));
        g = clamp8(Math.round(cloudChannels[1] * 255));
        b = clamp8(Math.round(cloudChannels[2] * 255));
        pixels[offset] = r;
        pixels[offset + 1] = g;
        pixels[offset + 2] = b;
        pixels[offset + 3] = 255;
      }
      const value: number = (54 * r + 183 * g + 19 * b) >> 8;
      if (focusPeaking) {
        luminance[pixel] = value;
      }
      const column: number = Math.min(
        SCOPE_COLUMNS - 1,
        Math.floor(x * SCOPE_COLUMNS / Math.max(1, width))
      );
      accumulate(red, column, r);
      accumulate(green, column, g);
      accumulate(blue, column, b);
      accumulate(lumaScope, column, value);
      const cb: number = clamp8(128 + ((-29 * r - 99 * g + 128 * b) >> 8));
      const cr: number = clamp8(128 + ((128 * r - 116 * g - 12 * b) >> 8));
      accumulate(cbScope, column, cb);
      accumulate(crScope, column, cr);
      if (falseColorEnabled) {
        const color: Array<number> = falseColor(value);
        pixels[offset] = color[0];
        pixels[offset + 1] = color[1];
        pixels[offset + 2] = color[2];
      }
    }
  }

  let peakingPixels: number = 0;
  if (focusPeaking && width > 2 && height > 2) {
    for (let y: number = 1; y < height - 1; y++) {
      for (let x: number = 1; x < width - 1; x++) {
        const pixel: number = y * width + x;
        const horizontal: number = Math.abs(
          luminance[pixel - 1] - luminance[pixel + 1]
        );
        const vertical: number = Math.abs(
          luminance[pixel - width] - luminance[pixel + width]
        );
        if (horizontal + vertical > 72) {
          const offset: number = pixel * 4;
          pixels[offset] = 255;
          pixels[offset + 1] = 38;
          pixels[offset + 2] = 205;
          pixels[offset + 3] = 255;
          peakingPixels++;
        }
      }
    }
  }

  const output: image.PixelMap = visualProcessing
    ? await image.createPixelMap(
      buffer,
      {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        alphaType: image.AlphaType.OPAQUE,
        size: { width: width, height: height }
      }
    )
    : source;
  return new ProfessionalMonitorResult(
    output,
    densityMap(red),
    densityMap(green),
    densityMap(blue),
    densityMap(lumaScope),
    `${densityMap(cbScope)}|${densityMap(crScope)}`,
    Math.round(peakingPixels * 100 / Math.max(1, width * height))
  );
}

function scopeBuffer(): Array<number> {
  return new Array<number>(SCOPE_COLUMNS * SCOPE_ROWS).fill(0);
}

function accumulate(buffer: Array<number>, column: number, value: number): void {
  const row: number = SCOPE_ROWS - 1
    - Math.floor(clamp8(value) * (SCOPE_ROWS - 1) / 255);
  buffer[row * SCOPE_COLUMNS + column]++;
}

function clamp8(value: number): number {
  return Math.min(255, Math.max(0, value));
}

function falseColor(luma: number): Array<number> {
  if (luma < 32) return [18, 24, 150];
  if (luma < 64) return [0, 150, 255];
  if (luma < 112) return [32, 205, 120];
  if (luma < 160) return [126, 126, 126];
  if (luma < 208) return [255, 205, 20];
  if (luma < 240) return [255, 92, 32];
  return [255, 32, 56];
}

function densityMap(values: Array<number>): string {
  const maximum: number = Math.max(1, ...values);
  const divisor: number = Math.log1p(maximum);
  const payload: string = values.map((value: number): string => {
    const level: number = Math.round(Math.log1p(value) / divisor * 15);
    return HEX[Math.min(15, Math.max(0, level))];
  }).join('');
  return `S${SCOPE_COLUMNS}x${SCOPE_ROWS}:${payload}`;
}
