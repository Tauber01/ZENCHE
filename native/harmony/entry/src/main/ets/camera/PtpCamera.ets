import { BusinessError, usbManager } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CameraProfile,
  SUPPORTED_VENDOR_IDS,
  profileForProduct,
  supportedCameraSummary
} from './CameraProfiles';
import {
  CameraStorageItem,
  CameraStorageSnapshot,
  CameraStorageVolume,
  isObjectAssociation,
  parseObjectInfo,
  parseStorageIds,
  parseStorageInfo
} from '../storage/CameraStorage';

const CONTAINER_COMMAND: number = 1;
const CONTAINER_DATA: number = 2;
const CONTAINER_RESPONSE: number = 3;
const RESPONSE_OK: number = 0x2001;
const RESPONSE_SESSION_ALREADY_OPEN: number = 0x201e;
const OPEN_SESSION: number = 0x1002;
const CLOSE_SESSION: number = 0x1003;
const GET_STORAGE_IDS: number = 0x1004;
const GET_STORAGE_INFO: number = 0x1005;
const GET_OBJECT_HANDLES: number = 0x1007;
const GET_OBJECT_INFO: number = 0x1008;
const GET_OBJECT: number = 0x1009;
const GET_THUMB: number = 0x100a;
const DELETE_OBJECT: number = 0x100b;
const GET_DEVICE_PROPERTY_VALUE: number = 0x1015;
const SET_DEVICE_PROPERTY: number = 0x1016;
const EXPOSURE_TIME: number = 0x500d;
const NIKON_EXPOSURE_TIME: number = 0xd100;
const NIKON_MOVIE_EXPOSURE_TIME: number = 0xd1a8;
const NIKON_MOVIE_FILE_TYPE: number = 0xd0af;
const NIKON_MOVIE_PRORES_TONE_MODE: number = 0x0001d000;
const NIKON_MOVIE_H265_TONE_MODE: number = 0x0001d001;
const NIKON_MOVIE_NRAW_TONE_MODE: number = 0x0001d028;
const NIKON_MOVIE_PRORES_RAW_TONE_MODE: number = 0x0001d029;
const NIKON_H264_8_BIT: number = 0x00000801;
const NIKON_H265_10_BIT: number = 0x00010a00;
const NIKON_NRAW_12_BIT: number = 0x00020c02;
const NIKON_PRORES_422_10_BIT: number = 0x00100a00;
const NIKON_PRORES_RAW_12_BIT: number = 0x00110c00;
const SONY_PICTURE_PROFILE: number = 0xd23f;
const SONY_MOVIE_FILE_FORMAT: number = 0xd241;
const CANON_EOS_SET_DEVICE_PROP_VALUE_EX: number = 0x9110;
const CANON_LOG_GAMMA: number = 0xd176;
const CHANGE_CAMERA_MODE: number = 0x90c2;
const DEVICE_READY: number = 0x90c8;
const GET_EVENT: number = 0x90c7;
const START_LIVE_VIEW: number = 0x9201;
const END_LIVE_VIEW: number = 0x9202;
const GET_LIVE_VIEW_IMAGE: number = 0x9203;
const MANUAL_FOCUS_DRIVE: number = 0x9204;
const AUTO_FOCUS_DRIVE: number = 0x90c1;
const CAPTURE_TO_SDRAM: number = 0x9207;
const START_MOVIE_RECORDING: number = 0x920a;
const END_MOVIE_RECORDING: number = 0x920b;
const TERMINATE_CAPTURE: number = 0x920c;
const OBJECT_ADDED_IN_SDRAM: number = 0xc101;
const STILL_IMAGE_CLASS: number = 6;
const BULK_TRANSFER_TYPE: number = 2;
const ENDPOINT_IN: number = 0x80;
const MAXIMUM_CONTAINER_SIZE: number = 256 * 1024 * 1024;
// HarmonyOS documents a <200 KB aggregate limit for one bulkTransfer call.
const USB_CHUNK_SIZE: number = 192 * 1024;

class PtpContainer {
  readonly type: number;
  readonly code: number;
  readonly transaction: number;
  readonly payload: Uint8Array;

  constructor(
    type: number,
    code: number,
    transaction: number,
    payload: Uint8Array
  ) {
    this.type = type;
    this.code = code;
    this.transaction = transaction;
    this.payload = payload;
  }
}

export class PtpCamera {
  private pipe?: Readonly<usbManager.USBDevicePipe>;
  private cameraInterface?: usbManager.USBInterface;
  private bulkIn?: usbManager.USBEndpoint;
  private bulkOut?: usbManager.USBEndpoint;
  private transaction: number = 0;
  private liveView: boolean = false;
  private movieRecording: boolean = false;
  private exposureMode: string = 'manual';
  private bulbDurationSeconds: number = 5;
  private activeProfile?: CameraProfile;
  private transferTail: Promise<void> = Promise.resolve();
  private deniedParameters: Set<string> = new Set<string>();

  get isConnected(): boolean {
    return this.pipe !== undefined;
  }

  get isLiveView(): boolean {
    return this.liveView;
  }

  get isMovieRecording(): boolean {
    return this.movieRecording;
  }

  get profile(): CameraProfile | undefined {
    return this.activeProfile;
  }

