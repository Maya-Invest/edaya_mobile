import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_teacher/app/teacher_app_root.dart';

void main() {
  setUp(() {
    Levit.reset();
  });

  testWidgets('teacher app bootstrap gate shows loading', (tester) async {
    await tester.pumpWidget(TeacherAppRoot());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
