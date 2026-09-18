import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edaya_teacher/app/teacher_app_root.dart';

void main() {
  setUp(() {
    Levit.reset();
    SharedPreferences.setMockInitialValues({});
    configureTeacherOutboxStoreFactory(InMemoryTeacherOutboxStore.new);
  });

  tearDown(() {
    configureTeacherOutboxStoreFactory(null);
  });

  testWidgets('teacher app bootstrap gate shows loading', (tester) async {
    await tester.pumpWidget(TeacherAppRoot());
    expect(find.byType(EdayaStartupScreen), findsOneWidget);
    expect(find.byType(EdayaBrandLogo), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
