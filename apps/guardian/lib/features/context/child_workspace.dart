import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../app/workspace_shell.dart';
import '../../live/runtime.dart';
import 'academic_year_controller.dart';
import 'student_context_controller.dart';

/// Only the page's data scope is replaced on a child change. The Navigator and
/// child picker remain alive until the complete new selection is ready.
class ChildWorkspace extends StatelessWidget {
  const ChildWorkspace({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LWatch(() {
    if (!prototypeIsLive(context)) return child;
    final session = context.levit.find<AppSessionController>();
    final student = context.levit.find<StudentContextController>();
    final year = context.levit.find<AcademicYearController>();
    final identity = (
      session.user.value?.id,
      session.schoolIdHeader,
      session.actorIdHeader,
      student.activeStudentId,
      year.selectedYearId.value,
    );
    final path = GoRouterState.of(context).uri.path;
    if (student.activeStudentId == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (path == '/home') const ChildContextCard(),
          const SizedBox(height: 24),
          if (student.isLoading.value)
            const LinearProgressIndicator()
          else
            Text(
              student.errorMessage.value.isNotEmpty
                  ? student.errorMessage.value
                  : words(
                      context,
                      'Sélectionnez un enfant pour continuer.',
                      'Select a child to continue.',
                    ),
            ),
        ],
      );
    }
    if (year.selectedYearId.value == null &&
        (path.startsWith('/scolarite') ||
            path.startsWith('/calendar') ||
            path.startsWith('/session') ||
            path.startsWith('/fees'))) {
      return Center(
        child: Text(words(context, 'Aucune inscription', 'No enrollment')),
      );
    }
    return _CapturedTransport(key: ValueKey(identity), child: child);
  });
}

class _CapturedTransport extends LScopedView<SchoolClientFactory> {
  const _CapturedTransport({super.key, required this.child});
  final Widget child;
  @override
  SchoolClientFactory onConfigScope(LevitScope scope) {
    final session = scope.find<AppSessionController>();
    final school = session.schoolIdHeader;
    final actor = session.actorIdHeader;
    final year = scope.find<AcademicYearController>().selectedYearId.value;
    final auth = scope.find<AuthClient>();
    return scope.put<SchoolClientFactory>(
      () =>
          () => createEdayaSchoolClient(
            auth,
            getSchoolId: () => school,
            getActorKind: () => 'guardian',
            getActorId: () => actor,
            getAcademicYearId: () => year,
          ),
    );
  }

  @override
  Widget buildView(BuildContext context, SchoolClientFactory controller) =>
      child;
}
