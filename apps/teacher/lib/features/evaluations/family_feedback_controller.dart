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
  int _generation = 0;

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
          _generation++;
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
    final generation = ++_generation;
    final school = _session.schoolIdHeader;
    results(const []);
    errorMessage('');
    await runTask(() async {
      try {
        final data = await listTeacherFamilyFeedbackResults(_schoolClient());
        if (isClosed ||
            generation != _generation ||
            school != _session.schoolIdHeader) {
          return;
        }
        results(data);
      } on Object catch (error) {
        if (isClosed ||
            generation != _generation ||
            school != _session.schoolIdHeader) {
          return;
        }
        errorMessage('$error');
        results(const []);
      }
    });
  }

  Future<TeacherFamilyFeedbackResult?> loadDetail(String campaignId) async {
    final school = _session.schoolIdHeader;
    try {
      final detail = await getTeacherFamilyFeedbackResult(
        _schoolClient(),
        campaignId,
      );
      if (isClosed || school != _session.schoolIdHeader) return null;
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
      if (isClosed || school != _session.schoolIdHeader) return null;
      errorMessage('$error');
      return null;
    }
  }
}
