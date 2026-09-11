import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index', (error): void => {
      if (error.code) { hilog.error(0x0000, 'FoldMotionDemo', 'Page loading failed: %{public}s', error.message); }
    });
  }
}
