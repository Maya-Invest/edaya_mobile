import '../context/store_backed_controller.dart';

class HomeController extends StoreBackedController {
  HomeController(super.store);

  void openCalendarDay(int dayOffset) {
    store.selectCalendarDayOffset(dayOffset);
  }
}
