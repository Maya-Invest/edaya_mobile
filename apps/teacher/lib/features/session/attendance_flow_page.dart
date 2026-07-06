import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../calendar/models/teacher_session.dart';
import 'models/session_detail_models.dart';
import 'session_detail_controller.dart';

class AttendanceFlowPage extends StatelessWidget {
  const AttendanceFlowPage({
    super.key,
    required this.session,
    this.controller,
  });

  final TeacherSession session;
  final SessionDetailController? controller;

  @override
  Widget build(BuildContext context) {
    final sharedController = controller;
    if (sharedController != null) {
      return LView<SessionDetailController>(
        resolver: (_) => sharedController,
        builder: (context, resolved) => _AttendanceFlowScaffold(
          controller: resolved,
        ),
      );
    }

    return _AttendanceFlowScopedPage(session: session);
  }
}

class _AttendanceFlowScopedPage extends LScopedView<SessionDetailController> {
  const _AttendanceFlowScopedPage({required this.session});

  final TeacherSession session;

  @override
  SessionDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => SessionDetailController(
        session: session,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, SessionDetailController controller) {
    return _AttendanceFlowScaffold(controller: controller);
  }
}

class _AttendanceFlowScaffold extends StatelessWidget {
  const _AttendanceFlowScaffold({required this.controller});

  final SessionDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.attendanceFlowTitle(controller.session.classLabel)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: LWatch(
        () {
          if (!controller.supportsAttendanceRecording) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr.attendanceRecordingLessonOnly,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (controller.isBusy.value && controller.students.value.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return _AttendanceFlowBody(controller: controller);
        },
      ),
    );
  }
}

class _AttendanceFlowBody extends StatefulWidget {
  const _AttendanceFlowBody({required this.controller});

  final SessionDetailController controller;

  @override
  State<_AttendanceFlowBody> createState() => _AttendanceFlowBodyState();
}

class _AttendanceFlowBodyState extends State<_AttendanceFlowBody> {
  final Map<String, SessionAttendanceStatus> _marks = {};
  int _index = 0;
  bool _showSummary = false;
  bool _initialized = false;

  @override
  void didUpdateWidget(covariant _AttendanceFlowBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _seedMarksFromController();
  }

  void _seedMarksFromController() {
    final students = widget.controller.students.value;
    if (students.isEmpty) {
      return;
    }

    var changed = false;
    for (final row in students) {
      final status = row.status;
      if (status != null && _marks[row.studentId] != status) {
        _marks[row.studentId] = status;
        changed = true;
      }
    }

    if (!_initialized || changed) {
      _initialized = true;
      _index = _firstUnmarkedIndex(students);
      _showSummary = _allMarked(students);
    }
  }

  int _firstUnmarkedIndex(List<SessionStudentRow> students) {
    for (var i = 0; i < students.length; i++) {
      if (!_marks.containsKey(students[i].studentId)) {
        return i;
      }
    }
    return students.isEmpty ? 0 : students.length - 1;
  }

  bool _allMarked(List<SessionStudentRow> students) {
    if (students.isEmpty) {
      return false;
    }
    return students.every((row) => _marks.containsKey(row.studentId));
  }

  Map<SessionAttendanceStatus, int> _statusCounts(
    List<SessionStudentRow> students,
  ) {
    final counts = {
      for (final status in SessionAttendanceStatus.values) status: 0,
    };
    for (final row in students) {
      final status = _marks[row.studentId];
      if (status != null) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    _seedMarksFromController();

    final students = widget.controller.students.value;
    if (students.isEmpty) {
      return Center(child: Text(context.tr.noStudentsToRecord));
    }

    if (_showSummary) {
      return _AttendanceSummary(
        students: students,
        marks: _marks,
        counts: _statusCounts(students),
        onDone: () => context.pop(),
        onReviewAgain: () {
          setState(() {
            _showSummary = false;
            _index = _firstUnmarkedIndex(students);
          });
        },
      );
    }

    final current = students[_index.clamp(0, students.length - 1)];
    final recorded = _marks.length;
    final progress = recorded / students.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(
            context.tr.attendanceRecordedProgress(recorded, students.length),
          ),
          const Spacer(),
          PersonAvatar(
            name: current.studentName,
            initials: current.studentInitials,
            photoUrl: current.photoUrl,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(
            current.studentName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < students.length; i++)
                Container(
                  width: i == _index ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _marks.containsKey(students[i].studentId)
                        ? Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.6,
                          )
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              for (final status in SessionAttendanceStatus.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 18,
                        ),
                        textStyle:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      onPressed: () => _mark(current, status),
                      child: Text(status.label(context.tr)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _mark(
    SessionStudentRow row,
    SessionAttendanceStatus status,
  ) async {
    final previousStatus = _marks[row.studentId] ?? row.status;
    setState(() {
      _marks[row.studentId] = status;
    });

    final saved = await widget.controller.recordAttendance(row, status);
    if (!mounted) {
      return;
    }

    if (!saved) {
      setState(() {
        if (previousStatus == null) {
          _marks.remove(row.studentId);
        } else {
          _marks[row.studentId] = previousStatus;
        }
        _showSummary = false;
      });
      final message = widget.controller.saveMessage.value;
      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    final students = widget.controller.students.value;
    setState(() {
      if (_allMarked(students)) {
        _showSummary = true;
        return;
      }
      _index = _firstUnmarkedIndex(students);
    });
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({
    required this.students,
    required this.marks,
    required this.counts,
    required this.onDone,
    required this.onReviewAgain,
  });

  final List<SessionStudentRow> students;
  final Map<String, SessionAttendanceStatus> marks;
  final Map<SessionAttendanceStatus, int> counts;
  final VoidCallback onDone;
  final VoidCallback onReviewAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr.attendanceComplete,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final status in SessionAttendanceStatus.values)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '${counts[status] ?? 0}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(status.label(context.tr)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = students[index];
                final status = marks[row.studentId];
                return ListTile(
                  leading: PersonAvatar(
                    name: row.studentName,
                    initials: row.studentInitials,
                    photoUrl: row.photoUrl,
                  ),
                  title: Text(row.studentName),
                  trailing: status == null
                      ? null
                      : Chip(label: Text(status.label(context.tr))),
                );
              },
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ),
            onPressed: onDone,
            child: Text(context.tr.done),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ),
            onPressed: onReviewAgain,
            child: Text(context.tr.reviewAgain),
          ),
        ],
      ),
    );
  }
}