  async listStorage(): Promise<CameraStorageSnapshot> {
    this.ensureConnected();
    const resumeLiveView: boolean = this.liveView;
    if (resumeLiveView) {
      await this.stopLiveView();
    }
    try {
      const volumes: Array<CameraStorageVolume> = [];
      const items: Array<CameraStorageItem> = [];
      const storageIds: Array<number> = parseStorageIds(
        await this.transact(GET_STORAGE_IDS, [], undefined, 15000)
      );
      for (const storageId of storageIds) {
        volumes.push(parseStorageInfo(
          storageId,
          await this.transact(
            GET_STORAGE_INFO,
            [storageId],
            undefined,
            15000
          )
        ));
        const pendingHandles: Array<number> = parseStorageIds(
          await this.transact(
            GET_OBJECT_HANDLES,
            [storageId, 0, 0xffffffff],
            undefined,
            30000
          )
        );
        const visitedHandles: Set<number> = new Set<number>();
        let pendingIndex: number = 0;
        while (pendingIndex < pendingHandles.length) {
          const handle: number = pendingHandles[pendingIndex++];
          if (visitedHandles.has(handle)) {
            continue;
          }
          visitedHandles.add(handle);
          const objectInfo: Uint8Array = await this.transact(
            GET_OBJECT_INFO,
            [handle],
            undefined,
            15000
          );
          if (isObjectAssociation(objectInfo)) {
            const children: Array<number> = parseStorageIds(
              await this.transact(
                GET_OBJECT_HANDLES,
                [storageId, 0, handle],
                undefined,
                30000
              )
            );
            children.forEach((child: number): void => {
              if (!visitedHandles.has(child)) {
                pendingHandles.push(child);
              }
            });
          } else {
            const item: CameraStorageItem | undefined = parseObjectInfo(
              handle,
              objectInfo
            );
            if (item !== undefined) {
              items.push(item);
            }
          }
        }
      }
      items.sort((left: CameraStorageItem, right: CameraStorageItem): number => {
        const byDate: number = right.capturedAt.localeCompare(left.capturedAt);
        return byDate !== 0
          ? byDate
          : right.filename.localeCompare(left.filename);
      });
      hilog.info(0x0000, 'ZENCHE',
        `[camera-storage] ${this.cameraName()} 已读取 ${volumes.length} 个存储卷、${items.length} 个文件`);
      return new CameraStorageSnapshot(volumes, items);
    } finally {
      if (resumeLiveView && this.isConnected) {
        await this.resumeLiveViewAfterExclusiveOperation();
      }
    }
  }

  async getStorageThumbnail(handle: number): Promise<Uint8Array> {
    this.ensureConnected();
    return this.transact(GET_THUMB, [handle], undefined, 30000);
  }

  async downloadStorageObject(handle: number): Promise<Uint8Array> {
    this.ensureConnected();
    const resumeLiveView: boolean = this.liveView;
    if (resumeLiveView) {
      await this.stopLiveView();
    }
    try {
      return await this.transact(GET_OBJECT, [handle], undefined, 180000);
    } finally {
      if (resumeLiveView && this.isConnected) {
        await this.resumeLiveViewAfterExclusiveOperation();
      }
    }
  }

  async deleteStorageObject(handle: number): Promise<void> {
    this.ensureConnected();
    const resumeLiveView: boolean = this.liveView;
    if (resumeLiveView) {
      await this.stopLiveView();
    }
    try {
      await this.transact(DELETE_OBJECT, [handle, 0], undefined, 30000);
    } finally {
      if (resumeLiveView && this.isConnected) {
        await this.resumeLiveViewAfterExclusiveOperation();
      }
    }
  }

  async connect(): Promise<CameraProfile> {
    await this.disconnect();
    const devices: Array<Readonly<usbManager.USBDevice>> =
      usbManager.getDevices();
    let selectedDevice: Readonly<usbManager.USBDevice> | undefined;
    let selectedProfile: CameraProfile | undefined;
    let unsupportedVendor: number = 0;
    let unsupportedProduct: number = 0;

    for (const device of devices) {
      if (!SUPPORTED_VENDOR_IDS.has(device.vendorId)) {
        continue;
      }
      const candidate: CameraProfile | undefined =
        profileForProduct(device.vendorId, device.productId);
      if (candidate !== undefined) {
        selectedDevice = device;
        selectedProfile = candidate;
        break;
      }
      unsupportedVendor = device.vendorId;
      unsupportedProduct = device.productId;
    }

    if (selectedDevice === undefined || selectedProfile === undefined) {
      if (unsupportedVendor !== 0) {
        const vendorHex: string = unsupportedVendor.toString(16).padStart(4, '0');
        const productHex: string = unsupportedProduct.toString(16).padStart(4, '0');
        throw new Error(
          `检测到未支持的 USB 相机设备 ${vendorHex}:${productHex}。当前支持 ${supportedCameraSummary()}。`
        );
      }
      throw new Error(
        `没有检测到支持的相机。请连接 ${supportedCameraSummary()}。`
      );
    }

    let granted: boolean = usbManager.hasRight(selectedDevice.name);
    if (!granted) {
      granted = await usbManager.requestRight(selectedDevice.name);
    }
    if (!granted) {
      throw new Error(`未获得 ${selectedProfile.name} 的 USB 访问权限。`);
    }

    const interfaceInfo: usbManager.USBInterface | undefined =
      this.findStillImageInterface(selectedDevice);
    if (interfaceInfo === undefined) {
      throw new Error(
        `${selectedProfile.name} 没有提供可用的 PTP USB 接口。`
      );
    }

    const input: usbManager.USBEndpoint | undefined =
      interfaceInfo.endpoints.find((endpoint: usbManager.USBEndpoint) =>
        endpoint.type === BULK_TRANSFER_TYPE &&
        (endpoint.address & ENDPOINT_IN) !== 0
      );
    const output: usbManager.USBEndpoint | undefined =
      interfaceInfo.endpoints.find((endpoint: usbManager.USBEndpoint) =>
        endpoint.type === BULK_TRANSFER_TYPE &&
        (endpoint.address & ENDPOINT_IN) === 0
      );
    if (input === undefined || output === undefined) {
      throw new Error(`${selectedProfile.name} 的 PTP bulk endpoint 不完整。`);
    }

    try {
      this.pipe = usbManager.connectDevice(
        selectedDevice as usbManager.USBDevice
      );
      if (this.pipe === undefined) {
        throw new Error('USB 服务没有返回设备连接管道。');
      }
      const claimResult: number = usbManager.claimInterface(
        this.pipe,
        interfaceInfo,
        true
      );
      if (claimResult !== 0) {
        throw new Error(`声明 PTP 接口失败，错误码 ${claimResult}。`);
      }
      this.cameraInterface = interfaceInfo;
      this.bulkIn = input;
      this.bulkOut = output;
      this.activeProfile = selectedProfile;
      this.transaction = 0;
      await this.transact(OPEN_SESSION, [1], undefined, 10000);
      return selectedProfile;
    } catch (error) {
      const message: string = (error as BusinessError).message;
      await this.disconnect();
      throw new Error(
        `无法打开 ${selectedProfile.name}。请关闭占用相机的应用并重新插拔 USB：${message}`
      );
    }
  }

