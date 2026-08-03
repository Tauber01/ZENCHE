import { ble } from '@kit.ConnectivityKit';

const SERVICE_UUID: string = '7a5e0001-5e4e-4348-452d-52454d4f5445';
const SHUTTER_UUID: string = '7a5e0002-5e4e-4348-452d-52454d4f5445';

export class BluetoothRemoteController {
  private client?: ble.GattClientDevice;
  private enabledValue: boolean = false;
  private readonly statusCallback: (status: string, connected: boolean) => void;
  private readonly shutterCallback: () => void;

  private readonly scanCallback = (results: Array<ble.ScanResult>): void => {
    if (!this.enabledValue || this.client !== undefined || results.length === 0) {
      return;
    }
    try {
      ble.stopBLEScan();
      const client: ble.GattClientDevice =
        ble.createGattClientDevice(results[0].deviceId);
      this.client = client;
      client.on(
        'BLEConnectionStateChange',
        (state: ble.BLEConnectionChangeState): void => {
          this.handleConnectionState(state);
        }
      );
      client.on(
        'BLECharacteristicChange',
        (characteristic: ble.BLECharacteristic): void => {
          if (
            characteristic.characteristicUuid.toLowerCase() === SHUTTER_UUID &&
            isShutter(new Uint8Array(characteristic.characteristicValue))
          ) {
            this.statusCallback('已收到蓝牙快门', true);
            this.shutterCallback();
          }
        }
      );
      this.statusCallback('正在连接 ZENCHE Remote…', false);
      client.connect();
    } catch (error) {
      this.statusCallback(`蓝牙遥控连接失败：${(error as Error).message}`, false);
    }
  };

  constructor(
    statusCallback: (status: string, connected: boolean) => void,
    shutterCallback: () => void
  ) {
    this.statusCallback = statusCallback;
    this.shutterCallback = shutterCallback;
  }

  start(): void {
    this.enabledValue = true;
    this.statusCallback('正在搜索 ZENCHE 蓝牙遥控器…', false);
    try {
      ble.on('BLEDeviceFind', this.scanCallback);
      ble.startBLEScan([{ serviceUuid: SERVICE_UUID }]);
    } catch (error) {
      this.statusCallback(`蓝牙遥控不可用：${(error as Error).message}`, false);
    }
  }

  stop(): void {
    this.enabledValue = false;
    try {
      ble.off('BLEDeviceFind', this.scanCallback);
      ble.stopBLEScan();
    } catch (error) {
    }
    const client: ble.GattClientDevice | undefined = this.client;
    this.client = undefined;
    if (client !== undefined) {
      try {
        client.disconnect();
        client.close();
      } catch (error) {
      }
    }
    this.statusCallback('蓝牙遥控未开启', false);
  }

  private async handleConnectionState(
    state: ble.BLEConnectionChangeState
  ): Promise<void> {
    if (state.state === 2 && this.client !== undefined) {
      this.statusCallback('蓝牙遥控已连接', true);
      try {
        const services: Array<ble.GattService> = await this.client.getServices();
        const service: ble.GattService | undefined = services.find(
          (value: ble.GattService): boolean =>
            value.serviceUuid.toLowerCase() === SERVICE_UUID
        );
        const characteristic: ble.BLECharacteristic | undefined =
          service?.characteristics.find(
            (value: ble.BLECharacteristic): boolean =>
              value.characteristicUuid.toLowerCase() === SHUTTER_UUID
          );
        if (characteristic === undefined) {
          throw new Error('遥控器快门通道不可用');
        }
        await this.client.setCharacteristicChangeNotification(
          characteristic,
          true
        );
        this.statusCallback('蓝牙遥控已就绪', true);
      } catch (error) {
        this.statusCallback((error as Error).message, false);
      }
    } else if (state.state === 0) {
      this.client?.close();
      this.client = undefined;
      this.statusCallback(
        this.enabledValue ? '蓝牙遥控已断开，正在重连…' : '蓝牙遥控未开启',
        false
      );
      if (this.enabledValue) {
        setTimeout((): void => this.start(), 800);
      }
    }
  }
}

function isShutter(bytes: Uint8Array): boolean {
  if (bytes.length === 0) {
    return false;
  }
  return bytes.some((value: number): boolean => value !== 0);
}
