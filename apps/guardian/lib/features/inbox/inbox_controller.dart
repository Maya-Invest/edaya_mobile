import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../context/student_context_controller.dart';

class InboxController extends RecipientInboxController {
  InboxController({
    required super.session,
    required super.schoolClient,
    required StudentContextController studentContext,
  }) : _students = studentContext,
       super(kind: 'guardian');

  final StudentContextController _students;
  final campaigns = LxVar<List<GuardianFamilyFeedbackCampaign>>(const []);
  final campaignsLoading = LxVar(false);
  final campaignsError = LxVar('');
  int _generation = 0;
  (String?, String?, String?, String?)? _selection;

  int get openCampaignCount =>
      campaigns.value.where((item) => item.slotState == 'open').length;

  @override
  void onInit() {
    super.onInit();
    autoDispose(campaigns);
    autoDispose(campaignsLoading);
    autoDispose(campaignsError);
    autoDispose(
      _students.activeStudent.stream.listen((_) => unawaited(refreshRelated())),
    );
  }

  @override
  Future<void> refreshRelated() async {
    final generation = ++_generation;
    final grants = session.grants.value;
    final student = _students.activeStudentId;
    final key = (
      session.user.value?.id,
      grants?.schoolId,
      grants?.actorId,
      student,
    );
    if (_selection != key || !hasRecipient) campaigns(const []);
    _selection = key;
    campaignsError('');
    campaignsLoading(hasRecipient);
    if (!hasRecipient) return;
    bool current() =>
        hasRecipient &&
        _generation == generation &&
        _students.activeStudentId == student &&
        session.grants.value?.actorId == key.$3 &&
        session.grants.value?.schoolId == key.$2 &&
        session.user.value?.id == key.$1;
    try {
      final result = await listGuardianFamilyFeedbackCampaigns(
        schoolClient(),
        studentId: student,
      );
      if (current()) campaigns(result);
    } catch (error) {
      if (current()) {
        campaigns(const []);
        campaignsError(systemL10n().couldNotLoadInbox(error.toString()));
      }
    } finally {
      if (current()) campaignsLoading(false);
    }
  }
}
