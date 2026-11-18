part of 'demo_school.dart';

extension DemoTeaching on DemoSchool {
  List<Row> contributions(dynamic student, dynamic subject, dynamic period) => [
    for (final mark in matching('assessment-results', {'studentId': student}))
      if (one('assessments', mark['assessmentId']) case final assessment
          when assessment['classSubjectId'] == subject &&
              assessment['periodId'] == period &&
              assessment['marksStatus'] == 'submitted')
        {...assessment, ...mark},
  ];
  Row attendanceCall(Row anchor) {
    final lesson = anchor['lessonSessionId'];
    final group =
        anchor['classGroupId'] ??
        one('lesson-sessions', lesson)['classGroupId'];
    final day = (anchor['date'] ?? one('lesson-sessions', lesson)['startsAt'])
        .toString()
        .substring(0, 10);
    final id = lesson ?? '$group/$day';
    final saved = matching('calls', {'id': id}).firstOrNull;
    final records = matching(
      'attendance',
      lesson == null
          ? {'classGroupId': group, 'date': day, 'scope': 'daily'}
          : {'lessonSessionId': lesson},
    );
    return {
      'id': id,
      'classGroupId': group,
      'date': day,
      'students': roster(group),
      'version': 0,
      'submitted': records.isNotEmpty,
      'entries': [],
      ...?saved,
      'records': [
        for (final r in records)
          {
            ...r,
            'pendingCorrection': matching('corrections', {
              'targetId': r['id'],
              'status': 'pending',
            }).firstOrNull,
          },
      ],
    };
  }

  Object? teachingQuery(String name, Row b) {
    switch (name) {
      case 'get-teacher-attendance-call':
        return attendanceCall(b['anchor']);
      case 'get-teacher-workflow-state':
        final p = b['proposal'] as Map;
        if (p['workflow'] == 'discipline') {
          final row = one('incidents', p['targetId']);
          final ids = matching('student-incident-involvements', {
            'incidentId': row['id'],
          }).map((r) => r['studentId']).toList();
          return {
            'version': row['version'] ?? 0,
            'locked': row['status'] == 'closed',
            'official': {
              ...row,
              'workflow': 'discipline',
              'targetId': row['id'],
              'studentIds': ids,
            },
            'context': {
              'students': [
                for (final id in ids) {'id': id, 'name': studentName(id)},
              ],
            },
            'history': matching('incident-history', {'incidentId': row['id']}),
            'corrections': matching('corrections', {'targetId': row['id']}),
          };
        }
        final logbook = p['workflow'] == 'logbook';
        final source = one(
          logbook ? 'lesson-sessions' : 'results',
          p['targetId'],
        );
        return {
          'version': source['version'] ?? 0,
          'locked': logbook
              ? source['validated'] == true
              : source['status'] == 'published',
          'official': {
            ...source,
            'progress': [
              for (final row
                  in (source['progress'] as List? ?? []).whereType<Map>())
                if (row['completed'] is bool ||
                    (row['completedPercentage'] as num? ?? 0) > 0)
                  {
                    ...row,
                    'completed':
                        row['completed'] ?? (row['completedPercentage'] == 100),
                  },
            ],
            'sections': source['sectionResults'] ?? [],
          },
          'corrections': matching('corrections', {'targetId': p['targetId']}),
        };
      case 'get-assessment-marks-review':
        final sheet = one('assessments', b['assessmentId']);
        return {
          'assessment': sheet,
          'students': roster(sheet['classGroupId']),
          'results': matching('assessment-results', {
            'assessmentId': sheet['id'],
          }),
          'allowedActions': {
            'submit': sheet['marksStatus'] == 'draft',
            'requestCorrection': sheet['marksStatus'] == 'submitted',
          },
          'corrections': matching('corrections', {'targetId': sheet['id']}),
          'publishedResultIds': [],
        };
      case 'get-teacher-subject-period-summary':
        final subject = one('class-subjects', b['classSubjectId']);
        return {
          'students': roster(subject['classGroupId']).map((student) {
            final marks = contributions(
              student['id'],
              subject['id'],
              b['periodId'],
            );
            double sum = 0, weights = 0;
            for (final m in marks) {
              if (m['score'] is! num) continue;
              final weight = (m['coefficient'] as num).toDouble();
              sum += 20 * (m['score'] as num) / (m['maxScore'] as num) * weight;
              weights += weight;
            }
            final report = matching('results', {
              'studentId': student['id'],
              'periodId': b['periodId'],
            }).firstOrNull;
            final comment = (report?['sectionResults'] as List?)
                ?.where((s) => s['classSubjectId'] == subject['id'])
                .firstOrNull;
            return {
              ...student,
              'studentId': student['id'],
              'average': weights == 0 ? null : sum / weights,
              'contributions': marks,
              if (comment != null)
                'comment': {
                  'text': comment['comment'] ?? '',
                  'sectionId': comment['sectionId'],
                  'resultId': report!['id'],
                },
            };
          }).toList(),
        };
      case 'list-teacher-family-feedback-results':
      case 'get-teacher-family-feedback-result':
        final result = {
          'campaignId': 'demo-feedback',
          'classGroupId': 'demo-class-a',
          'classSubjectId': 'demo-math-a',
          'academicYearId': year,
          'academicPeriodId': 'demo-t1',
          'eligibleSlotCount': 12,
          'completedSlotCount': 9,
          'responseRate': 0.75,
          'overallSuppressed': false,
          'themes': 'Les familles apprécient les exercices de révision.',
          'questions': [
            {
              'questionId': 'clarity',
              'suppressed': false,
              'nScored': 9,
              'distribution': {'4': 3, '5': 6},
            },
          ],
        };
        return name.startsWith('list') ? [result] : result;
      default:
        throw ApiError(404, name);
    }
  }

