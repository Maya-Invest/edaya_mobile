import 'package:levit_flutter/levit_flutter.dart';

class PrototypeShellController extends LevitController {
  final lastTabIndex = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(lastTabIndex);
  }

  void rememberTab(int index) {
    if (lastTabIndex.value != index) {
      lastTabIndex(index);
    }
  }
}
