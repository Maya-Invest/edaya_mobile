import 'package:edaya_api_client/edaya_api_client.dart' as api;

import 'package:edaya_shared/edaya_shared.dart';
import 'models/curriculum_scope_models.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

List<CurriculumClassSubjectOption> buildClassSubjectOptions({
  required List<Map<String, dynamic>> classSubjectRows,
  required Map<String, String> subjectNameById,
  required String classLabel,
  required String subjectFallback,
}) {
  return classSubjectRows.map((row) {
    final subjectId = row['subjectId'] as String?;
    return CurriculumClassSubjectOption(
      offering: row,
      id: row['id'] as String,
      classGroupId: row['classGroupId'] as String,
      subjectName: subjectId == null
          ? subjectFallback
          : row['name'] as String? ??
                subjectNameById[subjectId] ??
                subjectFallback,
      classLabel: classLabel,
    );
  }).toList()..sort((left, right) => left.label.compareTo(right.label));
}

CurriculumProgressOverview buildCurriculumProgressOverview({
  required Map<String, dynamic> classSubject,
  required List<Map<String, dynamic>> matterLinks,
  required List<Map<String, dynamic>> subjectMatters,
  required String matterFallback,
}) {
  final matterNameById = {
    for (final matter in subjectMatters)
      matter['id'] as String: matter['name'] as String? ?? matterFallback,
  };
  final sequenceById = {
    for (final matter in subjectMatters)
      matter['id'] as String: (matter['sequenceOrder'] as num?)?.toInt() ?? 0,
  };

  final matters =
      matterLinks.map((link) {
        final subjectMatterId = link['subjectMatterId'] as String;
        return CurriculumMatterProgress(
          id: link['id'] as String,
          name: matterNameById[subjectMatterId] ?? matterFallback,
          sequenceOrder: sequenceById[subjectMatterId] ?? 0,
          status: CurriculumMatterStatus.fromApi(link['status'] as String?),
          completedPercentage:
              (link['completedPercentage'] as num?)?.toInt() ?? 0,
          notes: link['notes'] as String?,
        );
      }).toList()..sort((left, right) {
        final order = left.sequenceOrder.compareTo(right.sequenceOrder);
        if (order != 0) {
          return order;
        }
        return left.name.compareTo(right.name);
      });

  return CurriculumProgressOverview.fromOffering(
    classSubject,
    matters: matters,
  );
}

List<CurriculumLogEntry> buildCurriculumLogEntries({
  required List<Map<String, dynamic>> lessonSessions,
  required List<Map<String, dynamic>> progressRows,
  required List<Map<String, dynamic>> matterLinks,
  required List<Map<String, dynamic>> subjectMatters,
  required String classLabel,
  required String subjectLabel,
  required String matterFallback,
}) {
  final matterNameByLinkId = <String, String>{};
  final matterNameBySubjectMatterId = {
    for (final matter in subjectMatters)
      matter['id'] as String: matter['name'] as String? ?? matterFallback,
  };
  for (final link in matterLinks) {
    final linkId = link['id'] as String;
    final subjectMatterId = link['subjectMatterId'] as String;
    matterNameByLinkId[linkId] =
        matterNameBySubjectMatterId[subjectMatterId] ?? matterFallback;
  }

  final progressBySessionId = <String, List<Map<String, dynamic>>>{};
  for (final row in progressRows) {
    final sessionId = row['lessonSessionId'] as String;
    progressBySessionId.putIfAbsent(sessionId, () => []).add(row);
  }

  final entries = lessonSessions.map((session) {
    final sessionId = session['id'] as String;
    final snapshots =
        (progressBySessionId[sessionId] ?? const <Map<String, dynamic>>[]).map((
          row,
        ) {
          final linkId = row['classSubjectMatterId'] as String;
          return CurriculumLogMatterSnapshot(
            matterName: matterNameByLinkId[linkId] ?? matterFallback,
            completed: row['completed'] as bool?,
            notes: row['notes'] as String?,
          );
        }).toList();

    return CurriculumLogEntry(
      lessonSessionId: sessionId,
      classGroupId: session['classGroupId'] as String,
      classSubjectId: session['classSubjectId'] as String,
      displayLabel: session['displayLabel'] as String? ?? subjectLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      startsAt: _parseDateTime(session['startsAt']) ?? DateTime.now(),
      endsAt: _parseDateTime(session['endsAt']) ?? DateTime.now(),
      sessionNote: session['sessionNote'] as String?,
      matterSnapshots: snapshots,
    );
  }).toList()..sort((left, right) => right.startsAt.compareTo(left.startsAt));

  return entries;
}

