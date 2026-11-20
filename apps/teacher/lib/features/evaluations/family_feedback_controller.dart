import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/teacher_context_controller.dart';

class LiveFamilyFeedbackController extends LevitController
    with LevitReactiveTasksMixin {
  LiveFamilyFeedbackController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    this.teacherContext,
    this.feedbackId,
  }) : _session = session,
       _schoolClient = schoolClient;

  final TeacherContextController? teacherContext;
  final String? feedbackId;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final results = LxVar<List<TeacherFamilyFeedbackResult>>(const []);
  final errorMessage = LxVar('');
  int _generation = 0;
  Object? _pendingScope;
  Future<void>? _pending;

  ({
    String account,
    String school,
    String actor,
    String? group,
    String? offering,
    String? year,
  })?
  get _selection {
    final grants = _session.grants.value;
    final account = _session.user.value?.id;
    final assignment = teacherContext?.activeAssignment;
    if (account == null ||
        grants?.kind != 'teacher' ||
        (teacherContext != null && assignment == null))
      return null;
    return (
      account: account,
      school: grants!.schoolId,
      actor: grants.actorId,
      group: assignment?.classGroupId,
      offering: assignment?.classSubjectId,
      year: teacherContext?.catalog?.workspace.year,
    );
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(results);
    autoDispose(errorMessage);
    autoDispose(_session.grants.stream.listen((_) => unawaited(load())));
    autoDispose(_session.user.stream.listen((_) => unawaited(load())));
    final context = teacherContext;
    if (context != null)
      autoDispose(
        context.activeAssignmentId.stream.listen((_) => unawaited(load())),
      );
    unawaited(load());
  }

  List<TeacherFamilyFeedbackResult> get openResults => results.value
      .where(
        (item) =>
            item.eligibleSlotCount > 0 &&
            item.completedSlotCount < item.eligibleSlotCount,
      )
      .toList();

  TeacherFamilyFeedbackResult? resultById(String campaignId) {
    for (final item in results.value) {
      if (item.campaignId == campaignId) {
        return item;
      }
    }
    return null;
  }

  Future<void> load() {
    final scope = _selection;
    if (_pending != null && _pendingScope == scope) return _pending!;
    final generation = ++_generation;
    _pending = null;
    _pendingScope = scope;
    results(const []);
    errorMessage('');
    if (scope == null) return Future.value();
    bool current() =>
        !isClosed && generation == _generation && _selection == scope;
    return _pending =
        runTask(() async {
          try {
            final id = feedbackId;
            final data = id == null
                ? await listTeacherFeedbackSummaries(
                    _schoolClient(),
                    classGroupId: scope.group,
                    classSubjectId: scope.offering,
                  )
                : [await getTeacherFamilyFeedbackResult(_schoolClient(), id)];
            if (current()) results(data);
          } on Object catch (error) {
            if (current()) errorMessage('$error');
          }
        }).whenComplete(() {
          if (generation == _generation) _pending = null;
        });
  }
}
