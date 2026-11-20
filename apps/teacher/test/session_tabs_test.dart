import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart'
    show AppLocalizations, FeatureActionBar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:edaya_teacher_v2/features/session/roll_call.dart';
import 'package:edaya_teacher_v2/features/session/attendance_draft_queue.dart';
import 'package:edaya_teacher_v2/features/session/logbook_page.dart';
import 'package:edaya_teacher_v2/features/session/live_session_controller.dart';
import 'integration/support/prototype_widget_test_harness.dart';
import 'integration/support/integration_test_lifecycle.dart';

Finder statusChip(String label) =>
    find.byWidgetPredicate((w) => w is ChoiceChip && w.tooltip == label);
Future<void> openActions(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton).hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'blocked finish explains the conflict and opens My profile from the action sheet',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: RollCall(
                rows: [
                  LiveSessionStudent(
                    studentId: 'ada',
                    fullName: 'Ada',
                    initials: 'A',
                    status: AttendanceStatus.present,
                  ),
                ],
                submitted: false,
                busy: false,
                pending: true,
                conflict: true,
                message: '',
                onSave: (_, _, _, _) async => true,
                onBulk: () async {},
                onFinish: () async => fail('blocked register submitted'),
                onSync: () async {},
                onMove: (_, _) async => false,
                windowOpen: false,
                schoolTime: (date) => date,
              ),
            ),
          ),
          GoRoute(
            path: '/account',
            builder: (_, _) =>
                const Scaffold(body: Text('Account destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await openActions(tester);
      final finish = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Finish roll call'),
      );
      expect(finish.enabled, isFalse);
      expect((finish.subtitle as Text).data, contains('My profile'));
      await tester.tap(find.widgetWithText(ListTile, 'My profile'));
      await tester.pumpAndSettle();
      expect(find.text('Account destination'), findsOneWidget);
    },
  );

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
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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
      await openActions(tester);
      await tester.tap(find.text('Un élève à la fois'));
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
      tester.view.physicalSize = const Size(1024, 768);
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
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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
        matching: statusChip(status),
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
      expect(
        tester
            .widget<FeatureActionBar>(find.byType(FeatureActionBar))
            .actions
            .singleWhere((a) => a.label == 'Terminer l’appel')
            .subtitle,
        '2/3 renseignés',
      );
      first.complete(true);
      await tester.pump();
      expect(sent, ['Ada', 'Sam']);
      second.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip('Ada', 'Présent')).selected, true);
      expect(tester.widget<ChoiceChip>(chip('Sam', 'Absent')).selected, false);
      expect(
        tester
            .widget<FeatureActionBar>(find.byType(FeatureActionBar))
            .actions
            .singleWhere((a) => a.label == 'Terminer l’appel')
            .subtitle,
        '1/3 renseignés',
      );
      expect(tester.widget<ChoiceChip>(other), same(originalChip));
      expect(tester.getTopLeft(other), originalPosition);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the pupil sheet fits its contents and Save stays reachable above the keyboard',
    (tester) async {
      const viewport = Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
      final lesson = h.store.sessions.firstWhere(
        (s) => !s.attendanceComplete && h.store.getAttendance(s.id).isNotEmpty,
      );
      await tester.pumpWidget(h.buildApp(locale: const Locale('fr')));
      h.router.go('/session/${lesson.id}');
      await tester.pumpAndSettle();
      final entry = h.store.getAttendance(lesson.id).first;
      final pupil = h.store.studentById(entry.studentId)!;
      await tester.tap(find.byTooltip(pupil.fullName));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(tester.getSize(sheet).height, lessThan(viewport.height * .65));
      final field = find.byType(TextFormField).last;
      final save = find.widgetWithText(FilledButton, 'Enregistrer');
      expect(
        tester.getTopLeft(save).dy - tester.getBottomLeft(field).dy,
        closeTo(12, 1),
      );
      await tester.tap(
        find.descendant(of: sheet, matching: statusChip('Présent')),
      );
      await tester.enterText(field, 'En classe');
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(save).dy,
        lessThanOrEqualTo(viewport.height - 340),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(entry.status, AttendanceStatus.present);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const [
    Size(390, 844),
    Size(599, 844),
    Size(600, 844),
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
          final progress = find.text(
            labels.rollRosterCount(h.store.getAttendance(lesson.id).length, 0),
          );
          if (viewport.width < 600) {
            expect(progress, findsNothing);
            await openActions(tester);
            expect(progress, findsOneWidget);
            Navigator.of(tester.element(progress)).pop();
            await tester.pumpAndSettle();
          } else {
            expect(
              find.descendant(
                of: find.byType(FilledButton),
                matching: progress,
              ),
              findsOneWidget,
            );
          }
          final picker = find.byType(AttendanceStatusPicker).first;
          final present = find.descendant(
            of: picker,
            matching: statusChip(labels.attendancePresent),
          );
          final absent = find.descendant(
            of: picker,
            matching: statusChip(labels.attendanceAbsent),
          );
          expect(tester.getSize(present).height, greaterThanOrEqualTo(48));
          expect(tester.widget<ChoiceChip>(present).selected, isFalse);
          await tester.ensureVisible(present);
          await tester.pumpAndSettle();
          await tester.tap(present);
          await tester.pumpAndSettle();
          expect(firstRow.status, AttendanceStatus.present);
          expect(tester.widget<ChoiceChip>(present).selected, true);
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
          if (viewport.width < 600 &&
              !tester.any(find.text(labels.bookAddChapter)))
            await openActions(tester);
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

      if (viewport.width < 600) await openActions(tester);
      await tap(find.text('Un élève à la fois'));
      expect(find.text('1 sur ${rows.length}'), findsOneWidget);
      await tap(find.byIcon(Icons.chevron_right).last);
      expect(find.text('2 sur ${rows.length}'), findsOneWidget);
      await tap(find.widgetWithText(Tab, 'Cahier de texte'));
      await tap(find.widgetWithText(Tab, 'Appel'));
      expect(find.text('2 sur ${rows.length}'), findsOneWidget);
      await tap(find.text('Absent'));
      expect(rows[1].status, AttendanceStatus.absent);
      for (var i = 2; i < rows.length; i++) {
        await tester.pump(const Duration(milliseconds: 320));
        await tap(find.text('Présent'));
      }
      if (viewport.width < 600) await openActions(tester);
      expect(find.text('Un élève à la fois'), findsOneWidget);
      expect(rows.first.status, isNull);
      if (viewport.width < 600) {
        expect(
          tester
              .widget<ListTile>(
                find.widgetWithText(ListTile, 'Terminer l’appel'),
              )
              .enabled,
          isFalse,
        );
      } else {
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Terminer l’appel'),
              )
              .onPressed,
          isNull,
        );
      }
      await tap(find.text('Marquer les élèves restants présents'));
      expect(rows[1].status, AttendanceStatus.absent);
      expect(s.attendanceComplete, isFalse);
      if (viewport.width < 600) await openActions(tester);
      await tap(find.text('Terminer l’appel'));
      expect(s.attendanceComplete, isTrue);
      await tap(find.widgetWithText(Tab, 'Cahier de texte'));
      if (viewport.width < 600) {
        final create = find.text('Créer une entrée');
        if (!tester.any(create)) await openActions(tester);
        await tap(create);
      } else {
        await tap(find.byIcon(Icons.edit_outlined));
      }
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
