import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import '../../mock/mock_store.dart';
import '../../mock/mock_mappers.dart';

class SessionHistoryPage extends StatelessWidget {
  const SessionHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      final store = context.levit.find<MockStore>();
      final sessions =
          store.sessions
              .map(calendarSessionFromMock)
              .where((s) => !s.endsAt.isAfter(SchoolClock.now()))
              .toList()
            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      return ListView(
        children: [
          for (final s in sessions)
            ListTile(
              title: Text(s.title),
              subtitle: Text(context.tr.workspaceNotRecorded),
              onTap: () => context.push('/session/${s.id}'),
            ),
          for (final record in store.attendance)
            ListTile(
              title: Text(record.subject),
              subtitle: Text('${record.status} · ${record.date}'),
            ),
        ],
      );
    }
    return LWatch(() {
      final student = context.levit.find<StudentContextController>();
      final years = context.levit.find<AcademicYearController>();
      final year = years.years.value
          .where((y) => y['id'] == years.selectedYearId.value)
          .firstOrNull;
      if (year == null || student.activeStudentId == null)
        return Center(child: Text(context.tr.workspaceNoHistory));
      return SessionHistoryPanel(
        key: ValueKey((student.activeStudentId, year['id'])),
        client: context.levit.find<SchoolClientFactory>(),
        query: 'get-student-session-history',
        selection: {'studentId': student.activeStudentId},
        year: year,
        onOpen: (id) =>
            context.push('/session/${Uri.encodeComponent(id)}?history=true'),
      );
    });
  }
}
