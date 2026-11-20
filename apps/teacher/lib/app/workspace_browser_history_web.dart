import 'dart:async';
import 'package:web/web.dart' as web;

bool get canGoBack => web.window.history.length > 1;

Future<void> goBack() async {
  final popped = Completer<void>();
  final subscription = web.window.onPopState.listen((_) {
    if (!popped.isCompleted) popped.complete();
  });
  try {
    web.window.history.back();
    await popped.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  } finally {
    await subscription.cancel();
  }
}