  async startLiveView(): Promise<void> {
    this.ensureConnected();
    if (this.liveView) {
      return;
    }
    await this.transact(START_LIVE_VIEW, [], undefined, 10000);
    this.liveView = true;
  }

  async stopLiveView(): Promise<void> {
    if (!this.liveView || !this.isConnected) {
      this.liveView = false;
      return;
    }
    try {
      await this.transact(END_LIVE_VIEW, [], undefined, 5000);
    } finally {
      this.liveView = false;
    }
  }

  async getLiveViewFrame(): Promise<Uint8Array> {
    this.ensureConnected();
    if (!this.liveView) {
      throw new Error('实时取景尚未开启。');
    }
    const data: Uint8Array = await this.transact(
      GET_LIVE_VIEW_IMAGE,
      [],
      undefined,
      12000
    );
    return this.extractJpeg(data);
  }

  async startMovieRecording(): Promise<void> {
    this.ensureConnected();
    if (this.movieRecording) {
      return;
    }
    if (!this.liveView) {
      await this.startLiveView();
    }
    await this.transact(
      START_MOVIE_RECORDING,
      [],
      undefined,
      15000
    );
    this.movieRecording = true;
  }

  async stopMovieRecording(): Promise<void> {
    this.ensureConnected();
    if (!this.movieRecording) {
      return;
    }
    try {
      await this.transact(
        END_MOVIE_RECORDING,
        [],
        undefined,
        15000
      );
    } finally {
      this.movieRecording = false;
    }
  }

  async capture(): Promise<Uint8Array> {
    this.ensureConnected();
    const resumeLiveView: boolean = this.liveView;
    let releaseRemoteMode: boolean = false;
    try {
      if (resumeLiveView) {
        await this.stopLiveView();
        await this.waitUntilDeviceReady(6000);
      }
      await this.waitUntilDeviceReady(6000);
      if (this.exposureMode === 'bulb') {
        await this.transact(CHANGE_CAMERA_MODE, [1], undefined, 10000);
        releaseRemoteMode = true;
        await this.setProperty(0x500e, this.littleEndian16(1));
        await this.setShutterRaw(false, 0xffffffff);
        await this.transact(
          CAPTURE_TO_SDRAM,
          [0xffffffff, 1],
          undefined,
          60000
        );
        await this.sleep(
          Math.max(1, Math.min(900, this.bulbDurationSeconds)) * 1000
        );
        await this.transact(
          TERMINATE_CAPTURE,
          [0, 0],
          undefined,
          15000
        );
      } else {
        await this.transact(
          CAPTURE_TO_SDRAM,
          [0xffffffff, 1],
          undefined,
          60000
        );
      }

      let handle: number = 0xffff0001;
      const deadline: number = Date.now() + 30000;
      while (Date.now() < deadline) {
        try {
          await this.transact(DEVICE_READY, [], undefined, 3000);
          const events: Uint8Array = await this.transact(
            GET_EVENT,
            [],
            undefined,
            3000
          );
          const eventHandle: number = this.findSdramObject(events);
          if (eventHandle !== 0) {
            handle = eventHandle;
            break;
          }
        } catch (error) {
          // The body can report busy while it writes the capture.
        }
        await this.sleep(180);
      }

      let source: Uint8Array | undefined = undefined;
      let objectError: Error | undefined;
      for (let attempt: number = 0; attempt < 4; attempt++) {
        try {
          source = await this.transact(
            GET_OBJECT,
            [handle],
            undefined,
            60000
          );
          break;
        } catch (error) {
          const candidate: Error = error as Error;
          objectError = candidate;
          if (!candidate.message.includes('0x2009') &&
              !candidate.message.includes('busy') &&
              !candidate.message.includes('Busy')) {
            throw candidate;
          }
          hilog.warn(
            0x0000,
            'NikonLink',
            `[camera] ${this.cameraName()} 读取照片时相机忙，第 ${attempt + 1} 次重试：${candidate.message}`
          );
          await this.waitUntilDeviceReady(3000);
        }
      }
      if (source === undefined && objectError !== undefined) {
        throw objectError;
      }
      await this.waitUntilDeviceReady(8000);
      return this.extractJpeg(source as Uint8Array);
    } finally {
      if (releaseRemoteMode && this.isConnected) {
        try {
          await this.waitUntilDeviceReady(8000);
        } catch (error) {
        }
        try {
          await this.transact(CHANGE_CAMERA_MODE, [0], undefined, 10000);
        } catch (error) {
        }
      }
      if (resumeLiveView && this.isConnected) {
        await this.resumeLiveViewAfterExclusiveOperation();
      }
    }
  }

