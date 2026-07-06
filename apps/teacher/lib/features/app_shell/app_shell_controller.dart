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
      case 2:
        _appRouter.router.go('/teaching');
      case 3:
        _appRouter.router.go('/report-cards');
    }
  }

  int selectedIndexForLocation(String location) {
    if (location.startsWith('/report-cards')) {
      return 3;
    }
    if (location.startsWith('/teaching')) {
      return 2;
    }
    if (location.startsWith('/evaluations')) {
      return 1;
    }
    return 0;
  }
}
