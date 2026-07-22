import '../context/store_backed_controller.dart';

class ReportCardController extends StoreBackedController {
  ReportCardController(super.store, {required this.reportCardId});

  final String reportCardId;
}
