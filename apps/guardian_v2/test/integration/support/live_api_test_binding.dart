import 'package:flutter_test/flutter_test.dart';
import '../../../../../packages/edaya_shared/test/support/widget_failure_artifacts.dart';

/// Flutter test binding that allows real HTTP and real async for live API widget tests.
///
/// Must be constructed before [TestWidgetsFlutterBinding.ensureInitialized]
/// runs (i.e. as the first statement in `main`).
class LiveApiWidgetTestBinding extends LiveTestWidgetsFlutterBinding {
  LiveApiWidgetTestBinding() {
    installWidgetFailureArtifacts(this);
  }
  @override
  bool get overrideHttpClient => false;
}
