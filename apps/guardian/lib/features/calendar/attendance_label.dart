import 'package:edaya_shared/edaya_shared.dart';

String attendanceLabel(AppLocalizations tr, String? status) => switch (status) {
  'present' || 'Présent' => tr.attendanceStatusPresent,
  'absent' || 'Absent' => tr.attendanceStatusAbsent,
  'late' || 'Retard' => tr.attendanceStatusLate,
  'excused' || 'Excusé' => tr.deadlineExcused,
  null => tr.notRecorded,
  _ => status,
};
