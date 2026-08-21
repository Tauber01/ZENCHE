import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'NikonLink', 'HarmonyOS ability created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(
          0x0000,
          'NikonLink',
          `Failed to load main page: ${error.code} ${error.message}`
        );
      }
    });
  }

  onForeground(): void {
    // 回到前台的时间戳：Index 页通过 @StorageLink 监听后立刻补跑一次
    // Wi-Fi 心跳探测，校验后台期间链路是否仍存活。
    AppStorage.setOrCreate('zencheForegroundAt', Date.now());
  }

}
