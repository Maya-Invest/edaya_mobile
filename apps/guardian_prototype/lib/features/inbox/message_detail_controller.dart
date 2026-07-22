import '../context/store_backed_controller.dart';

class MessageDetailController extends StoreBackedController {
  MessageDetailController(super.store, {required this.messageId});

  final String messageId;

  @override
  void onInit() {
    super.onInit();
    store.markMessageRead(messageId);
  }
}
