import 'package:flutter_test/flutter_test.dart';

/// Flutter test binding that allows real HTTP and real async for live API widget tests.
///
/// Must be constructed before [TestWidgetsFlutterBinding.ensureInitialized]
/// runs (i.e. as the first statement in `main`).
class LiveApiWidgetTestBinding extends LiveTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}
