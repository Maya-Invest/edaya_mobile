import 'package:levit_flutter/levit_flutter.dart';

import '../../mock/mock_store.dart';

class StoreBoundController extends LevitController {
  StoreBoundController(this.store);

  final MockStore store;
  final storeTick = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(storeTick);
    store.addListener(() => storeTick.value++);
  }
}
