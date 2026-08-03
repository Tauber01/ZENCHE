import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * Uses HarmonyOS' native camera picker so system privacy indicators, lens
 * switching and capture UI remain owned by the OS. The returned JPEG is copied
 * into ZENCHE's existing capture workflow by the caller.
 */
export class LocalCameraController {
  async capture(context: common.UIAbilityContext): Promise<Uint8Array> {
    const profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
    };
    const result: cameraPicker.PickerResult = await cameraPicker.pick(
      context,
      [cameraPicker.PickerMediaType.PHOTO],
      profile
    );
    if (result.resultUri === undefined || result.resultUri.length === 0) {
      throw new Error('系统相机未返回照片');
    }
    const file = fs.openSync(result.resultUri, fs.OpenMode.READ_ONLY);
    try {
      const size: number = fs.statSync(file.fd).size;
      if (size <= 0) {
        throw new Error('系统相机返回了空照片');
      }
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      const count: number = fs.readSync(file.fd, buffer);
      if (count <= 0) {
        throw new Error('无法读取系统相机照片');
      }
      return new Uint8Array(buffer, 0, count);
    } finally {
      fs.closeSync(file);
    }
  }
}
