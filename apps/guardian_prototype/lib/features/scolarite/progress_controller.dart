import 'package:levit_flutter/levit_flutter.dart';

import '../context/store_backed_controller.dart';

class ProgressController extends StoreBackedController {
  ProgressController(super.store);

  final expandedSubjectIds = LxVar<Set<String>>({});

  @override
  void onInit() {
    super.onInit();
    autoDispose(expandedSubjectIds);
  }

  void toggleSubject(String subject) {
    final next = Set<String>.from(expandedSubjectIds.value);
    if (next.contains(subject)) {
      next.remove(subject);
    } else {
      next.add(subject);
    }
    expandedSubjectIds.value = next;
  }
}
