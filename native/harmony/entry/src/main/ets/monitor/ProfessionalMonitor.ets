import { image } from '@kit.ImageKit';

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

const BARS: Array<string> = Array.from('▁▂▃▄▅▆▇█');

export async function processProfessionalMonitor(
  source: image.PixelMap,
  focusPeaking: boolean,
  falseColorEnabled: boolean
): Promise<ProfessionalMonitorResult> {
  const info: image.ImageInfo = await source.getImageInfo();
  const width: number = info.size.width;
  const height: number = info.size.height;
  const buffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
  await source.readPixelsToBuffer(buffer);
  const pixels: Uint8Array = new Uint8Array(buffer);
  const visualProcessing: boolean = focusPeaking || falseColorEnabled;
  const sampleStep: number = visualProcessing
    ? 1
    : Math.max(1, Math.floor(Math.max(width, height) / 640));
  const luminance: Uint8Array = new Uint8Array(
    focusPeaking ? width * height : 0
  );
  const red: Array<number> = new Array<number>(16).fill(0);
  const green: Array<number> = new Array<number>(16).fill(0);
  const blue: Array<number> = new Array<number>(16).fill(0);
  const waveformSum: Array<number> = new Array<number>(24).fill(0);
  const waveformCount: Array<number> = new Array<number>(24).fill(0);
  const hueSum: Array<number> = new Array<number>(24).fill(0);
  const hueCount: Array<number> = new Array<number>(24).fill(0);

  for (let y: number = 0; y < height; y += sampleStep) {
    for (let x: number = 0; x < width; x += sampleStep) {
      const pixel: number = y * width + x;
      const offset: number = pixel * 4;
      const r: number = pixels[offset];
      const g: number = pixels[offset + 1];
      const b: number = pixels[offset + 2];
      const value: number = (54 * r + 183 * g + 19 * b) >> 8;
      if (focusPeaking) {
        luminance[pixel] = value;
      }
      red[Math.min(15, r >> 4)]++;
      green[Math.min(15, g >> 4)]++;
      blue[Math.min(15, b >> 4)]++;
      const column: number = Math.min(
        23,
        Math.floor(x * 24 / Math.max(1, width))
      );
      waveformSum[column] += value;
      waveformCount[column]++;
      const maximum: number = Math.max(r, Math.max(g, b));
      const minimum: number = Math.min(r, Math.min(g, b));
      const saturation: number = maximum - minimum;
      if (saturation > 8) {
        const hue: number = hueIndex(r, g, b, maximum, saturation);
        hueSum[hue] += saturation;
        hueCount[hue]++;
      }
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
    sparkline(red),
    sparkline(green),
    sparkline(blue),
    sparkline(averages(waveformSum, waveformCount)),
    sparkline(averages(hueSum, hueCount)),
    Math.round(peakingPixels * 100 / Math.max(1, width * height))
  );
}

function hueIndex(
  red: number,
  green: number,
  blue: number,
  maximum: number,
  delta: number
): number {
  let hue: number;
  if (maximum === red) {
    hue = (green - blue) / delta;
  } else if (maximum === green) {
    hue = 2 + (blue - red) / delta;
  } else {
    hue = 4 + (red - green) / delta;
  }
  let degrees: number = (hue * 60) % 360;
  if (degrees < 0) {
    degrees += 360;
  }
  return Math.min(23, Math.floor(degrees / 15));
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

function averages(
  sums: Array<number>,
  counts: Array<number>
): Array<number> {
  return sums.map((sum: number, index: number): number =>
    counts[index] === 0 ? 0 : Math.floor(sum / counts[index])
  );
}

function sparkline(values: Array<number>): string {
  const maximum: number = Math.max(1, ...values);
  return values.map((value: number): string => {
    const index: number = Math.min(
      BARS.length - 1,
      Math.floor(value * (BARS.length - 1) / maximum)
    );
    return BARS[index];
  }).join('');
}
