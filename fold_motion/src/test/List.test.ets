import foldMotionModelTest from './FoldMotionModel.test';
import foldMotionDirectionModelTest from './FoldMotionDirectionModel.test';

export default function testsuite(): void {
  foldMotionModelTest();
  foldMotionDirectionModelTest();
}
