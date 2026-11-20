import 'package:edaya_api_client/edaya_api_client.dart' as api;

import 'package:edaya_shared/edaya_shared.dart';
import 'teaching_models.dart';

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
    chapterCount:
        (classSubject['chapterCount'] as num?)?.toInt() ?? matters.length,
    ongoingChapterCount:
        (classSubject['ongoingChapterCount'] as num?)?.toInt() ?? 0,
    completedChapterCount:
        (classSubject['completedChapterCount'] as num?)?.toInt() ?? 0,
    classSubjectCompletedPercentage:
        (classSubject['completedPercentage'] as num?)?.toInt() ?? 0,
    matters: matters,
  );
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
  if (!isHomeroomClass && taughtClassSubjectIds.isEmpty) return const [];
  final rows = await client.classSubjects.listAll({
    ...classGroupScope(classGroupId),
    if (!isHomeroomClass) ...entitiesByIds(taughtClassSubjectIds.toList()),
  });

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
      : await client.subjects.listAll(entitiesByIds(subjectIds));
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

typedef TeachingChapterCatalog = ({
  List<Map<String, dynamic>> links,
  List<Map<String, dynamic>> definitions,
});

Future<TeachingChapterCatalog> fetchTeachingChapterCatalog(
  api.SchoolClient client,
  String classSubjectId,
) async {
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

  return (links: matterLinks, definitions: subjectMatters);
}

Future<TeachingProgressOverview> fetchTeachingProgressOverview({
  required api.SchoolClient client,
  required String classSubjectId,
  required String matterFallback,
}) async {
  late final Map<String, dynamic> classSubject;
  late final TeachingChapterCatalog catalog;
  await Future.wait<void>([
    client.classSubjects.get(classSubjectId).then<void>((row) {
      classSubject = row;
    }),
    fetchTeachingChapterCatalog(client, classSubjectId).then<void>((rows) {
      catalog = rows;
    }),
  ], eagerError: true);

  return buildTeachingProgressOverview(
    classSubject: classSubject,
    matterLinks: catalog.links,
    subjectMatters: catalog.definitions,
    matterFallback: matterFallback,
  );
}

Future<({List<TeachingLogEntry> items, String? nextCursor})>
fetchTeachingLogPage({
  required api.SchoolClient client,
  required TeachingClassSubjectOption option,
  required bool recordedOnly,
  required Future<void> abort,
  String? cursor,
}) async {
  final page = await client.getTeacherLogbook({
    'classGroupId': option.classGroupId,
    'classSubjectId': option.id,
    'view': recordedOnly ? 'recorded' : 'all',
    if (cursor != null) 'cursor': cursor,
  }, abortTrigger: abort);
  return (
    items: [
      for (final row in (page['items'] as List).cast<Map>())
        TeachingLogEntry(
          lessonSessionId: row['id'] as String,
          displayLabel: row['displayLabel'] as String,
          startsAt: DateTime.parse(row['startsAt'] as String),
          hasContent: row['recorded'] as bool,
        ),
    ],
    nextCursor: page['nextCursor'] as String?,
  );
}
