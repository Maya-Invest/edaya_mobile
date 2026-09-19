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
        _appRouter.router.go('/academic');
      case 2:
        _appRouter.router.go('/evaluations');
      case 3:
        _appRouter.router.go('/fees');
      case 4:
        _appRouter.router.go('/inbox');
    }
  }

  int selectedIndexForLocation(String location) {
    if (location.startsWith('/calendar')) {
      return 0;
    }
    if (location.startsWith('/academic') || location.startsWith('/documents')) {
      return 1;
    }
    if (location.startsWith('/evaluations')) {
      return 2;
    }
    if (location.startsWith('/fees')) {
      return 3;
    }
    if (location.startsWith('/inbox')) {
      return 4;
    }
    return 0;
  }
}
