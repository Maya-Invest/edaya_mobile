import 'dart:math';

import 'package:edaya_api_client/edaya_api_client.dart' as api;

List<Map<String, dynamic>> unwrapFamilyFeedbackList(dynamic result) {
  if (result is List) {
    return result.whereType<Map<String, dynamic>>().toList();
  }
  if (result is Map<String, dynamic>) {
    final items = result['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

String familyFeedbackRequestId() {
  final random = Random.secure();
  return 'ff-${DateTime.now().toUtc().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}

class FamilyFeedbackContext {
  const FamilyFeedbackContext({
    required this.studentName,
    required this.teacherName,
    required this.subjectName,
    required this.className,
    required this.periodName,
  });

  factory FamilyFeedbackContext.fromJson(Map<String, dynamic> json) {
    return FamilyFeedbackContext(
      studentName: json['studentName'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      periodName: json['periodName'] as String? ?? '',
    );
  }

  final String studentName;
  final String teacherName;
  final String subjectName;
  final String className;
  final String periodName;

  String get summary {
    return [
      studentName,
      teacherName,
      subjectName,
      className,
      periodName,
    ].where((value) => value.isNotEmpty).join(' · ');
  }
}

class GuardianFamilyFeedbackCampaign {
  const GuardianFamilyFeedbackCampaign({
    required this.campaignId,
    required this.studentId,
    required this.slotState,
    this.closesAt,
    this.context,
  });

  factory GuardianFamilyFeedbackCampaign.fromJson(Map<String, dynamic> json) {
    final context = json['context'];
    return GuardianFamilyFeedbackCampaign(
      campaignId: json['campaignId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      slotState: json['slotState'] as String? ?? '',
      closesAt: json['closesAt'] as String?,
      context: context is Map<String, dynamic>
          ? FamilyFeedbackContext.fromJson(context)
          : null,
    );
  }

  final String campaignId;
  final String studentId;
  final String slotState;
  final String? closesAt;
  final FamilyFeedbackContext? context;
}

class FamilyFeedbackInstrumentItem {
  const FamilyFeedbackInstrumentItem({required this.id, required this.stem});

  factory FamilyFeedbackInstrumentItem.fromJson(Map<String, dynamic> json) {
    return FamilyFeedbackInstrumentItem(
      id: json['id'] as String? ?? '',
      stem: json['stem'] as String? ?? '',
    );
  }

  final String id;
  final String stem;
}

class FamilyFeedbackInstrument {
  const FamilyFeedbackInstrument({
    required this.version,
    required this.intro,
    required this.confidentialityNotice,
    required this.scaleHelper,
    required this.scaleLabels,
    required this.commentPrompt,
    required this.items,
  });

  factory FamilyFeedbackInstrument.fromJson(Map<String, dynamic> json) {
    return FamilyFeedbackInstrument(
      version: json['version'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      confidentialityNotice: json['confidentialityNotice'] as String? ?? '',
      scaleHelper: json['scaleHelper'] as String? ?? '',
      scaleLabels: {
        for (final entry in (json['scaleLabels'] as Map? ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
      commentPrompt: json['commentPrompt'] as String? ?? '',
      items: [
        for (final item in json['items'] as List? ?? const [])
          if (item is Map<String, dynamic>) FamilyFeedbackInstrumentItem.fromJson(item),
      ],
    );
  }

  final String version;
  final String intro;
  final String confidentialityNotice;
  final String scaleHelper;
  final Map<String, String> scaleLabels;
  final String commentPrompt;
  final List<FamilyFeedbackInstrumentItem> items;
}

class GuardianFamilyFeedbackQuestionnaire {
  const GuardianFamilyFeedbackQuestionnaire({
    required this.campaignId,
    required this.studentId,
    required this.slotId,
    required this.slotState,
    this.closesAt,
    this.context,
    this.instrument,
    this.completedAt,
  });

  factory GuardianFamilyFeedbackQuestionnaire.fromJson(Map<String, dynamic> json) {
    final receipt = json['receipt'];
    final context = json['context'];
    return GuardianFamilyFeedbackQuestionnaire(
      campaignId: json['campaignId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      slotId: json['slotId'] as String? ?? '',
      slotState: json['slotState'] as String? ?? '',
      closesAt: json['closesAt'] as String?,
      context: context is Map<String, dynamic>
          ? FamilyFeedbackContext.fromJson(context)
          : null,
      instrument: json['instrument'] is Map<String, dynamic>
          ? FamilyFeedbackInstrument.fromJson(json['instrument'] as Map<String, dynamic>)
          : null,
      completedAt: receipt is Map<String, dynamic> ? receipt['completedAt'] as String? : null,
    );
  }

  final String campaignId;
  final String studentId;
  final String slotId;
  final String slotState;
  final String? closesAt;
  final FamilyFeedbackContext? context;
  final FamilyFeedbackInstrument? instrument;
  final String? completedAt;

  bool get isOpen => slotState == 'open';
  bool get isCompleted => slotState == 'completed';
  bool get isAlreadyCompleted => slotState == 'already_completed';
}

class FamilyFeedbackQuestionAggregate {
  const FamilyFeedbackQuestionAggregate({
    required this.questionId,
    required this.suppressed,
    required this.nScored,
    required this.nCannotAssess,
    required this.distribution,
  });

  factory FamilyFeedbackQuestionAggregate.fromJson(Map<String, dynamic> json) {
    final raw = json['distribution'] as Map<String, dynamic>? ?? const {};
    return FamilyFeedbackQuestionAggregate(
      questionId: json['questionId'] as String? ?? '',
      suppressed: json['suppressed'] as bool? ?? true,
      nScored: json['nScored'] as int? ?? 0,
      nCannotAssess: json['nCannotAssess'] as int? ?? 0,
      distribution: {
        1: raw['1'] as int? ?? 0,
        2: raw['2'] as int? ?? 0,
        3: raw['3'] as int? ?? 0,
        4: raw['4'] as int? ?? 0,
        5: raw['5'] as int? ?? 0,
      },
    );
  }

  final String questionId;
  final bool suppressed;
  final int nScored;
  final int nCannotAssess;
  final Map<int, int> distribution;
}

class TeacherFamilyFeedbackResult {
  const TeacherFamilyFeedbackResult({
    required this.campaignId,
    required this.eligibleSlotCount,
    required this.completedSlotCount,
    required this.responseRate,
    required this.overallSuppressed,
    required this.questions,
    this.themes,
  });

  factory TeacherFamilyFeedbackResult.fromJson(Map<String, dynamic> json) {
    return TeacherFamilyFeedbackResult(
      campaignId: json['campaignId'] as String? ?? '',
      eligibleSlotCount: json['eligibleSlotCount'] as int? ?? 0,
      completedSlotCount: json['completedSlotCount'] as int? ?? 0,
      responseRate: (json['responseRate'] as num?)?.toDouble() ?? 0,
      overallSuppressed: json['overallSuppressed'] as bool? ?? true,
      questions: [
        for (final item in json['questions'] as List? ?? const [])
          if (item is Map<String, dynamic>) FamilyFeedbackQuestionAggregate.fromJson(item),
      ],
      themes: json['themes'] as String?,
    );
  }

  final String campaignId;
  final int eligibleSlotCount;
  final int completedSlotCount;
  final double responseRate;
  final bool overallSuppressed;
  final List<FamilyFeedbackQuestionAggregate> questions;
  final String? themes;
}

Future<List<GuardianFamilyFeedbackCampaign>> listGuardianFamilyFeedbackCampaigns(
  api.SchoolClient client,
) async {
  final result = await client.requestRoute<dynamic>(
    'POST',
    '/core/queries/list-guardian-family-feedback-campaigns',
    body: const <String, dynamic>{},
  );
  return unwrapFamilyFeedbackList(result).map(GuardianFamilyFeedbackCampaign.fromJson).toList();
}

Future<GuardianFamilyFeedbackQuestionnaire> getGuardianFamilyFeedbackQuestionnaire(
  api.SchoolClient client, {
  required String campaignId,
  required String studentId,
  required String locale,
}) async {
  final result = await client.runQuery('get-guardian-family-feedback-questionnaire', {
    'campaignId': campaignId,
    'studentId': studentId,
    'locale': locale == 'en' ? 'en' : 'fr',
  });
  return GuardianFamilyFeedbackQuestionnaire.fromJson(result);
}

Future<void> submitFamilyFeedbackResponse(
  api.SchoolClient client, {
  required String campaignId,
  required String studentId,
  required Map<String, Object> answers,
  String? comment,
}) {
  return client.runCommand('submit-family-feedback-response', {
    'requestId': familyFeedbackRequestId(),
    'campaignId': campaignId,
    'studentId': studentId,
    'answers': answers,
    if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
  });
}

Future<List<TeacherFamilyFeedbackResult>> listTeacherFamilyFeedbackResults(
  api.SchoolClient client,
) async {
  final result = await client.requestRoute<dynamic>(
    'POST',
    '/core/queries/list-teacher-family-feedback-results',
    body: const <String, dynamic>{},
  );
  return unwrapFamilyFeedbackList(result).map(TeacherFamilyFeedbackResult.fromJson).toList();
}

Future<TeacherFamilyFeedbackResult> getTeacherFamilyFeedbackResult(
  api.SchoolClient client,
  String campaignId,
) async {
  final result = await client.runQuery('get-teacher-family-feedback-result', {
    'id': campaignId,
  });
  return TeacherFamilyFeedbackResult.fromJson(result);
}