Future<List<CurriculumClassSubjectOption>> fetchClassSubjectOptions({
  required api.SchoolClient client,
  required StudentSubjectParticipation participation,
  required String classGroupId,
  required String classLabel,
  required String subjectFallback,
  String? offeringId,
  bool includeProgress = false,
}) async {
  final classSubjectRows = participation
      .currentSubjects()
      .where(
        (row) =>
            row['classGroupId'] == classGroupId &&
            (offeringId == null || row['id'] == offeringId),
      )
      .toList();
  if (classSubjectRows.isEmpty) {
    return const [];
  }

  final subjectIds = classSubjectRows
      .where((row) => row['name'] == null)
      .map((row) => row['subjectId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final missing = {
    if (includeProgress)
      for (final row in classSubjectRows)
        if (row['completedPercentage'] == null) row['id'] as String,
  };
  final subjectRows = subjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjects.listAll(entitiesByIds(subjectIds));
  final olderOfferings = missing.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.classSubjects.listAll(entitiesByIds(missing.toList()));
  final byId = {for (final row in olderOfferings) row['id']: row};
  final subjectNameById = {
    for (final subject in subjectRows)
      subject['id'] as String: subject['name'] as String? ?? subjectFallback,
  };

  return buildClassSubjectOptions(
    classSubjectRows: [
      for (final row in classSubjectRows)
        if (!missing.contains(row['id']))
          row
        else if (byId[row['id']] case final legacy?)
          {
            ...legacy,
            ...row,
            'completedPercentage': legacy['completedPercentage'],
          },
    ],
    subjectNameById: subjectNameById,
    classLabel: classLabel,
    subjectFallback: subjectFallback,
  );
}

Future<CurriculumProgressOverview> fetchCurriculumProgressOverview({
  required api.SchoolClient client,
  required Map<String, dynamic> classSubject,
  required String matterFallback,
}) async {
  final classSubjectId = classSubject['id'] as String;
  final matterLinks = await client.classSubjectMatters.listAll({
    'classSubjectId': classSubjectId,
  });
  final subjectMatterIds = matterLinks
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toList();
  final subjectMatters = subjectMatterIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjectMatters.listAll(entitiesByIds(subjectMatterIds));

  return buildCurriculumProgressOverview(
    classSubject: classSubject,
    matterLinks: matterLinks,
    subjectMatters: subjectMatters,
    matterFallback: matterFallback,
  );
}

Future<List<CurriculumLogEntry>> fetchCurriculumLogEntries({
  required StudentSubjectParticipation participation,
  required api.SchoolClient client,
  required String classGroupId,
  required String classSubjectId,
  required String classLabel,
  required String subjectLabel,
  required String matterFallback,
}) async {
  final sessions = await client.lessonSessions.listAll({
    'classGroupId': classGroupId,
    'classSubjectId': classSubjectId,
  });
  final lessonSessions = sessions.where((row) {
    final at = _parseDateTime(row['startsAt']);
    return at != null &&
        participation.includes(row['classSubjectId'] as String?, at);
  }).toList();
  if (lessonSessions.isEmpty) {
    return const [];
  }

  final matterLinks = await client.classSubjectMatters.listAll({
    'classSubjectId': classSubjectId,
  });
  final subjectMatterIds = matterLinks
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toList();
  final subjectMatters = subjectMatterIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjectMatters.listAll(entitiesByIds(subjectMatterIds));
  final sessionIds = lessonSessions.map((row) => row['id'] as String).toList();
  final progressRows = await client.classSubjectProgress.listAll(
    progressForLessonSessions(sessionIds),
  );

  return buildCurriculumLogEntries(
    lessonSessions: lessonSessions,
    progressRows: progressRows,
    matterLinks: matterLinks,
    subjectMatters: subjectMatters,
    classLabel: classLabel,
    subjectLabel: subjectLabel,
    matterFallback: matterFallback,
  );
}
