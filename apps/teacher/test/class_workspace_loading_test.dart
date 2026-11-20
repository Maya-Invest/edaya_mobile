import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_v2/features/teaching/live_class_workspace_controller.dart';
import 'package:edaya_teacher_v2/features/teaching/teaching_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Context implements TeacherContextController {
  @override
  final teacherId = LxVar<String?>('teacher');
  @override
  final activeAssignmentId = LxVar<String?>('assignment');
  @override
  final selection = const TeacherWorkspaceSelection(
    schoolId: 'school',
    academicYearId: 'year',
    classGroupId: 'class',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements api.Transport {
  final lessons = <String, Completer<Map<String, dynamic>>>{};
  final chapterReads = <String>[];
  final queries = <Map<String, String>>[];
  final aborted = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final body = options?.body as Map?;
    final offering = body?['classSubjectId'] as String?;
    if (path.contains('/class-subjects/')) {
      return {'id': path.split('/').last, 'chapterCount': 1} as T;
    }
    if (path.endsWith('/class-subject-matters/list')) {
      chapterReads.add(offering!);
      return [
            {'id': 'link', 'subjectMatterId': 'chapter'},
          ]
          as T;
    }
    if (path.endsWith('/subject-matters/list')) {
      return [
            {'id': 'chapter', 'name': 'Fractions'},
          ]
          as T;
    }
    if (Uri.parse(path).path.endsWith('/teacher/logbook')) {
      final result = Completer<Map<String, dynamic>>();
      final params = Uri.parse(path).queryParameters;
      queries.add(params);
      final key = [params['classSubjectId'], params['cursor']].join('/');
      options!.abortTrigger!.then((_) => aborted.add(key));
      lessons[params['classSubjectId']!] = result;
      return await result.future as T;
    }
    throw StateError('Unexpected request $path');
  }
}

void main() {
  testWidgets(
    'progress renders independently, stale failures are ignored and revoked access clears the panel',
    (tester) async {
      final transport = _Transport();
      final c = LiveClassWorkspaceController(
        classGroupId: 'class',
        teacherContext: _Context(),
        schoolClient: () => api.createSchoolClient(transport),
      );
      addTearDown(c.onClose);
      c.classSubjectOptions([
        for (final id in ['one', 'two'])
          TeachingClassSubjectOption(
            id: id,
            classGroupId: 'class',
            subjectName: id,
            classLabel: 'Class',
          ),
      ]);
      final first = c.selectSubject('one');
      await tester.pump();
      expect(c.progressOverview.value?.matters.single.name, 'Fractions');
      final second = c.selectSubject('two');
      expect(c.progressOverview.value, isNull);
      await tester.pump();
      transport.lessons['one']!.completeError(api.ApiError(403, 'Old scope'));
      await first;
      expect(c.errorMessage.value, isEmpty);
      expect(c.progressOverview.value?.matters.single.name, 'Fractions');
      transport.lessons['two']!.completeError(api.ApiError(503, 'Unavailable'));
      await second;
      expect(c.errorMessage.value, isNotEmpty);
      expect(c.progressOverview.value?.matters.single.name, 'Fractions');
      final retry = c.loadTeachingData();
      await tester.pump();
      expect(c.errorMessage.value, isEmpty);
      transport.lessons['two']!.completeError(api.ApiError(403, 'Revoked'));
      await retry;
      expect(c.progressOverview.value, isNull);
      expect(c.logbookEntries.value, isEmpty);
      expect(c.errorMessage.value, isNotEmpty);
      expect(transport.chapterReads, ['one', 'two', 'two']);
    },
  );
  testWidgets(
    'logbook can continue, retry, cancel and refresh a selection after a save',
    (tester) async {
      final transport = _Transport();
      final c = LiveClassWorkspaceController(
        classGroupId: 'class',
        teacherContext: _Context(),
        schoolClient: () => api.createSchoolClient(transport),
      );
      c.classSubjectOptions([
        for (final id in ['one', 'two'])
          TeachingClassSubjectOption(
            id: id,
            classGroupId: 'class',
            subjectName: id,
            classLabel: 'Class',
          ),
      ]);
      Map<String, dynamic> page(List<String> ids, String? next) => {
        'items': [
          for (final id in ids)
            {
              'id': id,
              'displayLabel': 'Lesson $id',
              'startsAt': '2026-02-01T10:00:00Z',
              'recorded': true,
            },
        ],
        'nextCursor': next,
      };
      final initial = c.selectSubject('one');
      await tester.pump();
      transport.lessons['one']!.complete(page(['3', '2'], 'next'));
      await initial;
      final more = c.loadMoreLogbook();
      await c.loadMoreLogbook();
      expect(
        transport.queries.where((q) => q['cursor'] == 'next'),
        hasLength(1),
      );
      transport.lessons['one']!.completeError(api.ApiError(503, 'Busy'));
      await more;
      expect(c.logbookPageError.value, isNotEmpty);
      expect(c.nextLogbookCursor.value, 'next');
      expect(c.logbookEntries.value.map((e) => e.lessonSessionId), ['3', '2']);
      final retry = c.loadMoreLogbook();
      transport.lessons['one']!.complete(page(['2', '1'], 'last'));
      await retry;
      expect(c.logbookPageError.value, isEmpty);
      expect(c.logbookEntries.value.map((e) => e.lessonSessionId), [
        '3',
        '2',
        '1',
      ]);
      final old = c.loadMoreLogbook();
      final current = c.selectSubject('two');
      await tester.pump();
      expect(transport.aborted, contains('one/last'));
      expect(c.logbookEntries.value, isEmpty);
      transport.lessons['two']!.complete(page(['7'], null));
      transport.lessons['one']!.completeError(api.ApiError(403, 'Old scope'));
      await Future.wait([old, current]);
      expect(c.errorMessage.value, isEmpty);
      expect(c.logbookEntries.value.single.lessonSessionId, '7');
      final refresh = c.loadTeachingData();
      await tester.pump();
      transport.lessons['two']!.complete(page(['8', '7'], 'later'));
      await refresh;
      expect(c.logbookEntries.value.first.lessonSessionId, '8');
      final denied = c.loadMoreLogbook();
      transport.lessons['two']!.completeError(
        api.ApiError(403, 'Ended assignment'),
      );
      await denied;
      expect(c.logbookEntries.value, isEmpty);
      expect(c.progressOverview.value, isNull);
      expect(c.nextLogbookCursor.value, isNull);
      expect(transport.queries.every((q) => q['view'] == 'recorded'), isTrue);
      c.onClose();
    },
  );
}
