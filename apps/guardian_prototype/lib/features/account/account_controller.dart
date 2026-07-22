import '../context/store_backed_controller.dart';
import '../context/student_context_controller.dart';

class AccountController extends StoreBackedController {
  AccountController(super.store, {required this.studentContext});

  final StudentContextController studentContext;

  void signOut() => studentContext.signOut();
}
