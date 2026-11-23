part of 'demo_school.dart';

extension DemoReportRoster on DemoSchool {
  Row classReportRoster(Row input) {
    final group = input['classGroupId'], period = input['periodId'];
    final scope = {'schoolId': DemoSchool.school, 'academicYearId': year};
    final assignments = matching('teacher-assignments', {
      ...scope,
      'classGroupId': group,
      'teacherId': actor,
      'status': 'active',
    });
    if (!teacher ||
        assignments.isEmpty ||
        matching('academic-periods', {...scope, 'id': period}).isEmpty) {
      throw ApiError(403, 'Report roster unavailable');
    }
    final homeroom = assignments.any((a) => a['kind'] == 'homeroom');
    final subjects = {
      for (final a in assignments)
        if (a['kind'] == 'subject') a['classSubjectId'] as String,
    };
    final view = input['view'] ?? 'roster', status = input['status'];
    final query = (input['q'] as String? ?? '').trim();
    final search = query.toLowerCase();
    if (!['roster', 'summary'].contains(view) ||
        ![null, 'none', 'draft', 'published'].contains(status) ||
        query.length > 200) {
      throw ApiError(400, 'Invalid report roster query');
    }

    final reports = matching('results', {
      ...scope,
      'classGroupId': group,
      'periodId': period,
    });
    final byStudent = <String, Row>{};
    final missingValues = <String>{}, missingGrading = <String>{};
    var published = 0, complete = 0, remaining = 0;
    for (final report in reports) {
      final student = report['studentId'] as String;
      final summary = _summarizeReport(
        report,
        homeroom: homeroom,
        taughtSubjects: subjects,
      );
      if (summary.missingValues) missingValues.add(student);
      if (summary.missingGrading) missingGrading.add(student);
      if (report['status'] == 'published') published++;
      if (summary.remaining == 0) complete++;
      remaining += summary.remaining;
      final previous = byStudent[student];
      if (previous == null ||
          (report['id'] as String).compareTo(previous['id']) > 0) {
        byStudent[student] = summary.header;
      }
    }

    final selection = [
      actor,
      year,
      group,
      period,
      view,
      status,
      query,
      homeroom,
      ...subjects.toList()..sort(),
    ];
    final pupils = <Row>[];
    if (view == 'roster') {
      final enrolled = matching('enrollments', {
        ...scope,
        'classGroupId': group,
        'status': 'active',
      }).map((e) => e['studentId']).toSet();
      for (final pupil in matching('students', {
        'schoolId': DemoSchool.school,
      })) {
        final id = pupil['id'] as String;
        if (!enrolled.contains(id)) continue;
        final report = byStudent[id];
        final name = '${pupil['firstName'] ?? ''} ${pupil['lastName'] ?? ''}'
            .trim();
        final label = name.isEmpty ? id : name;
        if ((status != null && status != (report?['status'] ?? 'none')) ||
            !label.toLowerCase().contains(search)) {
          continue;
        }
        pupils.add({
          'studentId': id,
          'studentName': label,
          'photoUrl': pupil['photoUrl'],
          'report': report,
        });
      }
    }
    pupils.sort((a, b) {
      final name = (a['studentName'] as String).compareTo(b['studentName']);
      return name != 0
          ? name
          : (a['studentId'] as String).compareTo(b['studentId']);
    });
    String cursorFor(Row pupil) =>
        jsonEncode([...selection, pupil['studentName'], pupil['studentId']]);
    final cursor = input['cursor'];
    final start = cursor == null
        ? 0
        : pupils.indexWhere((p) => cursorFor(p) == cursor) + 1;
    if (cursor != null && start == 0) {
      throw ApiError(400, 'Invalid report roster cursor');
    }
    final items = pupils.skip(start).take(30).toList();
    return {
      'totals': {
        'generatedCount': reports.length,
        'publishedCount': published,
        'commentFilledCount': complete,
        'remainingFields': remaining,
      },
      'items': items,
      'matchedPupils': pupils.length,
      'missingValues': pupils.any(
        (p) => missingValues.contains(p['studentId']),
      ),
      'missingGrading': pupils.any(
        (p) => missingGrading.contains(p['studentId']),
      ),
      'nextCursor': start + items.length < pupils.length
          ? cursorFor(items.last)
          : null,
    };
  }
}

({Row header, int remaining, bool missingValues, bool missingGrading})
_summarizeReport(
  Row report, {
  required bool homeroom,
  required Set<String> taughtSubjects,
}) {
  bool hasText(dynamic value) => value is String && value.trim().isNotEmpty;
  final average = report['overallAverage'] ?? report['average'];
  final rank = report['rank'] as int?, size = report['classSize'] as int?;
  var missingValues = rank == null || rank < 1 || size == null || size < rank;
  var missingGrading = false;
  void checkGrade(Row row, dynamic value) {
    if (row['grading'] != null) return;
    if (value == null) {
      missingValues = true;
    } else {
      missingGrading = true;
    }
  }

  checkGrade(report, average);
  final hasComment = hasText(report['teacherComment']);
  var remaining = homeroom && !hasComment ? 1 : 0;
  for (final section in _reportSections(report)) {
    final requiresComment = switch (section['sectionKind']) {
      'subject' => taughtSubjects.contains(section['classSubjectId']),
      'module' => homeroom,
      _ => false,
    };
    if (requiresComment && !hasText(section['comment'])) remaining++;
    if (section['classSubjectId'] != null ||
        _reportChildren(section).any((s) => s['classSubjectId'] != null)) {
      checkGrade(section, section['average']);
    }
  }
  return (
    header: {
      'id': report['id'],
      'status': report['status'],
      'hasComment': hasComment,
      'overallAverage': average,
      'grading': report['grading'],
      'aggregateLabel': report['aggregateLabel'],
      'rank': rank,
      'classSize': size,
    },
    remaining: remaining,
    missingValues: missingValues,
    missingGrading: missingGrading,
  );
}

Iterable<Row> _reportChildren(Row section) =>
    (section['subResults'] as List? ?? const []).whereType<Row>();

Iterable<Row> _reportSections(Row report) sync* {
  for (final section
      in (report['sectionResults'] as List? ?? const []).whereType<Row>()) {
    yield section;
    yield* _reportChildren(section);
  }
}
