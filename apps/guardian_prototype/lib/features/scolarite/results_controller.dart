import 'package:levit_flutter/levit_flutter.dart';

import '../../mock/mock_store.dart';
import '../context/store_backed_controller.dart';

class ResultsController extends StoreBackedController {
  ResultsController(super.store);

  late final expandedPeriodIds = LxVar<Set<String>>({
    for (final period in store.academicPeriods)
      if (period.status == MockPeriodStatus.open) period.id,
  });

  @override
  void onInit() {
    super.onInit();
    autoDispose(expandedPeriodIds);
  }

  void togglePeriod(String periodId) {
    final next = Set<String>.from(expandedPeriodIds.value);
    if (next.contains(periodId)) {
      next.remove(periodId);
    } else {
      next.add(periodId);
    }
    expandedPeriodIds.value = next;
  }
}