  async setParameter(name: string, rawValue: string | number): Promise<void> {
    if (!this.canAdjustParameter(name)) {
      throw new Error(this.parameterLockReason(name));
    }
    // Keep the live-view stream alive while changing AF mode. Restarting it
    // immediately before MANUAL_FOCUS_DRIVE races the next preview transfer
    // and surfaces as "I/O in progress" on some camera/USB stacks.
    const preserveLiveViewForFocus: boolean = name === 'focusMode' && this.liveView;
    const resumeLiveView: boolean = this.liveView && !preserveLiveViewForFocus;
    if (resumeLiveView) {
      await this.stopLiveView();
    }
    try {
      let lastError: Error | undefined;
      const maxRetries: number = 5;
      for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
          await this.setParameterCore(name, rawValue);
          return;
        } catch (error) {
          lastError = error as Error;
          const message: string = lastError.message;
          const focusTransient: boolean = name === 'focusMode' &&
            this.isTransientFocusError(lastError);
          if ((!this.isTransientPtpError(lastError) && !focusTransient)
              || attempt >= maxRetries - 1) {
            if (focusTransient) {
              throw this.enhanceFocusError(lastError);
            }
            if (message.includes('0x200F') || message.includes('0x201C')) {
              throw new Error(
                `${this.cameraName()} 当前状态暂时拒绝写入此参数。` +
                '请确认机身处于允许调整的曝光模式后重试。'
              );
            }
            throw lastError;
          }
          await new Promise<void>(
            (resolve) => setTimeout(
              resolve, 200 * (attempt + 1)));
        }
      }
      throw lastError ?? new Error(
        `${this.cameraName()} 参数写入失败。`);
    } finally {
      if (resumeLiveView && this.isConnected) {
        await this.resumeLiveViewAfterExclusiveOperation();
      }
    }
  }

  async moveFocus(signedStep: number): Promise<void> {
    this.ensureConnected();
    if (!this.liveView) {
      throw new Error('焦点步进仅能在实时取景开启时使用。');
    }
    const normalized: number = Math.max(-3, Math.min(3, signedStep));
    if (normalized === 0) {
      return;
    }
    const direction: number = normalized < 0 ? 0x1 : 0x2;
    const magnitude: number = Math.abs(normalized);
    const amount: number = magnitude === 1 ? 128 : magnitude === 2 ? 512 : 1024;
    let lastError: Error | undefined;
    for (let attempt: number = 0; attempt < 3; attempt++) {
      try {
        await this.transact(
          MANUAL_FOCUS_DRIVE,
          [direction, amount],
          undefined,
          10000
        );
      } catch (error) {
        lastError = error as Error;
        if (!this.isTransientFocusError(lastError) || attempt >= 2) {
          throw this.enhanceFocusError(lastError);
        }
        await this.sleep(180 * (attempt + 1));
        continue;
      }
      try {
        await this.waitUntilDeviceReady(4000);
        return;
      } catch (readyError) {
        // The drive response means the lens already moved. Retry readiness
        // only so a slow body does not get two focus moves.
        if (!this.isTransientFocusError(readyError as Error)) {
          throw new Error((readyError as Error).message);
        }
        try {
          await this.waitUntilDeviceReady(4000);
          return;
        } catch (finalReadyError) {
          throw this.enhanceFocusError(finalReadyError as Error);
        }
      }
    }
    throw lastError ?? new Error(`${this.cameraName()} 对焦请求失败。`);
  }

  async triggerAutoFocus(): Promise<void> {
    this.ensureConnected();
    if (!this.liveView) {
      throw new Error('AF-ON 仅能在实时取景开启时使用。');
    }
    await this.setParameter('focusMode', 'single-shot');
    let lastError: Error | undefined;
    for (let attempt: number = 0; attempt < 3; attempt++) {
      try {
        await this.transact(AUTO_FOCUS_DRIVE, [], undefined, 10000);
        await this.waitUntilDeviceReady(4000);
        return;
      } catch (error) {
        lastError = error as Error;
        if (!this.isTransientFocusError(lastError) || attempt >= 2) {
          throw this.enhanceFocusError(lastError);
        }
        await this.sleep(180 * (attempt + 1));
      }
    }
    throw lastError ?? new Error('AF-ON 请求失败。');
  }

  private async setParameterCore(
    name: string,
    rawValue: string | number
  ): Promise<void> {
    this.ensureConnected();
    if (name === 'bulbDuration') {
      if (this.exposureMode !== 'bulb') {
        throw new Error(
          'B门曝光时长仅能在 M 拍摄模式的 B门快门速度下调整。'
        );
      }
      this.bulbDurationSeconds = Math.max(
        1,
        Math.min(900, Number(rawValue))
      );
      return;
    }
    if (!this.canAdjust(name)) {
      throw new Error('当前拍摄模式下此参数由相机控制。');
    }

    if (name === 'focusMode') {
      const mode: string = String(rawValue);
      const stillValue: number =
        mode === 'manual' ? 0x0001 :
        mode === 'continuous' ? 0x8011 : 0x8010;
      const liveValue: number =
        mode === 'manual' ? 4 : mode === 'continuous' ? 1 : 0;
      if (this.liveView) {
        try {
          await this.setProperty(0xd061, new Uint8Array([liveValue]));
        } catch (liveViewError) {
          await this.setProperty(0x500a, this.littleEndian16(stillValue));
        }
      } else {
        try {
          await this.setProperty(0x500a, this.littleEndian16(stillValue));
        } catch (stillError) {
          await this.setProperty(0xd061, new Uint8Array([liveValue]));
        }
      }
      return;
    }

    if (name === 'videoCodec') {
      await this.setVideoCodec(String(rawValue));
      return;
    }
    if (name === 'videoLog') {
      await this.setVideoLog(String(rawValue));
      return;
    }
    if (name === 'nLog') {
      await this.setVideoLog(Number(rawValue) !== 0 ? 'nlog' : 'off');
      return;
    }

    let property: number = 0;
    let value: Uint8Array = new Uint8Array(0);
    const numericValue: number = Number(rawValue);
    switch (name) {
      case 'exposureTime':
      case 'videoExposureTime':
        await this.setShutterSeconds(
          numericValue,
          name === 'videoExposureTime'
        );
        return;
      case 'aperture':
        property = 0x5007;
        value = this.littleEndian16(Math.round(numericValue * 100));
        break;
      case 'iso':
        property = 0x500f;
        value = this.littleEndian16(Math.round(numericValue));
        break;
      case 'exposureCompensation':
        property = 0x5010;
        value = this.littleEndian16(Math.round(numericValue * 1000));
        break;
      case 'whiteBalanceMode':
        property = 0x5005;
        value = this.littleEndian16(
          String(rawValue) === 'continuous' ? 0x0002 : 0x8013
        );
        break;
      case 'pictureControl':
        property = 0xd200;
        value = this.littleEndian16(this.pictureControlValue(String(rawValue)));
        break;
      case 'exposureMode':
        const requestedExposureMode: string = String(rawValue);
        property = 0x500e;
        if (requestedExposureMode === 'bulb') {
          // Keep Bulb as local capture state until the user presses the
          // shutter, so the app does not monopolize the physical shutter.
          this.exposureMode = requestedExposureMode;
          return;
        }
        value = this.littleEndian16(
          requestedExposureMode === 'aperturePriority' ? 3 :
          requestedExposureMode === 'shutterPriority' ? 4 :
          requestedExposureMode === 'program' ? 2 : 1
        );
        break;
      default:
        throw new Error(`${this.cameraName()} 不支持此参数：${name}`);
    }
    await this.setProperty(property, value);
    if (name === 'exposureMode') {
      this.exposureMode = String(rawValue);
    }
  }

  private async setVideoCodec(codec: string): Promise<void> {
    if (this.activeProfile === undefined) {
      throw new Error('请先连接支持的相机。');
    }
    if (this.activeProfile.vendorId === 0x054c) {
      const value: number = codec === 'sonyXavcHs8k' ? 10 :
        codec === 'sonyXavcHs4k' ? 11 :
        codec === 'sonyXavcS4k' ? 8 :
        codec === 'sonyXavcSHd' ? 9 :
        codec === 'sonyXavcSi4k' ? 14 :
        codec === 'sonyXavcSiHd' ? 15 : -1;
      if (value < 0) throw new Error('Sony 不支持所选视频录制规格。');
      await this.setProperty(
        SONY_MOVIE_FILE_FORMAT,
        new Uint8Array([value])
      );
      return;
    }
    if (this.activeProfile.vendorId === 0x04a9) {
      throw new Error(
        `${this.activeProfile.name} 未报告可写的佳能录制格式属性；` +
        '规格已展示，请在机身中选择 RAW、XF-HEVC S 或 XF-AVC S。'
      );
    }
    if (this.activeProfile.vendorId !== 0x04b0) {
      throw new Error('当前相机不支持远程切换视频录制规格。');
    }
    if (
      ['nraw', 'proresRaw', 'prores422hq'].includes(codec) &&
      !this.supportsAdvancedNikonVideo(this.activeProfile.name)
    ) {
      throw new Error(`${this.activeProfile.name} 不支持所选 RAW/ProRes 视频编码。`);
    }
    const normalized: string = codec.toLowerCase();
    const value: number = normalized === 'h265' ? NIKON_H265_10_BIT :
      normalized === 'prores422hq' ? NIKON_PRORES_422_10_BIT :
        normalized === 'proresraw' ? NIKON_PRORES_RAW_12_BIT :
          normalized === 'nraw' ? NIKON_NRAW_12_BIT : NIKON_H264_8_BIT;
    await this.setProperty(
      NIKON_MOVIE_FILE_TYPE,
      this.littleEndian32(value)
    );
  }

  private async setVideoLog(logProfile: string): Promise<void> {
    if (this.activeProfile === undefined) {
      throw new Error('请先连接支持的相机。');
    }
    if (this.activeProfile.vendorId === 0x054c) {
      const value: number = logProfile === 'off' ? 0 :
        logProfile === 'sonySLog2' ? 7 :
        logProfile === 'sonySLog3Cine' ? 8 :
        logProfile === 'sonySLog3' ? 9 :
        logProfile === 'sonyHlg' ? 10 : -1;
      if (value < 0) throw new Error('Sony 不支持所选 Log / Picture Profile。');
      await this.setProperty(SONY_PICTURE_PROFILE, new Uint8Array([value]));
      return;
    }
    if (this.activeProfile.vendorId === 0x04a9) {
      const value: number = logProfile === 'off' ? 0 :
        logProfile === 'canonLog' ? 1 :
        logProfile === 'canonLog2' ? 2 :
        logProfile === 'canonLog3' ? 3 : -1;
      if (value < 0) throw new Error('Canon 不支持所选 Canon Log 曲线。');
      const payload: Uint8Array = new Uint8Array(12);
      const view: DataView = new DataView(payload.buffer);
      view.setUint32(0, 12, true);
      view.setUint32(4, CANON_LOG_GAMMA, true);
      view.setUint32(8, value, true);
      await this.transact(
        CANON_EOS_SET_DEVICE_PROP_VALUE_EX,
        [],
        payload,
        10000
      );
      return;
    }
    if (this.activeProfile.vendorId !== 0x04b0) {
      throw new Error('当前相机不支持远程切换 Log 曲线。');
    }
    const enabled: boolean = logProfile !== 'off';
    if (enabled && logProfile !== 'nlog') {
      throw new Error('Nikon 机身仅支持 N-Log。');
    }
    const fileTypeData: Uint8Array = await this.transact(
      GET_DEVICE_PROPERTY_VALUE,
      [NIKON_MOVIE_FILE_TYPE],
      undefined,
      10000
    );
    if (fileTypeData.length < 4) {
      throw new Error('相机未返回有效的视频编码值。');
    }
    const fileType: number = new DataView(
      fileTypeData.buffer,
      fileTypeData.byteOffset,
      fileTypeData.byteLength
    ).getUint32(0, true);
    const toneProperty: number = this.nikonToneProperty(fileType, enabled);
    if (toneProperty === 0) return;
    await this.setProperty(
      toneProperty,
      new Uint8Array([enabled ? 1 : 0])
    );
  }

  private nikonToneProperty(fileType: number, enabled: boolean): number {
    if (fileType === NIKON_H265_10_BIT) return NIKON_MOVIE_H265_TONE_MODE;
    if (fileType === NIKON_NRAW_12_BIT) return NIKON_MOVIE_NRAW_TONE_MODE;
    if (fileType === NIKON_PRORES_422_10_BIT) return NIKON_MOVIE_PRORES_TONE_MODE;
    if (fileType === NIKON_PRORES_RAW_12_BIT) {
      return NIKON_MOVIE_PRORES_RAW_TONE_MODE;
    }
    if (!enabled) return 0;
    throw new Error(
      '当前编码不支持 N-Log；请选择 H.265 10-bit、N-RAW、ProRes 422 HQ 或 ProRes RAW。'
    );
  }

  private supportsAdvancedNikonVideo(name: string): boolean {
    return name.includes('Z9') || name.includes('Z8') ||
      name.includes('Z6III') || name.includes('ZR');
  }

  canAdjustParameter(name: string): boolean {
    if (
      name === 'videoCodec' &&
      this.activeProfile?.vendorId === 0x04a9
    ) {
      return false;
    }
    return !this.deniedParameters.has(name) && this.canAdjust(name);
  }

  parameterLockReason(name: string): string {
    if (
      name === 'videoCodec' &&
      this.activeProfile?.vendorId === 0x04a9
    ) {
      return '该 Canon 机身未报告通用可写的录制格式属性，请在机身菜单中选择规格';
    }
    if (this.deniedParameters.has(name)) {
      return '相机已拒绝此参数，本次连接内保持锁定';
    }
    return '当前拍摄模式下由相机控制';
  }

  async disconnect(): Promise<void> {
    if (this.pipe !== undefined) {
      if (this.movieRecording) {
        try {
          await this.stopMovieRecording();
        } catch (error) {
          this.movieRecording = false;
        }
      }
      try {
        await this.stopLiveView();
      } catch (error) {
      }
      try {
        await this.transact(CLOSE_SESSION, [], undefined, 2000);
      } catch (error) {
      }
      if (this.cameraInterface !== undefined) {
        try {
          usbManager.releaseInterface(this.pipe, this.cameraInterface);
        } catch (error) {
        }
      }
      try {
        usbManager.closePipe(this.pipe);
      } catch (error) {
      }
    }
    this.pipe = undefined;
    this.cameraInterface = undefined;
    this.bulkIn = undefined;
    this.bulkOut = undefined;
    this.activeProfile = undefined;
    this.liveView = false;
    this.movieRecording = false;
    this.transaction = 0;
    this.deniedParameters.clear();
  }

  private findStillImageInterface(
    device: Readonly<usbManager.USBDevice>
  ): usbManager.USBInterface | undefined {
    for (const configuration of device.configs) {
      for (const interfaceInfo of configuration.interfaces) {
        if (interfaceInfo.clazz === STILL_IMAGE_CLASS) {
          return interfaceInfo;
        }
      }
    }
    return undefined;
  }

  private async transact(
    operation: number,
    parameters: Array<number>,
    outgoingData: Uint8Array | undefined,
    timeout: number
  ): Promise<Uint8Array> {
    let release: () => void = (): void => {};
    const previous: Promise<void> = this.transferTail;
    this.transferTail = new Promise<void>(
      (resolve: () => void): void => {
        release = resolve;
      }
    );
    await previous;
    try {
      return await this.transactCore(
        operation,
        parameters,
        outgoingData,
        timeout
      );
    } finally {
      release();
    }
  }

  private async transactCore(
    operation: number,
    parameters: Array<number>,
    outgoingData: Uint8Array | undefined,
    timeout: number
  ): Promise<Uint8Array> {
    this.ensureConnectedForOperation(operation);
    const current: number = operation === OPEN_SESSION
      ? 0
      : ((this.transaction + 1) >>> 0);
    this.transaction = current;
    const parameterBytes: Uint8Array = new Uint8Array(parameters.length * 4);
    const parameterView: DataView = new DataView(parameterBytes.buffer);
    parameters.forEach((parameter: number, index: number) => {
      parameterView.setUint32(index * 4, parameter >>> 0, true);
    });

    await this.sendContainer(
      CONTAINER_COMMAND,
      operation,
      current,
      parameterBytes,
      timeout
    );
    if (outgoingData !== undefined) {
      await this.sendContainer(
        CONTAINER_DATA,
        operation,
        current,
        outgoingData,
        timeout
      );
    }

    const first: PtpContainer = await this.receiveContainer(timeout);
    let data: Uint8Array = new Uint8Array(0);
    let response: PtpContainer = first;
    if (first.type === CONTAINER_DATA) {
      data = first.payload;
      response = await this.receiveContainer(timeout);
    }
    if (response.type !== CONTAINER_RESPONSE) {
      throw new Error(
        `${this.cameraName()} 返回了无效的 PTP 容器类型 ${response.type}。`
      );
    }
    if (
      response.transaction !== current ||
      (first.type === CONTAINER_DATA && first.transaction !== current)
    ) {
      throw new Error(`${this.cameraName()} 返回了不匹配的 PTP 事务编号。`);
    }
    if (
      response.code !== RESPONSE_OK &&
      !(operation === OPEN_SESSION &&
        response.code === RESPONSE_SESSION_ALREADY_OPEN)
    ) {
      throw new Error(
        `${this.cameraName()} PTP 错误 0x${response.code
          .toString(16)
          .padStart(4, '0')}（操作 0x${operation
          .toString(16)
          .padStart(4, '0')}）`
      );
    }
    return data;
  }

  private async sendContainer(
    type: number,
    code: number,
    transaction: number,
    payload: Uint8Array,
    timeout: number
  ): Promise<void> {
    if (this.pipe === undefined || this.bulkOut === undefined) {
      throw new Error('USB 输出 endpoint 不可用。');
    }
    const packet: Uint8Array = new Uint8Array(12 + payload.length);
    const view: DataView = new DataView(packet.buffer);
    view.setUint32(0, packet.length, true);
    view.setUint16(4, type, true);
    view.setUint16(6, code, true);
    view.setUint32(8, transaction >>> 0, true);
    packet.set(payload, 12);

    let offset: number = 0;
    while (offset < packet.length) {
      const size: number = Math.min(USB_CHUNK_SIZE, packet.length - offset);
      const chunk: Uint8Array = packet.slice(offset, offset + size);
      const sent: number = await usbManager.bulkTransfer(
        this.pipe,
        this.bulkOut,
        chunk,
        timeout
      );
      if (sent <= 0) {
        throw new Error(`向 ${this.cameraName()} 发送 USB 数据失败。`);
      }
      offset += sent;
    }
  }

  private async receiveContainer(timeout: number): Promise<PtpContainer> {
    if (this.pipe === undefined || this.bulkIn === undefined) {
      throw new Error('USB 输入 endpoint 不可用。');
    }
    const first: Uint8Array = new Uint8Array(USB_CHUNK_SIZE);
    const received: number = await usbManager.bulkTransfer(
      this.pipe,
      this.bulkIn,
      first,
      timeout
    );
    if (received < 12) {
      throw new Error(`读取 ${this.cameraName()} USB 数据失败。`);
    }

    const header: DataView = new DataView(first.buffer, 0, received);
    const total: number = header.getUint32(0, true);
    const type: number = header.getUint16(4, true);
    const code: number = header.getUint16(6, true);
    const transaction: number = header.getUint32(8, true);
    if (total < 12 || total > MAXIMUM_CONTAINER_SIZE) {
      throw new Error(
        `${this.cameraName()} 返回的数据长度无效：${total}。`
      );
    }

    const all: Uint8Array = new Uint8Array(total);
    const initialCount: number = Math.min(received, total);
    all.set(first.slice(0, initialCount), 0);
    let offset: number = initialCount;
    while (offset < total) {
      const buffer: Uint8Array = new Uint8Array(
        Math.min(USB_CHUNK_SIZE, total - offset)
      );
      const count: number = await usbManager.bulkTransfer(
        this.pipe,
        this.bulkIn,
        buffer,
        timeout
      );
      if (count <= 0) {
        throw new Error(`${this.cameraName()} 图像传输中断。`);
      }
      const copyCount: number = Math.min(count, total - offset);
      all.set(buffer.slice(0, copyCount), offset);
      offset += copyCount;
    }
    return new PtpContainer(
      type,
      code,
      transaction,
      all.slice(12, total)
    );
  }

  private async setProperty(
    property: number,
    value: Uint8Array
  ): Promise<void> {
    await this.transact(
      SET_DEVICE_PROPERTY,
      [property],
      value,
      10000
    );
  }

  private async setShutterSeconds(
    seconds: number,
    video: boolean
  ): Promise<void> {
    if (!Number.isFinite(seconds) || seconds <= 0) {
      throw new Error('快门速度必须大于 0 秒。');
    }
    let finalError: Error | undefined;
    for (const property of this.shutterProperties(video)) {
      const encoded: Uint8Array = property === EXPOSURE_TIME
        ? this.littleEndian32(Math.round(seconds * 10000))
        : this.nikonShutterValue(seconds);
      try {
        await this.setProperty(property, encoded);
        return;
      } catch (error) {
        const candidate: Error = error as Error;
        if (!this.isPropertyCompatibilityError(candidate)) {
          throw candidate;
        }
        finalError = candidate;
      }
    }
    throw new Error(
      `${this.cameraName()} 当前没有可写的${video ? '视频' : '照片'}快门属性。` +
      '请确认相机处于 M/S 模式，且未在机身菜单中锁定曝光参数。' +
      (finalError === undefined ? '' : `（${finalError.message}）`)
    );
  }

  private async setShutterRaw(
    video: boolean,
    rawValue: number
  ): Promise<void> {
    let finalError: Error | undefined;
    for (const property of this.shutterProperties(video)) {
      try {
        await this.setProperty(property, this.littleEndian32(rawValue));
        return;
      } catch (error) {
        const candidate: Error = error as Error;
        if (!this.isPropertyCompatibilityError(candidate)) {
          throw candidate;
        }
        finalError = candidate;
      }
    }
    throw new Error(
      `${this.cameraName()} 当前不支持通过 USB/PTP 设置 B 门快门。` +
      (finalError === undefined ? '' : `（${finalError.message}）`)
    );
  }

  private shutterProperties(video: boolean): Array<number> {
    return video
      ? [
        NIKON_MOVIE_EXPOSURE_TIME,
        EXPOSURE_TIME,
        NIKON_EXPOSURE_TIME
      ]
      : [NIKON_EXPOSURE_TIME, EXPOSURE_TIME];
  }

  private nikonShutterValue(seconds: number): Uint8Array {
    let numerator: number;
    let denominator: number;
    if (seconds < 1) {
      numerator = 1;
      denominator = Math.max(1, Math.round(1 / seconds));
    } else if (Math.abs(seconds - Math.round(seconds)) < 0.000001) {
      numerator = Math.round(seconds);
      denominator = 1;
    } else {
      denominator = 1000;
      numerator = Math.round(seconds * denominator);
      const divisor: number =
        this.greatestCommonDivisor(numerator, denominator);
      numerator = Math.round(numerator / divisor);
      denominator = Math.round(denominator / divisor);
    }
    numerator = Math.max(1, Math.min(0xffff, numerator));
    denominator = Math.max(1, Math.min(0xffff, denominator));
    return this.littleEndian32(
      ((numerator << 16) | denominator) >>> 0
    );
  }

  private greatestCommonDivisor(left: number, right: number): number {
    let first: number = Math.round(left);
    let second: number = Math.round(right);
    while (second !== 0) {
      const remainder: number = first % second;
      first = second;
      second = remainder;
    }
    return Math.max(1, first);
  }

  private isPropertyCompatibilityError(error: Error): boolean {
    return error.message.includes('0x2005') ||
      error.message.includes('0x200a') ||
      error.message.includes('0x200A') ||
      error.message.includes('0x200f') ||
      error.message.includes('0x200F') ||
      error.message.includes('0x201c') ||
      error.message.includes('0x201C') ||
      error.message.includes('0x201d') ||
      error.message.includes('0x201D');
  }

  private isTransientPtpError(error: Error): boolean {
    const message: string = error.message;
    return message.includes('0x200f') || message.includes('0x200F') ||
      message.includes('0x201c') || message.includes('0x201C');
  }

  private isTransientFocusError(error: Error): boolean {
    const message: string = error.message;
    const normalized: string = message.toLowerCase();
    return message.includes('0x2019') ||
      normalized.includes('busy') ||
      normalized.includes('in progress') ||
      normalized.includes('i/o') ||
      normalized.includes('timeout') ||
      normalized.includes('error code=-110') ||
      normalized.includes('错误码=-110') ||
      normalized.includes('-110') ||
      message.includes('超时') ||
      message.includes('传输失败');
  }

  private enhanceFocusError(error: Error): Error {
    if (!this.isTransientFocusError(error)) {
      return error;
    }
    return new Error(
      `${this.cameraName()} 当前正在传输实时取景画面，暂时无法执行焦点步进。` +
      '请稍候片刻后重试。'
    );
  }

  private async waitUntilDeviceReady(timeout: number): Promise<void> {
    const deadline: number = Date.now() + timeout;
    let finalError: Error | undefined;
    while (Date.now() < deadline) {
      try {
        await this.transact(DEVICE_READY, [], undefined, 3000);
        return;
      } catch (error) {
        finalError = error as Error;
        await this.sleep(180);
      }
    }
    throw new Error(
      `${this.cameraName()} 在独占操作后未恢复就绪状态。` +
      (finalError === undefined ? '' : `（${finalError.message}）`)
    );
  }

  private async resumeLiveViewAfterExclusiveOperation(): Promise<void> {
    for (
      let attempt: number = 1;
      attempt <= 3 && this.isConnected;
      attempt++
    ) {
      try {
        await this.waitUntilDeviceReady(4000);
        await this.startLiveView();
        return;
      } catch (error) {
        this.liveView = false;
        await this.sleep(250 * attempt);
      }
    }
  }

  private canAdjust(name: string): boolean {
    switch (name) {
      case 'exposureTime':
      case 'videoExposureTime':
        return this.exposureMode === 'manual' ||
          this.exposureMode === 'shutterPriority';
      case 'aperture':
        return this.exposureMode === 'manual' ||
          this.exposureMode === 'aperturePriority' ||
          this.exposureMode === 'bulb';
      case 'iso':
        return true;
      case 'exposureCompensation':
        return this.exposureMode === 'program' ||
          this.exposureMode === 'aperturePriority' ||
          this.exposureMode === 'shutterPriority';
      default:
        return true;
    }
  }

  private pictureControlValue(value: string): number {
    switch (value) {
      case 'neutral':
        return 2;
      case 'vivid':
        return 3;
      case 'monochrome':
        return 4;
      case 'portrait':
        return 5;
      case 'landscape':
        return 6;
      case 'flat':
        return 7;
      case 'auto':
        return 8;
      default:
        return 1;
    }
  }

  private findSdramObject(events: Uint8Array): number {
    if (events.length < 2) {
      return 0;
    }
    const view: DataView = new DataView(
      events.buffer,
      events.byteOffset,
      events.byteLength
    );
    const count: number = view.getUint16(0, true);
    let offset: number = 2;
    for (
      let index: number = 0;
      index < count && offset + 6 <= events.length;
      index++, offset += 6
    ) {
      const code: number = view.getUint16(offset, true);
      const handle: number = view.getUint32(offset + 2, true);
      if (code === OBJECT_ADDED_IN_SDRAM) {
        return handle;
      }
    }
    return 0;
  }

  private extractJpeg(source: Uint8Array): Uint8Array {
    let start: number = -1;
    let end: number = -1;
    for (let index: number = 0; index < source.length - 1; index++) {
      if (
        start < 0 &&
        source[index] === 0xff &&
        source[index + 1] === 0xd8
      ) {
        start = index;
      }
      if (
        start >= 0 &&
        source[index] === 0xff &&
        source[index + 1] === 0xd9
      ) {
        end = index + 2;
      }
    }
    if (start < 0 || end <= start) {
      throw new Error(
        `${this.cameraName()} 返回的数据中没有 JPEG 图像。`
      );
    }
    return source.slice(start, end);
  }

  private littleEndian16(value: number): Uint8Array {
    const bytes: Uint8Array = new Uint8Array(2);
    new DataView(bytes.buffer).setUint16(0, value & 0xffff, true);
    return bytes;
  }

  private littleEndian32(value: number): Uint8Array {
    const bytes: Uint8Array = new Uint8Array(4);
    new DataView(bytes.buffer).setUint32(0, value >>> 0, true);
    return bytes;
  }

  private ensureConnected(): void {
    if (!this.isConnected) {
      throw new Error('请先连接支持的相机。');
    }
  }

  private ensureConnectedForOperation(operation: number): void {
    if (operation === OPEN_SESSION) {
      if (this.pipe === undefined) {
        throw new Error('无法打开 USB 相机连接。');
      }
      return;
    }
    this.ensureConnected();
  }

  private cameraName(): string {
    return this.activeProfile?.name ?? '相机';
  }

  private sleep(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds);
    });
  }
}
