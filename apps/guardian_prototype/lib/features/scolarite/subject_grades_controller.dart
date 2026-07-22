import '../context/store_backed_controller.dart';

class SubjectGradesController extends StoreBackedController {
  SubjectGradesController(
    super.store, {
    required this.periodId,
    required this.subject,
  });

  final String periodId;
  final String subject;
}
