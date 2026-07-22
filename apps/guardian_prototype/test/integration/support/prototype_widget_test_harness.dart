import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_prototype/app/router.dart';
import 'package:guardian_prototype/main.dart';
import 'package:guardian_prototype/mock/mock_store.dart';

import 'design_review_capture.dart';

class PrototypeWidgetTestHarness {
  PrototypeWidgetTestHarness();

  late MockStore store;
  late GoRouter router;
  Size? viewportSize;

  void bootstrap({required bool authenticated}) {
    store = MockStore();
    if (authenticated) {
      store.signIn();
    } else {
      store.signOut();
    }
    router = createRouter(store);
  }

  Widget designReviewRoot({required Widget child}) {
    final framed = viewportSize == null
        ? child
        : SizedBox(
            width: viewportSize!.width,
            height: viewportSize!.height,
            child: child,
          );
    return RepaintBoundary(
      key: designReviewRootKey,
      child: framed,
    );
  }

  Widget buildApp() {
    return GuardianPrototypeApp(store: store, router: router);
  }
}
