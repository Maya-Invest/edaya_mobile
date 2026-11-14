import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart' show AppLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:edaya_teacher_v2/features/session/roll_call.dart';
import 'package:edaya_teacher_v2/features/session/attendance_draft_queue.dart';
import 'package:edaya_teacher_v2/features/session/logbook_page.dart';
import 'package:edaya_teacher_v2/features/session/live_session_controller.dart';
import 'integration/support/prototype_widget_test_harness.dart';
import 'integration/support/integration_test_lifecycle.dart';

void main() {
  testWidgets(
    'photo pass stays on a rejected write and advances only once across a resize',
    (tester) async {
      final rows = [
        for (final name in ['Ada', 'Sam'])
          LiveSessionStudent(
            studentId: name,
            fullName: name,
            initials: name[0],
          ),
      ];
      var write = Completer<bool>();
      final requests = <String>[];
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: RollCall(
              rows: rows,
              submitted: false,
              busy: false,
              pending: false,
              message: '',
              onSave: (row, status, comment, reason) {
                requests.add(row.studentId);
                return write.future;
              },
              onBulk: () async {},
              onFinish: () async {},
              onSync: () async {},
              onMove: (_, _) async => false,
              windowOpen: false,
              schoolTime: (date) => date,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mode photo'));
      await tester.pumpAndSettle();
      final mark = find.text('Présent');
      await tester.tap(mark);
      await tester.tap(mark);
      expect(requests, ['Ada']);
      write.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('1 sur 2'), findsOneWidget);
      write = Completer<bool>();
      await tester.tap(mark);
      write.complete(true);
      await tester.pump();
      await tester.tap(mark);
      expect(requests, ['Ada', 'Ada']);
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpAndSettle();
      expect(find.text('2 sur 2'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('1 sur 2'), findsOneWidget);
      expect(requests, ['Ada', 'Ada']);
    },
  );
  testWidgets(
    'a delayed roster save leaves other pupils stable and accepts the next tap',
    (tester) async {
      final pupils = [
        for (final name in ['Ada', 'Sam', 'Eli'])
          LiveSessionStudent(
            studentId: name,
            fullName: name,
            initials: name[0],
          ),
      ];
      final queue = AttendanceDraftQueue();
      final first = Completer<bool>(), second = Completer<bool>();
      final sent = <String>[];
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) => RollCall(
                rows: List.of(pupils),
                busy: false,
                submitted: false,
                pending: false,
                savingDraft: queue.writing.value,
                message: '',
                windowOpen: false,
                schoolTime: (date) => date,
                onSave: (row, status, _, _) async {
                  final result = queue.add(() async {
                    sent.add(row.studentId);
                    final accepted =
                        await (sent.length == 1 ? first : second).future;
                    if (accepted) {
                      final i = pupils.indexWhere(
                        (p) => p.studentId == row.studentId,
                      );
                      update(
                        () => pupils[i] = pupils[i].copyWith(status: status),
                      );
                    }
                    return accepted;
                  }, active: () => true);
                  update(() {});
                  try {
                    return await result;
                  } finally {
                    update(() {});
                  }
                },
                onFinish: () async {},
                onBulk: () async {},
                onSync: () async {},
                onMove: (_, _) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder chip(String name, String status) => find.descendant(
        of: find.byKey(ValueKey(name)),
        matching: find.widgetWithText(ChoiceChip, status),
      );
      final other = chip('Eli', 'Présent');
      final originalChip = tester.widget<ChoiceChip>(other);
      final originalPosition = tester.getTopLeft(other);
      await tester.tap(chip('Ada', 'Présent'));
      await tester.pump();
      expect(tester.widget<ChoiceChip>(chip('Ada', 'Présent')).selected, true);
      expect(sent, ['Ada']);
      expect(tester.widget<ChoiceChip>(other), same(originalChip));
      expect(
        tester.widget<ChoiceChip>(chip('Sam', 'Absent')).onSelected,
        isNotNull,
      );
      await tester.tap(chip('Sam', 'Absent'));
      await tester.pump();
      expect(sent, ['Ada']);
      expect(tester.widget<ChoiceChip>(chip('Sam', 'Absent')).selected, true);
      expect(find.text('2/3 renseignés'), findsOneWidget);
      first.complete(true);
      await tester.pump();
      expect(sent, ['Ada', 'Sam']);
      second.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip('Ada', 'Présent')).selected, true);
      expect(tester.widget<ChoiceChip>(chip('Sam', 'Absent')).selected, false);
      expect(find.text('1/3 renseignés'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(other), same(originalChip));
      expect(tester.getTopLeft(other), originalPosition);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const [
    Size(390, 844),
    Size(768, 1024),
    Size(1024, 768),
    Size(320, 844),
  ]) {
    for (final language in ['fr', 'en']) {
      testWidgets(
        'register chips and chapter sections at ${viewport.width} in $language',
        (tester) async {
          final dark = language == 'en';
          final h = PrototypeWidgetTestHarness()
            ..bootstrap(authenticated: true);
          final lesson = h.store.sessions.firstWhere(
            (s) => !s.attendanceComplete && !s.logbookComplete,
          );
          await tester.binding.setSurfaceSize(viewport);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            return tester.binding.setSurfaceSize(null);
          });
          await tester.pumpWidget(
            h.buildApp(
              locale: Locale(language),
              textScale: viewport.width == 320 ? 2 : 1,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            ),
          );
          h.router.go('/session/${lesson.id}');
          await tester.pumpAndSettle();
          final firstRow = h.store.getAttendance(lesson.id).first;
          final labels = AppLocalizations.of(
            tester.element(find.byType(RollCall)),
          )!;
          expect(
            find.text(
              labels.rollRosterCount(
                h.store.getAttendance(lesson.id).length,
                0,
              ),
            ),
            findsOneWidget,
          );
          final picker = find.byType(AttendanceStatusPicker).first;
          final present = find.descendant(
            of: picker,
            matching: find.widgetWithText(ChoiceChip, labels.attendancePresent),
          );
          final absent = find.descendant(
            of: picker,
            matching: find.widgetWithText(ChoiceChip, labels.attendanceAbsent),
          );
          expect(tester.getSize(present).height, greaterThanOrEqualTo(48));
          expect(tester.widget<ChoiceChip>(present).selected, isFalse);
          await tester.ensureVisible(present);
          await tester.pumpAndSettle();
          await tester.tap(present);
          await tester.pumpAndSettle();
          expect(firstRow.status, AttendanceStatus.present);
          expect(tester.widget<ChoiceChip>(present).showCheckmark, true);
          final green = tester.widget<ChoiceChip>(present).selectedColor;
          await tester.ensureVisible(absent);
          await tester.pumpAndSettle();
          await tester.tap(absent);
          await tester.pumpAndSettle();
          expect(firstRow.status, AttendanceStatus.absent);
          expect(tester.widget<ChoiceChip>(absent).selectedColor, isNot(green));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, isNotNull);
          await tester.tap(find.widgetWithText(Tab, labels.logbook));
          await tester.pumpAndSettle();
          expect(find.text(labels.bookGeneral), findsOneWidget);
          expect(find.text(labels.bookChapters), findsOneWidget);
          final add = find.text(labels.bookAddChapter);
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final size in [
    DesignReviewFormFactor.phone,
    DesignReviewFormFactor.medium,
    DesignReviewFormFactor.tablet,
  ]) {
    testWidgets('session tabs, photo pass and editor on ${size.name}', (
      tester,
    ) async {
      final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
      final s = h.store.sessions.firstWhere(
        (s) => !s.attendanceComplete && h.store.getAttendance(s.id).length > 1,
      );
      final viewport = switch (size) {
        DesignReviewFormFactor.phone => const Size(390, 844),
        DesignReviewFormFactor.medium => const Size(768, 1024),
        DesignReviewFormFactor.tablet => const Size(1024, 768),
      };
      await configureDesignReviewViewport(tester, size);
      await tester.binding.setSurfaceSize(viewport);
      tester.view.physicalSize = viewport;
      h.viewportSize = viewport;
      await tester.pumpWidget(h.designReviewRoot(child: h.buildApp()));
      await tester.pump();
      h.router.go('/calendar/lesson/${s.id}');
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(RollCall), findsOneWidget);
      final rows = h.store.getAttendance(s.id);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Mode photo'));
      expect(find.text('1 sur ${rows.length}'), findsOneWidget);
      await tap(find.byIcon(Icons.chevron_right).last);
      expect(find.text('2 sur ${rows.length}'), findsOneWidget);
      await tap(find.widgetWithText(Tab, 'Cahier de texte'));
      await tap(find.widgetWithText(Tab, 'Appel'));
      expect(find.text('2 sur ${rows.length}'), findsOneWidget);
      await tap(find.text('Absent'));
      expect(rows[1].status, AttendanceStatus.absent);
      for (var i = 2; i < rows.length; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 320)),
        );
        await tap(find.text('Présent'));
      }
      expect(find.text('Mode photo'), findsOneWidget);
      expect(rows.first.status, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Terminer'))
            .onPressed,
        isNull,
      );
      await tap(find.text('Restants présents'));
      expect(rows[1].status, AttendanceStatus.absent);
      expect(s.attendanceComplete, isFalse);
      await tap(find.text('Terminer'));
      expect(s.attendanceComplete, isTrue);
      await tap(find.widgetWithText(Tab, 'Cahier de texte'));
      final edit = find.byIcon(Icons.edit_outlined);
      await tap(edit);
      expect(find.byType(BottomSheet), findsOneWidget);
      final input = find.byType(TextField).first;
      await tester.enterText(input, 'Test du cahier');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(find.text('Enregistrer'));
      expect(h.store.getLogbook(s.id)?.content, 'Test du cahier');
      expect(find.byType(LogbookForm), findsNothing);
      expect(find.text('Test du cahier'), findsOneWidget);
      h.router.go('/progress/cahier/${s.id}');
      await tester.pumpAndSettle();
      expect(find.text('Test du cahier'), findsOneWidget);
    });
  }
}
