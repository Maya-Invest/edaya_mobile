import '../context/store_backed_controller.dart';

class FeeDetailController extends StoreBackedController {
  FeeDetailController(super.store, {required this.feeId});

  final String feeId;
}
