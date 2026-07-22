import '../context/store_backed_controller.dart';

class GradeDetailController extends StoreBackedController {
  GradeDetailController(super.store, {required this.gradeId});

  final String gradeId;
}
