import 'package:edaya_api_client/edaya_api_client.dart' as api;

import 'package:edaya_shared/edaya_shared.dart';
import 'teaching_models.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

List<TeachingClassSubjectOption> buildTeachingClassSubjectOptions({
  required List<Map<String, dynamic>> classSubjectRows,
  required Map<String, String> subjectNameById,
  required Map<String, String> classLabelById,
  required String subjectFallback,
}) {
  return classSubjectRows.map((row) {
    final classGroupId = row['classGroupId'] as String;
    final subjectId = row['subjectId'] as String?;
    return TeachingClassSubjectOption(
      id: row['id'] as String,
      classGroupId: classGroupId,
      subjectName: subjectId == null
          ? subjectFallback
          : subjectNameById[subjectId] ?? subjectFallback,
      classLabel: classLabelById[classGroupId] ?? classGroupId,
    );
  }).toList()..sort((left, right) => left.label.compareTo(right.label));
}

TeachingProgressOverview buildTeachingProgressOverview({
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
        return TeachingMatterProgress(
          id: link['id'] as String,
          name: matterNameById[subjectMatterId] ?? matterFallback,
          sequenceOrder: sequenceById[subjectMatterId] ?? 0,
          status: TeachingMatterStatus.fromApi(link['status'] as String?),
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

  return TeachingProgressOverview(
    classSubjectCompletedPercentage:
        (classSubject['completedPercentage'] as num?)?.toInt() ?? 0,
    matters: matters,
  );
}

List<TeachingLogEntry> buildTeachingLogEntries({
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
    final snapshots = (progressBySessionId[sessionId] ?? const []).map((row) {
      final linkId = row['classSubjectMatterId'] as String;
      return TeachingLogMatterSnapshot(
        matterName: matterNameByLinkId[linkId] ?? matterFallback,
        completedPercentage: (row['completedPercentage'] as num?)?.toInt() ?? 0,
        notes: row['notes'] as String?,
      );
    }).toList();

    return TeachingLogEntry(
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

Future<List<TeachingClassSubjectOption>> fetchAllTeachingClassSubjectOptions({
  required api.SchoolClient client,
  required Map<String, String> classLabelById,
  required Set<String> taughtClassSubjectIds,
  required Set<String> homeroomClassGroupIds,
  required String subjectFallback,
}) async {
  if (classLabelById.isEmpty) {
    return const [];
  }

  final allOptions = <TeachingClassSubjectOption>[];
  final seenIds = <String>{};

  for (final classGroupId in classLabelById.keys) {
    final options = await fetchTeachingSubjectsForClass(
      client: client,
      classGroupId: classGroupId,
      taughtClassSubjectIds: taughtClassSubjectIds,
      isHomeroomClass: homeroomClassGroupIds.contains(classGroupId),
      classLabelById: classLabelById,
      subjectFallback: subjectFallback,
    );
    for (final option in options) {
      if (seenIds.add(option.id)) {
        allOptions.add(option);
      }
    }
  }

  allOptions.sort((left, right) => left.label.compareTo(right.label));
  return allOptions;
}

Future<List<TeachingClassSubjectOption>> fetchTeachingSubjectsForClass({
  required api.SchoolClient client,
  required String classGroupId,
  required Set<String> taughtClassSubjectIds,
  required bool isHomeroomClass,
  required Map<String, String> classLabelById,
  required String subjectFallback,
}) async {
  final rows = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  if (isHomeroomClass) {
    final homeroomRows = await client.classSubjects.list(
      classGroupScope(classGroupId),
    );
    for (final row in homeroomRows) {
      final id = row['id'] as String;
      if (seenIds.add(id)) {
        rows.add(row);
      }
    }
  }

  if (taughtClassSubjectIds.isNotEmpty) {
    final taughtRows = await client.classSubjects.list(
      entitiesByIds(taughtClassSubjectIds.toList()),
    );
    for (final row in taughtRows) {
      if (row['classGroupId'] != classGroupId) {
        continue;
      }
      final id = row['id'] as String;
      if (seenIds.add(id)) {
        rows.add(row);
      }
    }
  }

  if (rows.isEmpty) {
    return const [];
  }

  final subjectIds = rows
      .map((row) => row['subjectId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final subjectRows = subjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjects.list(entitiesByIds(subjectIds));
  final subjectNameById = {
    for (final subject in subjectRows)
      subject['id'] as String: subject['name'] as String? ?? subjectFallback,
  };

  return buildTeachingClassSubjectOptions(
    classSubjectRows: rows,
    subjectNameById: subjectNameById,
    classLabelById: classLabelById,
    subjectFallback: subjectFallback,
  );
}

Future<TeachingProgressOverview> fetchTeachingProgressOverview({
  required api.SchoolClient client,
  required String classSubjectId,
  required String matterFallback,
}) async {
  final classSubject = await client.classSubjects.get(classSubjectId);
  final matterLinks = await client.classSubjectMatters.list({
    'classSubjectId': classSubjectId,
  });
  final subjectMatterIds = matterLinks
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toList();
  final subjectMatters = subjectMatterIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjectMatters.list(entitiesByIds(subjectMatterIds));

  return buildTeachingProgressOverview(
    classSubject: classSubject,
    matterLinks: matterLinks,
    subjectMatters: subjectMatters,
    matterFallback: matterFallback,
  );
}

Future<List<TeachingLogEntry>> fetchTeachingLogEntries({
  required api.SchoolClient client,
  required String classGroupId,
  required String classSubjectId,
  required String classLabel,
  required String subjectLabel,
  required String matterFallback,
}) async {
  final lessonSessions = await client.lessonSessions.list({
    'classGroupId': classGroupId,
    'classSubjectId': classSubjectId,
  });
  if (lessonSessions.isEmpty) {
    return const [];
  }

  final sessionIds = lessonSessions.map((row) => row['id'] as String).toList();
  final matterLinks = await client.classSubjectMatters.list({
    'classSubjectId': classSubjectId,
  });
  final subjectMatterIds = matterLinks
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toList();
  final subjectMatters = subjectMatterIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjectMatters.list(entitiesByIds(subjectMatterIds));
  final progressRows = await client.classSubjectProgress.list(
    progressForLessonSessions(sessionIds),
  );

  return buildTeachingLogEntries(
    lessonSessions: lessonSessions,
    progressRows: progressRows,
    matterLinks: matterLinks,
    subjectMatters: subjectMatters,
    classLabel: classLabel,
    subjectLabel: subjectLabel,
    matterFallback: matterFallback,
  );
}
