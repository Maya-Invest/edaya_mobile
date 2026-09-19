import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class LiveFamilyFeedbackController extends LevitController
    with LevitReactiveTasksMixin {
  LiveFamilyFeedbackController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _session = session,
       _schoolClient = schoolClient;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final results = LxVar<List<TeacherFamilyFeedbackResult>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(results);
    autoDispose(errorMessage);
    autoDispose(
      _session.grants.stream.listen((grants) {
        if (grants?.kind == 'teacher') {
          unawaited(load());
        } else {
          results(const []);
        }
      }),
    );
    if (_session.isAuthenticated) {
      unawaited(load());
    }
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

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        results(await listTeacherFamilyFeedbackResults(_schoolClient()));
      } on Object catch (error) {
        errorMessage('$error');
        results(const []);
      }
    });
  }

  Future<TeacherFamilyFeedbackResult?> loadDetail(String campaignId) async {
    try {
      final detail = await getTeacherFamilyFeedbackResult(
        _schoolClient(),
        campaignId,
      );
      final next = [
        for (final item in results.value)
          if (item.campaignId == campaignId) detail else item,
      ];
      if (!next.any((item) => item.campaignId == campaignId)) {
        next.add(detail);
      }
      results(next);
      return detail;
    } on Object catch (error) {
      errorMessage('$error');
      return null;
    }
  }
}
