import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../../packages/edaya_shared/test/support/widget_failure_artifacts.dart';

class LiveApiWidgetTestBinding extends LiveTestWidgetsFlutterBinding {
  LiveApiWidgetTestBinding() {
    configureTeacherOutboxStoreFactory(InMemoryTeacherOutboxStore.new);
    installWidgetFailureArtifacts(this);
  }

  @override
  bool get overrideHttpClient => false;
}
