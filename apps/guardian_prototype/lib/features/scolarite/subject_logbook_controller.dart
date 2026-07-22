import '../context/store_backed_controller.dart';

class SubjectLogbookController extends StoreBackedController {
  SubjectLogbookController(super.store, {required this.subject});

  final String subject;
}
