import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';

class SessionHistoryPage extends StatelessWidget {
  const SessionHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      final store = context.levit.find<MockStore>();
      final sessions = [...store.sessions]
        ..sort((a, b) => b.date.compareTo(a.date));
      return ListView(
        children: [
          for (final s in sessions.where(
            (s) => !DateTime(
              s.date.year,
              s.date.month,
              s.date.day,
              s.endHour,
            ).isAfter(SchoolClock.now()),
          ))
            ListTile(
              title: Text('${s.classLabel} · ${s.subject}'),
              subtitle: Text(
                s.attendanceComplete
                    ? context.tr.workspaceAttendanceComplete
                    : context.tr.workspaceAttendanceIncomplete,
              ),
              onTap: () => context.push('/session/${s.id}'),
            ),
        ],
      );
    }
    return LWatch(() {
      final teacher = context.levit.find<TeacherContextController>();
      final years = context.levit.find<AcademicYearController>();
      final year = years.years.value
          .where((y) => y['id'] == years.selectedYearId.value)
          .firstOrNull;
      final teacherId = teacher.teacherId.value;
      final selection = teacher.selection;
      if (year == null || teacherId == null || selection == null)
        return Center(child: Text(context.tr.workspaceNoHistory));
      return SessionHistoryPanel(
        key: ValueKey((
          selection.schoolId,
          year['id'],
          teacherId,
          selection.classGroupId,
          selection.classSubjectId,
        )),
        client: context.levit.find<SchoolClientFactory>(),
        query: 'get-teacher-session-history',
        selection: {
          'teacherId': teacherId,
          'classGroupId': selection.classGroupId,
          if (selection.classSubjectId case final String id)
            'classSubjectId': id,
        },
        year: year,
        onOpen: (id) => context.push('/session/${Uri.encodeComponent(id)}'),
      );
    });
  }
}
