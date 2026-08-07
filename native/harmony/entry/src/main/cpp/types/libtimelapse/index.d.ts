/**
 * E6 延时合成 native 编码模块（libtimelapse.so）。
 * NAPI 契约：createEncoder / feedFrame / finishEncoder / destroyEncoder。
 */
export const createEncoder: (
  width: number,
  height: number,
  fps: number,
  bitRate: number,
  outputPath: string
) => number;
export const feedFrame: (handle: number, nv12: Uint8Array, ptsUs: number) => number;
export const finishEncoder: (handle: number) => number;
export const destroyEncoder: (handle: number) => void;
