import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../live/runtime.dart';
import '../auth/session_storage.dart';
import 'academic_year_controller.dart';

/// Archive readers own a year-scoped transport; the Home selection is never changed.
class ArchiveWorkspace extends LScopedView<AcademicYearController> {
  const ArchiveWorkspace({super.key, required this.child, this.year});
  final Widget child;
  final String? year;
  @override
  AcademicYearController onConfigScope(LevitScope scope) {
    final session = scope.find<AppSessionController>();
    final school = session.schoolIdHeader;
    final actor = session.actorIdHeader;
    final auth = scope.find<AuthClient>();
    late AcademicYearController selected;
    SchoolClient factory() => createEdayaSchoolClient(
      auth,
      getSchoolId: () => school,
      getActorKind: () => 'guardian',
      getActorId: () => actor,
      getAcademicYearId: () => selected.selectedYearId.value,
    );
    selected = scope.put(
      () => AcademicYearController(
        archive: true,
        initialYearId: year,
        sessionStorage: scope.find<SessionStorage>(),
        session: session,
        schoolClient: factory,
      ),
    );
    scope.put<SchoolClientFactory>(() => factory);
    selected.loadYears();
    return selected;
  }

  @override
  Widget buildView(BuildContext context, AcademicYearController controller) {
    final id = controller.selectedYearId.value;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: id,
            key: ValueKey(id),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: words(context, 'Année scolaire', 'School year'),
            ),
            items: [
              for (final row in controller.years.value)
                DropdownMenuItem(
                  value: row['id'] as String,
                  child: Text(row['name'] as String? ?? row['id'] as String),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              final uri = GoRouterState.of(context).uri;
              context.replace(
                uri
                    .replace(
                      path: uri.path.startsWith('/scolarite/period/')
                          ? '/scolarite/notes'
                          : uri.path.startsWith('/fees/')
                          ? '/fees'
                          : uri.path,
                      queryParameters: {...uri.queryParameters, 'year': value}
                        ..remove('period')
                        ..remove('mark'),
                    )
                    .toString(),
              );
            },
          ),
        ),
        if (controller.errorMessage.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(controller.errorMessage.value),
          ),
        Expanded(
          child: id == null
              ? Center(
                  child: controller.errorMessage.value.isEmpty
                      ? const CircularProgressIndicator()
                      : TextButton.icon(
                          onPressed: controller.loadYears,
                          icon: const Icon(Icons.refresh),
                          label: Text(words(context, 'Réessayer', 'Retry')),
                        ),
                )
              : KeyedSubtree(key: ValueKey(id), child: child),
        ),
      ],
    );
  }
}

Widget archived(BuildContext context, Widget child, Uri uri) =>
    prototypeIsLive(context)
    ? ArchiveWorkspace(
        key: ValueKey((uri.path, uri.queryParameters['year'])),
        year: uri.queryParameters['year'],
        child: child,
      )
    : child;
