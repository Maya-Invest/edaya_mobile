import '../context/store_backed_controller.dart';

class PaymentDetailController extends StoreBackedController {
  PaymentDetailController(super.store, {required this.paymentId});

  final String paymentId;
}
