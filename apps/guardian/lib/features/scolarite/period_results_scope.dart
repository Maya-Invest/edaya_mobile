import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../live/prototype_runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'period_results_controller.dart';

PeriodResultsController periodResultsFor(LevitScope scope, String? period) {
  if (scope.find<PrototypeRuntime>().live) {
    return PeriodResultsController(
      client: scope.find<SchoolClientFactory>()(),
      studentId: scope.find<StudentContextController>().activeStudentId!,
      yearId: scope.find<AcademicYearController>().selectedYearId.value!,
      initialPeriod: period,
    );
  }
  final store = scope.find<MockStore>();
  return PeriodResultsController(
    studentId: store.activeStudentId,
    yearId: store.selectedYear,
    initialPeriod: period ?? store.selectedPeriodId,
    periodLoader: () async => [
      for (final p in store.academicPeriods) {'id': p.id, 'name': p.label},
    ],
    resultLoader: (id) async {
      final label = store.periodById(id)?.label ?? '';
      final subjects = store.subjectResultsForPeriod(label);
      return {
        'state': 'provisional',
        'calculationReady': true,
        'sections': [
          {
            'sectionId': 'academics',
            'sectionKind': 'module',
            'name': 'Enseignements',
            'subResults': [
              for (final s in subjects)
                {
                  'sectionId': 'subject:${s.subject}',
                  'sectionKind': 'subject',
                  'subjectId': s.subject,
                  'classSubjectId': s.subject,
                  'name': s.subject,
                  'coefficient': 1,
                  'average': s.average,
                },
            ],
          },
        ],
        'marks': [
          for (final g in store.gradesForPeriod(label))
            {
              'id': g.id,
              'subjectId': g.subject,
              'classSubjectId': g.subject,
              'title': g.title,
              'date': g.date.toIso8601String(),
              'score': g.score,
              'maxScore': g.maxScore,
              'coefficient': g.coefficient,
              'designation': 'scored',
            },
        ],
      };
    },
  );
}
