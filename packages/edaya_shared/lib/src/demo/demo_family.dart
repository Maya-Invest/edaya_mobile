part of 'demo_school.dart';

extension DemoFamily on DemoSchool {
  Object? familyQuery(String name, Row b) {
    final student = b['studentId'];
    switch (name) {
      case 'get-student-finance-summary':
        final charges = matching('student-charges', {
          'studentId': student,
          'academicYearId': b['academicYearId'] ?? year,
        });
        final balance = charges.fold<num>(
          0,
          (total, r) => total + r['expectedAmount'] - r['allocatedAmount'],
        );
        return {
          'accountId': '$student-account',
          'currency': 'XOF',
          'available': 0,
          'outstanding': balance,
          'overdue': 0,
        };
      case 'get-payment-settlement-history':
        final accounts = rows(
          'guardian-links',
        ).map((r) => "${r['studentId']}-account");
        if (!accounts.contains(b['accountId'])) {
          throw ApiError(403, 'Unlinked account');
        }
        return {
          'payments': matching('payments', {'accountId': b['accountId']}),
          'allocations': matching('allocations', {'accountId': b['accountId']}),
        };
      case 'get-guardian-assessment-result':
        final assessment = one('assessments', b['assessmentId']);
        final result =
            assessment['marksStatus'] == 'submitted' && linked(student)
            ? submittedResults(
                assessment,
              ).where((row) => row['studentId'] == student).firstOrNull
            : null;
        return {
          'mark': result == null
              ? null
              : {
                  ...result,
                  'maxScore': assessment['maxScore'],
                  if (result['score'] is num)
                    'grading': demoGrade(
                      20 *
                          (result['score'] as num) /
                          (assessment['maxScore'] as num),
                    ),
                },
        };
      case 'get-guardian-period-results':
        final report = matching('results', {
          'studentId': student,
          'periodId': b['periodId'],
          'academicYearId': year,
        }).firstOrNull;
        if (report == null) {
          return {
            'state': 'provisional',
            'sections': [],
            'marks': [],
            'calculationReady': false,
          };
        }
        final published = report['status'] == 'published';
        final marks = <Row>[];
        for (final result in matching('assessment-results', {
          'studentId': student,
        })) {
          final assessment = one('assessments', result['assessmentId']);
          if (assessment['periodId'] != b['periodId'] ||
              assessment['marksStatus'] != 'submitted') {
            continue;
          }
          marks.add({
            ...assessment,
            ...submittedResults(
              assessment,
            ).firstWhere((r) => r['id'] == result['id']),
            if (result['score'] is num)
              'grading': demoGrade(
                20 * (result['score'] as num) / (assessment['maxScore'] as num),
              ),
            'subjectId': 'demo-math',
            'date': assessment['startsAt'],
          });
        }
        Row sectionResult(Row section) {
          if (published) return section;
          final summary =
              teachingQuery('get-teacher-subject-period-summary', {
                    'periodId': b['periodId'],
                    'classSubjectId': section['classSubjectId'],
                  })
                  as Map;
          final own = (summary['students'] as List)
              .whereType<Map>()
              .where((row) => row['studentId'] == student)
              .firstOrNull;
          return {
            ...section,
            'comment': null,
            if (own != null)
              for (final key in [
                'rank',
                'participantCount',
                'grading',
                'average',
              ])
                key: own[key],
          };
        }
        return {
          'state': published ? 'published' : 'provisional',
          'reportId': published ? report['id'] : null,
          'calculationReady': true,
          'average': report['average'],
          'grading':
              report['grading'] ??
              demoGrade((report['average'] as num).toDouble()),
          'sections': [
            for (final section in report['sectionResults'])
              sectionResult(Map<String, dynamic>.from(section as Map)),
          ],
          'marks': marks,
          if (published) 'teacherComment': report['teacherComment'],
        };
      case 'list-guardian-family-feedback-campaigns':
        return rows(
          'surveys',
        ).where((s) => linked(s['studentId']) && year == 'demo-2026').toList();
      case 'get-guardian-family-feedback-questionnaire':
        final survey = one('surveys', b['campaignId']);
        if (survey['studentId'] != student) throw ApiError(404, name);
        final en = b['locale'] == 'en';
        return {
          ...survey,
          'instrument': {
            'version': '1',
            'intro': en
                ? 'Tell us about mathematics lessons.'
                : 'Votre avis sur les cours de mathématiques.',
            'scaleLabels': {
              for (var i = 1; i <= 5; i++) '$i': '$i',
              'cannot_assess': en ? 'Cannot assess' : 'Je ne peux pas évaluer',
            },
            'commentPrompt': en
                ? 'Please avoid naming other students.'
                : 'Évitez de nommer d’autres élèves.',
            'items': [
              {
                'id': 'clarity',
                'stem': en
                    ? 'The homework instructions are clear.'
                    : 'Les consignes des devoirs sont claires.',
              },
            ],
          },
        };
      default:
        throw ApiError(404, name);
    }
  }

  Object? familyCommand(String name, Row b) {
    switch (name) {
      case 'submit-family-feedback-response':
        final survey = one('surveys', b['campaignId']);
        if (survey['studentId'] != b['studentId'] ||
            survey['slotState'] != 'open') {
          throw ApiError(409, 'Survey already completed');
        }
        return put('surveys', {
          'id': survey['id'],
          'slotState': 'completed',
          'receipt': {'completedAt': DemoSchool.time},
          'answers': b['answers'],
          'comment': b['comment'],
        });
      case 'submit-student-photo':
        if (matching('student-photo-submissions', {
          'studentId': b['studentId'],
          'status': 'pending',
        }).isNotEmpty) {
          throw ApiError(409, 'PHOTO_PENDING');
        }
        return put('student-photo-submissions', {
          ...b,
          'id': newId('student-photo-submissions'),
          'submitterGuardianId': actor,
          'version': 1,
          'status': 'pending',
          'createdAt': DemoSchool.time,
        });
      case 'withdraw-student-photo-submission':
        final submission = one('student-photo-submissions', b['submissionId']);
        if (submission['submitterGuardianId'] != actor ||
            submission['status'] != 'pending' ||
            submission['version'] != b['expectedVersion']) {
          throw ApiError(409, 'PHOTO_CHANGED');
        }
        return put('student-photo-submissions', {
          'id': b['submissionId'],
          'status': 'withdrawn',
          'version': (b['expectedVersion'] as int) + 1,
        });
      default:
        throw ApiError(404, name);
    }
  }
}