  void checkVersion(dynamic expected, dynamic current) {
    if (expected != null && expected != current) {
      throw ApiError(409, 'VERSION_CONFLICT');
    }
  }

  Object? teachingCommand(String name, Row b) {
    switch (name) {
      case 'save-teacher-attendance-draft':
      case 'submit-teacher-attendance':
        final anchor = b['anchor'] as Row, call = attendanceCall(anchor);
        checkVersion(b['expectedVersion'], call['version']);
        if (call['submitted'] == true) {
          throw ApiError(409, 'ATTENDANCE_SUBMITTED');
        }
        final submit = name == 'submit-teacher-attendance';
        final entries = (b['entries'] ?? call['entries']) as List;
        if (submit && entries.length != (call['students'] as List).length) {
          throw ApiError(409, 'INCOMPLETE_ATTENDANCE');
        }
        if (submit) {
          for (final row in entries) {
            put('attendance', {
              ...row,
              'id': "${call['id']}-${row['studentId']}",
              'academicYearId': year,
              'schoolId': DemoSchool.school,
              'date': call['date'],
              'classGroupId': call['classGroupId'],
              'scope': anchor['kind'],
              'lessonSessionId': anchor['lessonSessionId'],
              'workflowVersion': 0,
            });
          }
        }
        return put('calls', {
          'id': call['id'],
          'version': call['version'] + 1,
          'submitted': submit,
          'entries': entries,
        });
      case 'record-teacher-attendance-arrival':
      case 'record-teacher-attendance-departure':
        final record = one('attendance', b['recordId']);
        checkVersion(b['expectedVersion'], record['workflowVersion']);
        return put('attendance', {
          'id': record['id'],
          'workflowVersion': record['workflowVersion'] + 1,
          if (name.endsWith('arrival')) ...{
            'arrivedAt': b['occurredAt'],
            'status': 'late',
          } else
            'departedAt': b['occurredAt'],
        });
      case 'save-teacher-logbook':
        final p = b['proposal'] as Row,
            lesson = one('lesson-sessions', p['targetId']);
        checkVersion(b['expectedVersion'], lesson['version'] ?? 0);
        final entries = (p['progress'] as List).cast<Map>();
        final all = rows('class-subject-progress');
        all.removeWhere(
          (row) =>
              row['lessonSessionId'] == lesson['id'] &&
              !entries.any(
                (item) => item['matterId'] == row['classSubjectMatterId'],
              ),
        );
        for (final item in entries) {
          put('class-subject-progress', {
            'id': "${lesson['id']}-${item['matterId']}",
            'lessonSessionId': lesson['id'],
            'classSubjectMatterId': item['matterId'],
            'completed': item['completed'],
            'notes': item['notes'],
          });
        }
        final chapters = matching('class-subject-matters', {
          'classSubjectId': lesson['classSubjectId'],
        });
        var ongoing = 0, finished = 0;
        double total = 0, earned = 0;
        for (final chapter in chapters) {
          final evidence = matching('class-subject-progress', {
            'classSubjectMatterId': chapter['id'],
          });
          final done = evidence.any((entry) => entry['completed'] == true);
          final covered = evidence.any((entry) => entry['completed'] is bool);
          final score = done
              ? 1.0
              : covered
              ? 0.5
              : 0.0;
          final weight =
              (one(
                        'subject-matters',
                        chapter['subjectMatterId'],
                      )['progressWeight']
                      as num?)
                  ?.toDouble() ??
              1.0;
          total += weight;
          earned += score * weight;
          if (done) {
            finished++;
          } else if (covered) {
            ongoing++;
          }
          put('class-subject-matters', {
            'id': chapter['id'],
            'status': done
                ? 'completed'
                : covered
                ? 'in_progress'
                : 'not_started',
            'completedPercentage': (score * 100).round(),
          });
        }
        put('class-subjects', {
          'id': lesson['classSubjectId'],
          'completedPercentage': total == 0
              ? 0
              : (100 * earned / total).round(),
          'chapterCount': chapters.length,
          'completedChapterCount': finished,
          'ongoingChapterCount': ongoing,
        });
        return put('lesson-sessions', {
          'id': lesson['id'],
          'version': (lesson['version'] ?? 0) + 1,
          'sessionNote': p['sessionNote'],
          'progress': p['progress'],
        });
      case 'create-assessment':
        return put('assessments', {
          ...b,
          'schoolId': DemoSchool.school,
          'teacherId': actor,
          'academicYearId': year,
          'marksStatus': 'draft',
          'marksRevision': 0,
        });
      case 'record-assessment-result':
      case 'record-assessment-results':
      case 'submit-assessment-marks':
        final sheet = one('assessments', b['assessmentId']);
        checkVersion(b['expectedRevision'], sheet['marksRevision']);
        if (sheet['marksStatus'] != 'draft') {
          throw ApiError(409, 'MARKS_SUBMITTED');
        }
        if (name == 'submit-assessment-marks') {
          final entries = matching('assessment-results', {
            'assessmentId': sheet['id'],
          });
          final complete = entries
              .where(
                (r) =>
                    r['score'] != null ||
                    r['mentionId'] != null ||
                    ['absent', 'exempt'].contains(r['designation']),
              )
              .map((r) => r['studentId'])
              .toSet();
          if (!roster(
            sheet['classGroupId'],
          ).every((s) => complete.contains(s['id']))) {
            throw ApiError(409, 'INCOMPLETE_MARKS');
          }
          return put('assessments', {
            'id': sheet['id'],
            'marksStatus': 'submitted',
            'marksRevision': sheet['marksRevision'] + 1,
          });
        }
        final values = (b['results'] as List? ?? [b]).cast<Row>();
        final saved = [
          for (final r in values)
            put('assessment-results', {
              ...r,
              'assessmentId': sheet['id'],
              'id': r['id'] ?? "${sheet['id']}-${r['studentId']}",
            }),
        ];
        put('assessments', {
          'id': sheet['id'],
          'marksRevision': sheet['marksRevision'] + saved.length,
        });
        return name.endsWith('results') ? saved : saved.single;
      case 'request-assessment-marks-correction':
      case 'revise-assessment-marks-correction':
      case 'withdraw-assessment-marks-correction':
      case 'request-teacher-correction':
      case 'revise-teacher-correction':
      case 'withdraw-teacher-correction':
        final previous = b['correctionId'] == null
            ? null
            : one('corrections', b['correctionId']);
        if (previous != null) {
          checkVersion(b['expectedVersion'], previous['version']);
        }
        final proposal =
            b['proposal'] ??
            previous?['proposal'] ??
            {
              'workflow': 'marks',
              'targetId': b['assessmentId'],
              'changes': b['changes'],
            };
        return put('corrections', {
          ...?previous,
          ...b,
          'id': previous?['id'] ?? newId('corrections'),
          'targetId': proposal['targetId'],
          'allowedActions': {'withdraw': true, 'revise': true},
          'proposal': proposal,
          'status': name.startsWith('withdraw') ? 'withdrawn' : 'pending',
          'version': (previous?['version'] ?? 0) + 1,
        });
      case 'write-homeroom-report-comment':
      case 'write-report-card-section-comments':
        final r = one('results', b['id']);
        checkVersion(b['expectedVersion'], r['version']);
        if (r['status'] == 'published') throw ApiError(409, 'REPORT_PUBLISHED');
        final sections = (r['sectionResults'] as List).cast<Row>();
        for (final entry in b['sections'] as List? ?? []) {
          sections.firstWhere(
            (s) => s['sectionId'] == entry['sectionId'],
          )['comment'] = entry['comment'];
        }
        return put('results', {
          'id': r['id'],
          'version': r['version'] + 1,
          if (b.containsKey('teacherComment'))
            'teacherComment': b['teacherComment'],
        });
      case 'append-incident-follow-up':
        one('incidents', b['incidentId']);
        return put('incident-history', {
          'id': newId('incident-history'),
          'incidentId': b['incidentId'],
          'action': 'follow_up',
          'createdAt': DemoSchool.time,
          'payload': {'text': b['text']},
        });
      case 'edit-teacher-incident':
        final proposal = b['proposal'] as Row;
        final record = one('incidents', proposal['targetId']);
        checkVersion(b['expectedVersion'], record['version'] ?? 0);
        if (record['status'] == 'closed') {
          throw ApiError(409, 'INCIDENT_LOCKED');
        }
        (data['student-incident-involvements'] as List).removeWhere(
          (r) => r['incidentId'] == record['id'],
        );
        for (final id in proposal['studentIds']) {
          put('student-incident-involvements', {
            'id': "${record['id']}-$id",
            'incidentId': record['id'],
            'studentId': id,
            'role': 'subject',
          });
        }
        return put('incidents', {
          ...proposal,
          'id': record['id'],
          'version': (record['version'] ?? 0) + 1,
        });
      case 'record-attendance':
        return put('attendance', {...b, 'academicYearId': year});
      case 'record-lesson-session-progress':
        return put('class-subject-progress', b);
      case 'complete-assessment':
        one('assessments', b['assessmentId']);
        return put('assessments', {
          'id': b['assessmentId'],
          'status': 'completed',
          'completedAt': DemoSchool.time,
        });
      case 'record-incident':
        return put('incidents', {
          ...b,
          'reporterId': actor,
          'teacherId': actor,
          'academicYearId': year,
          'status': 'open',
        });
      case 'add-student-involvement':
        return put('student-incident-involvements', b);
      default:
        throw ApiError(404, name);
    }
  }
}
