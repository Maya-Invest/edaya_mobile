import 'package:levit_flutter/levit_flutter.dart';

import '../../mock/mock_store.dart';

/// Base for route controllers that read reactive mock data.
abstract class StoreBackedController extends LevitController {
  StoreBackedController(this.store);

  final MockStore store;
  final storeTick = LxVar(0);

  @override
  void onInit() {
    super.onInit();
    autoDispose(storeTick);
    store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() => storeTick.value++;

  @override
  void onClose() {
    store.removeListener(_onStoreChanged);
    super.onClose();
  }
}
