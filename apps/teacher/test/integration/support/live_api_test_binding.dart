import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

class LiveApiWidgetTestBinding extends LiveTestWidgetsFlutterBinding {
  LiveApiWidgetTestBinding() {
    configureTeacherOutboxStoreFactory(InMemoryTeacherOutboxStore.new);
  }

  @override
  bool get overrideHttpClient => false;
}
