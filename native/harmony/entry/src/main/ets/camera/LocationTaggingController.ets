import { geoLocationManager } from '@kit.LocationKit';
import { CaptureLocationMetadata } from '../workflow/CaptureWorkflow';

export class CaptureLocation implements CaptureLocationMetadata {
  readonly latitude: number;
  readonly longitude: number;
  readonly altitude: number;
  readonly accuracy: number;
  readonly timestamp: number;

  constructor(location: geoLocationManager.Location) {
    this.latitude = location.latitude;
    this.longitude = location.longitude;
    this.altitude = location.altitude;
    this.accuracy = location.accuracy;
    this.timestamp = location.timeStamp;
  }
}

export class LocationTaggingController {
  private enabledValue: boolean = false;
  private latest?: CaptureLocation;
  private readonly statusCallback: (status: string) => void;

  constructor(statusCallback: (status: string) => void) {
    this.statusCallback = statusCallback;
  }

  setEnabled(enabled: boolean): void {
    this.enabledValue = enabled;
    if (enabled) {
      this.refresh();
    } else {
      this.latest = undefined;
      this.statusCallback('定位未开启');
    }
  }

  async refresh(): Promise<void> {
    if (!this.enabledValue) {
      return;
    }
    this.statusCallback('正在获取位置…');
    try {
      const location: geoLocationManager.Location =
        await geoLocationManager.getCurrentLocation();
      this.latest = new CaptureLocation(location);
      this.statusCallback(`定位就绪 · ±${Math.round(location.accuracy)} m`);
    } catch (error) {
      this.statusCallback(`定位失败：${(error as Error).message}`);
    }
  }

  snapshot(): CaptureLocation | undefined {
    if (
      !this.enabledValue ||
      this.latest === undefined ||
      Date.now() - this.latest.timestamp > 120000
    ) {
      return undefined;
    }
    return this.latest;
  }
}
