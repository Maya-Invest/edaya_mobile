import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';

/// Resolve existing notification URLs into the unified results workspace.
/// Each attempt has immutable school/actor/year headers and must match the child.
class LegacyResultLink extends StatefulWidget {
  const LegacyResultLink({super.key, required this.id, required this.report});
  final String id;
  final bool report;
  @override
  State<LegacyResultLink> createState() => _LegacyResultLinkState();
}

class _LegacyResultLinkState extends State<LegacyResultLink> {
  bool started = false, failed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      resolve();
    }
  }

  Future<void> resolve() async {
    if (!prototypeIsLive(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.replace('/scolarite/notes');
      });
      return;
    }
    final session = context.levit.find<AppSessionController>();
    final students = context.levit.find<StudentContextController>();
    final student = students.activeStudentId;
    final school = session.schoolIdHeader, actor = session.actorIdHeader;
    final account = session.user.value?.id;
    final auth = context.levit.find<AuthClient>();
    final years = context.levit.find<AcademicYearController>();
    final ids = {
      years.selectedYearId.value,
      ...years.years.value.map((r) => r['id'] as String?),
    }.whereType<String>();
    for (final year in ids) {
      try {
        final client = createEdayaSchoolClient(
          auth,
          getSchoolId: () => school,
          getActorKind: () => 'guardian',
          getActorId: () => actor,
          getAcademicYearId: () => year,
        );
        final row = widget.report
            ? await client.results.get(widget.id)
            : await client.assessmentResults.get(widget.id);
        if (row['studentId'] != student) continue;
        final assessment = widget.report
            ? null
            : await client.assessments.get(row['assessmentId'] as String);
        final period = (assessment ?? row)['periodId'] as String;
        String? subject;
        if (assessment != null) {
          subject =
              (await client.classSubjects.get(
                    assessment['classSubjectId'] as String,
                  ))['subjectId']
                  as String;
        }
        if (!mounted ||
            students.activeStudentId != student ||
            session.user.value?.id != account ||
            session.schoolIdHeader != school ||
            session.actorIdHeader != actor) {
          return;
        }
        context.replace(
          Uri(
            path: subject == null
                ? '/scolarite/notes'
                : '/scolarite/period/$period/subject/$subject',
            queryParameters: {
              'year': year,
              'period': period,
              if (!widget.report) 'mark': widget.id,
            },
          ).toString(),
        );
        return;
      } catch (_) {
        /* Try another authorized academic year. */
      }
    }
    if (mounted) setState(() => failed = true);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: failed
        ? Text(
            words(
              context,
              'Résultat indisponible pour cet enfant.',
              'Result unavailable for this child.',
            ),
          )
        : const CircularProgressIndicator(),
  );
}
