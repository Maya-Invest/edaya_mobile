import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'models/session_detail_models.dart';

class AttendanceExceptionResult {
  const AttendanceExceptionResult({
    required this.status,
    this.reason,
    this.notes,
  });

  final SessionAttendanceStatus status;
  final String? reason;
  final String? notes;
}

Future<AttendanceExceptionResult?> showAttendanceExceptionSheet({
  required BuildContext context,
  required SessionStudentRow row,
  SessionAttendanceStatus? initialStatus,
}) {
  return showModalBottomSheet<AttendanceExceptionResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AttendanceExceptionSheet(
      row: row,
      initialStatus: initialStatus ?? row.status ?? SessionAttendanceStatus.present,
    ),
  );
}

class AttendanceExceptionSheet extends StatefulWidget {
  const AttendanceExceptionSheet({
    super.key,
    required this.row,
    required this.initialStatus,
  });

  final SessionStudentRow row;
  final SessionAttendanceStatus initialStatus;

  @override
  State<AttendanceExceptionSheet> createState() =>
      _AttendanceExceptionSheetState();
}

class _AttendanceExceptionSheetState extends State<AttendanceExceptionSheet> {
  late SessionAttendanceStatus _status;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _reasonController = TextEditingController(text: widget.row.reason ?? '');
    _notesController = TextEditingController(text: widget.row.notes ?? '');
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _showsExceptionFields =>
      _status == SessionAttendanceStatus.absent ||
      _status == SessionAttendanceStatus.late;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr.attendanceExceptionTitle(widget.row.studentName),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<SessionAttendanceStatus>(
            segments: [
              for (final status in SessionAttendanceStatus.values)
                ButtonSegment(
                  value: status,
                  label: Text(status.label(context.tr)),
                ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) {
              setState(() => _status = selection.first);
            },
          ),
          if (_showsExceptionFields) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: context.tr.attendanceReasonLabel,
                hintText: context.tr.attendanceReasonHint,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.tr.attendanceNotesLabel,
                hintText: context.tr.attendanceNotesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                AttendanceExceptionResult(
                  status: _status,
                  reason: _normalize(_reasonController.text),
                  notes: _normalize(_notesController.text),
                ),
              );
            },
            child: Text(context.tr.save),
          ),
        ],
      ),
    );
  }

  String? _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
