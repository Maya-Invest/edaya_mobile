import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../live/runtime.dart';
import 'academic_year_controller.dart';
import 'student_context_controller.dart';

/// Legacy year URLs select the same pupil context used by every feature.
class ArchiveWorkspace extends StatefulWidget {
  const ArchiveWorkspace({super.key, required this.child, this.year});
  final Widget child;
  final String? year;
  @override
  State<ArchiveWorkspace> createState() => _ArchiveWorkspaceState();
}

class _ArchiveWorkspaceState extends State<ArchiveWorkspace> {
  Future<void>? selection;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.year != null &&
        context.levit.find<AcademicYearController>().selectedYearId.value !=
            widget.year) {
      final student = context.levit.find<StudentContextController>();
      final year = widget.year!;
      selection ??= Future(() => student.selectEnrollmentYear(year));
    }
  }

  @override
  Widget build(BuildContext context) => selection == null
      ? widget.child
      : FutureBuilder<void>(
          future: selection,
          builder: (_, snapshot) => snapshot.hasError
              ? Center(child: Text(context.tr.noAcademicYearsAvailable))
              : snapshot.connectionState == ConnectionState.done
              ? widget.child
              : const Center(child: CircularProgressIndicator()),
        );
}

Widget archived(BuildContext context, Widget child, Uri uri) =>
    prototypeIsLive(context) && uri.queryParameters['year'] != null
    ? ArchiveWorkspace(
        key: ValueKey(uri.queryParameters['year']),
        year: uri.queryParameters['year'],
        child: child,
      )
    : child;
