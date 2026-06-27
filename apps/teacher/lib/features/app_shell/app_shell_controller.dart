import 'package:levit_flutter/levit_flutter.dart';

import '../../app/router.dart';

class AppShellController extends LevitController {
  AppShellController({required AppRouter appRouter}) : _appRouter = appRouter;

  final AppRouter _appRouter;

  void onDestinationSelected(int index) {
    switch (index) {
      case 0:
        _appRouter.router.go('/calendar');
      case 1:
        _appRouter.router.go('/evaluations');
    }
  }

  int selectedIndexForLocation(String location) {
    if (location.startsWith('/evaluations')) {
      return 1;
    }
    return 0;
  }
}
