part of 'demo_school.dart';

extension DemoFamily on DemoSchool {
  Row childPhoto(Row input) {
    final student = one('students', input['studentId']);
    final rows = matching('student-photo-submissions', {
      'studentId': student['id'],
    });
    final pending = rows.where((row) => row['status'] == 'pending').firstOrNull;
    final Row decision;
    if (pending != null) {
      decision = {
        'status': 'pending',
        'ownSubmission': pending['submitterGuardianId'] == actor
            ? {
                for (final key in ['id', 'attachmentId', 'version'])
                  key: pending[key],
              }
            : null,
      };
    } else {
      String reviewedAt(Row row) =>
          (row['reviewedAt'] ?? row['updatedAt'] ?? row['createdAt'] ?? '')
              as String;
      final reviewed =
          rows
              .where(
                (row) => const {'approved', 'rejected'}.contains(row['status']),
              )
              .toList()
            ..sort((a, b) {
              final byTime = reviewedAt(b).compareTo(reviewedAt(a));
              return byTime == 0
                  ? (b['id'] as String).compareTo(a['id'] as String)
                  : byTime;
            });
      final latest = reviewed.firstOrNull;
      decision =
          latest?['status'] == 'rejected' &&
              latest?['submitterGuardianId'] == actor
          ? {'status': 'rejected', 'reason': latest?['rejectionReason']}
          : {'status': 'none'};
    }
    return {
      'academicYearId': year,
      'student': {
        for (final key in [
          'id',
          'schoolId',
          'firstName',
          'lastName',
          'status',
          'identifier',
          'photoUrl',
        ])
          key: student[key],
      },
      'decision': decision,
    };
  }

  Row familyPapers(Row input) {
    final pupil = input['studentId'] as String;
    final rows =
        matching('document-issuances', {
              'academicYearId': year,
              'studentId': pupil,
              'status': 'ready',
            })
            .where(
              (row) =>
                  visible('document-issuances', row) &&
                  isLeftoverFamilyPaper(row['templateKey'] as String),
            )
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    String? after;
    final cursor = input['cursor'];
    if (cursor != null) {
      try {
        final parts = jsonDecode(cursor as String);
        if (parts is! List ||
            parts.length != 4 ||
            parts[0] != actor ||
            parts[1] != pupil ||
            parts[2] != year ||
            parts[3] is! String) {
          throw const FormatException();
        }
        after = parts[3] as String;
      } on FormatException {
        throw ApiError(400, 'Invalid family paper cursor');
      }
    }
    final remaining = rows
        .where((r) => after == null || (r['id'] as String).compareTo(after) > 0)
        .take(31)
        .toList();
    final page = remaining.take(30).toList();
    return {
      'academicYearId': year,
      'studentId': pupil,
      'items': [
        for (final r in page)
          {
            for (final key in [
              'id',
              'sourceId',
              'templateKey',
              'number',
              'status',
            ])
              key: r[key],
          },
      ],
      'nextCursor': remaining.length > page.length
          ? jsonEncode([actor, pupil, year, page.last['id']])
          : null,
    };
  }

  Row occurrenceDetail(Row input) {
    const missing = {'occurrence': null};
    final pupil = {
      'studentId': input['studentId'],
      'academicYearId': input['academicYearId'],
    };
    final id = input['occurrenceId'];
    const tables = {
      'lesson': 'lesson-sessions',
      'assessment': 'assessments',
      'activity': 'activity-sessions',
    };
    for (final kind in {
      if (tables.containsKey(input['kind'])) input['kind'] as String,
      ...tables.keys,
    }) {
      final row = matching(tables[kind]!, {
        'id': id,
        'academicYearId': pupil['academicYearId'],
      }).firstOrNull;
      if (row == null) continue;
      if (kind == 'assessment' &&
          (row['kind'] == 'homework' || row['dueAt'] != null)) {
        continue;
      }
      final anchor = row['lessonSessionId'] == null
          ? null
          : matching('lesson-sessions', {
              'id': row['lessonSessionId'],
              'classGroupId': row['classGroupId'],
            }).firstOrNull;
      final times = row['endsAt'] != null && row['startsAt'] != null
          ? row
          : anchor;
      if (times == null) continue;
      final start = DateTime.parse(times['startsAt'] as String);
      final past = !DateTime.parse(
        times['endsAt'] as String,
      ).isAfter(SchoolClock.now());
      if (past && row['status'] == 'cancelled') return missing;
      final placements = matching('enrollments', {
        ...pupil,
        'classGroupId': row['classGroupId'],
      });
      if (placements.isEmpty) return missing;
      final active = placements.any(
        (p) =>
            !start.isBefore(DateTime.parse(p['enrolledAt'])) &&
            (p['endedAt'] == null ||
                start.isBefore(DateTime.parse(p['endedAt']))),
      );
      final subject = row['classSubjectId'] as String?;
      final anchorField = {
        'lesson': 'lessonSessionId',
        'activity': 'activitySessionId',
        'assessment': 'assessmentId',
      }[kind]!;
      final attendance = matching('attendance', {
        'studentId': pupil['studentId'],
        anchorField: id,
      }).firstOrNull;
      final enrolled =
          subject == null ||
          StudentSubjectParticipation(
            matching('subject-enrollments', pupil),
            [],
          ).includes(subject, start);
      final saved =
          past &&
          subject != null &&
          (attendance != null ||
              (kind == 'assessment' &&
                  matching('assessment-results', {
                    'assessmentId': id,
                    'studentId': pupil['studentId'],
                  }).isNotEmpty));
      if (!(active && enrolled) && !saved) return missing;
      final progress = kind == 'lesson' && subject != null
          ? matching('class-subject-progress', {'lessonSessionId': id})
          : <Row>[];
      final rawNote = row['sessionNote'] as String?;
      final decoded = decodeStructuredSessionNote(rawNote);
      final content = decoded.content.startsWith(structuredLogbookPrefix)
          ? ''
          : decoded.guardianText;
      final chapters = <Row>[];
      for (final entry in progress) {
        final link = matching('class-subject-matters', {
          'id': entry['classSubjectMatterId'],
          'classSubjectId': subject,
        }).firstOrNull;
        final label = link == null
            ? null
            : matching('subject-matters', {
                'id': link['subjectMatterId'],
              }).firstOrNull?['name'];
        chapters.add({
          'name': label,
          'completed': entry['completed'],
          'notes': entry['notes'],
        });
      }
      return {
        'occurrence': {
          'id': id,
          'kind': kind,
          'title': row['displayLabel'] ?? row['title'],
          'classSubjectId': subject,
          'subjectLabel': kind == 'lesson' ? row['displayLabel'] : null,
          'startsAt': times['startsAt'],
          'endsAt': times['endsAt'],
          'status': row['status'],
          'attendance': attendance == null
              ? null
              : {
                  for (final key in [
                    'id',
                    'date',
                    'status',
                    'reason',
                    anchorField,
                  ])
                    key: attendance[key],
                  'justificationStatus':
                      attendance['justificationStatus'] ?? 'none',
                },
          'logbook':
              kind == 'lesson' &&
                  subject != null &&
                  (content.isNotEmpty || chapters.isNotEmpty)
              ? {'content': content, 'chapters': chapters}
              : null,
          'activityNotes': kind == 'activity' ? row['notes'] : null,
          'assessment': kind == 'assessment'
              ? {
                  'description': row['description'],
                  'maxScore': row['maxScore'],
                  'coefficient': row['coefficient'] ?? 1,
                  'mark':
                      (familyQuery('get-guardian-assessment-result', {
                            'studentId': pupil['studentId'],
                            'assessmentId': id,
                          })
                          as Row)['mark'],
                }
              : null,
        },
      };
    }
    return missing;
  }

  Row paymentDetail(Row input) {
    final pupil = {
      'studentId': input['studentId'],
      'academicYearId': input['academicYearId'],
    };
    final account = "${input['studentId']}-account";
    final payment = matching('payments', {
      ...pupil,
      'id': input['paymentId'],
      'accountId': account,
    }).firstOrNull;
    if (payment == null) return {'payment': null};
    final charges = {
      for (final c in matching('student-charges', pupil)) c['id']: c['label'],
    };
    final allocations = matching('allocations', {
      'accountId': account,
      'causedByPaymentId': payment['id'],
    });
    return {'payment': _paymentPreview(payment, charges, allocations)};
  }

  String _stamp(String date) => DateTime.parse(
    date.length == 10 ? '${date}T00:00:00Z' : date,
  ).toUtc().toIso8601String();

  Row _paymentPreview(
    Row payment,
    Map<dynamic, dynamic> charges,
    List<Row> allocations,
  ) {
    allocations.sort(
      (a, b) => (a['id'] as String).compareTo(b['id'] as String),
    );
    final labels = <String>{};
    for (final allocation in allocations) {
      final label = charges[allocation['chargeId']];
      if (allocation['kind'] != 'reverse' &&
          label is String &&
          label.isNotEmpty) {
        labels.add(label);
      }
    }
    return {
      for (final key in [
        'id',
        'currency',
        'amount',
        'method',
        'status',
        'reference',
      ])
        key: payment[key],
      'kind': payment['kind'] ?? 'receipt',
      'paymentDate': _stamp(payment['paymentDate']),
      'chargeLabels': labels.toList(),
    };
  }

  Row _pupil(Row input) => {
    'studentId': input['studentId'],
    'academicYearId': input['academicYearId'],
  };

  Row _financeScope(Row pupil) {
    final payments = matching('payments', pupil);
    return {
      ...pupil,
      'accountId': payments.firstOrNull?['accountId'],
      'currency': 'XOF',
    };
  }

  Row feesSummary(Row input) {
    final pupil = _pupil(input);
    var expected = 0, paid = 0, outstanding = 0, overdue = 0, overdueCount = 0;
    for (final c in matching('student-charges', pupil)) {
      if (c['status'] == 'cancelled') continue;
      final billed = c['expectedAmount'] as int,
          allocated = c['allocatedAmount'] as int;
      final net =
          billed -
          (c['adjustmentAmount'] as int? ?? 0) -
          (c['waiverAmount'] as int? ?? 0);
      final remaining = (net - allocated).clamp(0, billed);
      expected += billed;
      paid += allocated;
      outstanding += remaining;
      if (c['status'] == 'overdue') overdueCount++;
      final installments = (c['installments'] as List? ?? []).cast<Row>();
      final installmentsDue =
          (installments.isEmpty
                  ? [
                      {'dueDate': c['dueDate'], 'expectedAmount': net},
                    ]
                  : installments)
              .where(
                (i) =>
                    i['dueDate'] != null &&
                    DateTime.parse(
                      _stamp(i['dueDate']),
                    ).isBefore(DateTime.parse(DemoSchool.time)),
              )
              .fold<int>(0, (sum, i) => sum + (i['expectedAmount'] as int));
      overdue += (installmentsDue - allocated).clamp(0, remaining);
    }
    return {
      ..._financeScope(pupil),
      'available': 0,
      'outstanding': outstanding,
      'overdue': overdue,
      'expected': expected,
      'paid': paid,
      'overdueCount': overdueCount,
    };
  }

  Row settlementPage(Row input) {
    final pupil = _pupil(input), scope = _financeScope(pupil);
    final limit = int.tryParse((input['limit'] ?? 30).toString());
    if (limit == null || limit < 1 || limit > 100) {
      throw ApiError(400, 'Invalid limit');
    }
    final prefix = [
      DemoSchool.school,
      pupil['studentId'],
      pupil['academicYearId'],
      scope['accountId'],
    ];
    List? boundary;
    if (input['cursor'] != null) {
      try {
        final cursor = jsonDecode(input['cursor']) as List;
        if (cursor.length != 8 ||
            !prefix.indexed.every((e) => cursor[e.$1] == e.$2) ||
            !['payments', 'charges'].contains(cursor[4]) ||
            cursor[6] is! String ||
            cursor[7] is! String ||
            (cursor[5] == null
                ? cursor[4] == 'payments'
                : DateTime.tryParse(cursor[5]) == null)) {
          throw const FormatException();
        }
        boundary = cursor;
      } on Object {
        throw ApiError(400, 'Invalid settlement cursor');
      }
    }
    final charges = matching(
      'student-charges',
      pupil,
    ).where((c) => c['status'] != 'cancelled').toList();
    final labels = {for (final c in charges) c['id']: c['label']};
    final allocations = matching('allocations', {
      'accountId': scope['accountId'],
    });
    final byPayment = <String, List<Row>>{}, counts = <String, int>{};
    for (final a in allocations) {
      final id = a['causedByPaymentId'];
      if (id is String) (byPayment[id] ??= []).add(a);
      if (a['kind'] == 'settle') {
        counts.update(a['chargeId'], (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final result = <String, dynamic>{
      ...scope,
      'charges': [],
      'payments': [],
      'nextChargeCursor': null,
      'nextPaymentCursor': null,
    };
    for (final section in ['charges', 'payments']) {
      if (boundary != null && boundary[4] != section) continue;
      final isCharge = section == 'charges';
      final rows = isCharge
          ? charges
          : matching('payments', {...pupil, 'accountId': scope['accountId']});
      List key(Row row) {
        final date = row[isCharge ? 'dueDate' : 'paymentDate'];
        return [
          date == null ? null : _stamp(date),
          date == null && isCharge ? row['label'] : '',
          row['id'],
        ];
      }

      int compare(List a, List b) {
        if (a[0] == null && b[0] != null) return 1;
        if (a[0] != null && b[0] == null) return -1;
        final date = a[0] == null
            ? 0
            : DateTime.parse(a[0]).compareTo(DateTime.parse(b[0]));
        if (date != 0) return isCharge ? date : -date;
        final label = (a[1] as String).compareTo(b[1]);
        return label != 0 ? label : (a[2] as String).compareTo(b[2]);
      }

      final after = boundary?.sublist(5);
      rows.sort((a, b) => compare(key(a), key(b)));
      final candidates = rows
          .where((r) => after == null || compare(key(r), after) > 0)
          .take(limit + 1)
          .toList();
      final selected = candidates.take(limit);
      result[section] = [
        for (final r in selected)
          isCharge
              ? {
                  for (final k in [
                    'id',
                    'currency',
                    'expectedAmount',
                    'allocatedAmount',
                    'adjustmentAmount',
                    'waiverAmount',
                    'status',
                    'label',
                  ])
                    k: r[k],
                  'dueDate': key(r).first,
                  'settlementCount': counts[r['id']] ?? 0,
                }
              : _paymentPreview(r, labels, byPayment[r['id']] ?? []),
      ];
      if (candidates.length > limit) {
        result[isCharge ? 'nextChargeCursor' : 'nextPaymentCursor'] =
            jsonEncode([...prefix, section, ...key(selected.last)]);
      }
    }
    return result;
  }

  Row periodResultRead(Row input, {required bool subject}) {
    final period = one('academic-periods', input['periodId']);
    if (period['academicYearId'] != year) {
      throw ApiError(403, 'Select the period year');
    }
    final data = familyQuery('get-guardian-period-results', input) as Row;
    final fields = {...data, 'periodId': period['id'], 'academicYearId': year};
    if (!subject) return fields..remove('marks');
    Iterable<Row> leaves(List rows) sync* {
      for (final row in rows.whereType<Row>()) {
        if (row['sectionKind'] == 'subject') yield row;
        if (row['subResults'] is List) yield* leaves(row['subResults'] as List);
      }
    }

    final section = leaves(data['sections'] as List)
        .where(
          (row) =>
              row['subjectId'] == input['subjectId'] ||
              row['classSubjectId'] == input['subjectId'],
        )
        .firstOrNull;
    final marks =
        (data['marks'] as List)
            .whereType<Row>()
            .where(
              (row) =>
                  section != null &&
                  (row['subjectId'] == section['subjectId'] ||
                      row['classSubjectId'] == section['classSubjectId']),
            )
            .toList()
          ..sort((a, b) {
            final date = '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}');
            return date == 0 ? '${a['id']}'.compareTo('${b['id']}') : date;
          });
    final cursor = input['cursor'];
    final start = cursor == null
        ? 0
        : marks.indexWhere((row) => row['id'] == cursor) + 1;
    final limit = int.tryParse('${input['limit'] ?? 30}');
    if ((cursor != null && start == 0) ||
        limit == null ||
        limit < 1 ||
        limit > 100) {
      throw ApiError(400, 'Invalid marks page');
    }
    final page = marks.skip(start).take(limit).toList();
    return {
      'periodId': period['id'],
      'periodName': period['name'],
      'academicYearId': year,
      'state': data['state'],
      'section': section,
      'marks': page,
      'nextCursor': start + page.length < marks.length ? page.last['id'] : null,
      'focusedMark': marks
          .where(
            (row) => row['id'] == input['focusMarkId'] && !page.contains(row),
          )
          .firstOrNull,
    };
  }

  Row childChoices() {
    final children = rows('students').where((r) => linked(r['id'])).toList();
    return {
      'guardianId': actor,
      'school': one('schools', DemoSchool.school),
      'children': children,
      'years': rows('academic-years'),
      'enrollments': [
        for (final e in rows('enrollments'))
          if (linked(e['studentId']))
            {
              ...e,
              'enrollmentIndex': e['enrollmentIndex'] ?? 0,
              'classLabel': one('class-groups', e['classGroupId'])['name'],
            },
      ],
    };
  }

  Row homeHighlights(Row b) {
    final student = b['studentId'];
    List<Row> studentRows(String table) => matching(table, {
      'studentId': student,
    }).where((r) => visible(table, r)).toList();
    final clock = SchoolClock.now();
    final records = studentRows('attendance');
    final dayIds =
        (query('get-student-timetable', {
                  'studentId': student,
                  'startDate': b['day'],
                  'endDate': b['day'],
                })
                as Map)['events']
            as List;
    final ids = dayIds.map((e) => e['id']).toSet();
    final statuses = <String, String>{};
    for (final row in records) {
      final id =
          row['lessonSessionId'] ??
          row['activitySessionId'] ??
          row['assessmentId'];
      if (id is String && ids.contains(id)) {
        statuses[id] = row['status'] as String;
      }
    }
    var balance = 0, overdue = 0;
    DateTime? earliest;
    for (final charge in studentRows('student-charges')) {
      if (charge['status'] == 'cancelled' || charge['academicYearId'] != year) {
        continue;
      }
      final net =
          (charge['expectedAmount'] as int) -
          (charge['allocatedAmount'] as int? ?? 0) -
          (charge['adjustmentAmount'] as int? ?? 0) -
          (charge['waiverAmount'] as int? ?? 0);
      final due = DateTime.tryParse(charge['dueDate'] as String? ?? '');
      if (charge['status'] == 'overdue' ||
          (net > 0 && due != null && due.isBefore(clock))) {
        overdue++;
      }
      if (net <= 0) continue;
      balance += net;
      if (due != null && (earliest == null || due.isBefore(earliest))) {
        earliest = due;
      }
    }
    final photos = studentRows('student-photo-submissions')
      ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    final reports = studentRows(
      'results',
    ).where((r) => r['status'] == 'published').length;
    final selection =
        query('get-student-subject-enrollments', {'studentId': student}) as Map;
    final subjects =
        StudentSubjectParticipation(
              (selection['enrollments'] as List).cast<Row>(),
              (selection['offerings'] as List).cast<Row>(),
            )
            .currentSubjects(clock)
            .where((r) => r['classGroupId'] == b['classGroupId'])
            .toList();
    return {
      'attendance': statuses,
      'unavailable': <String>[],
      'cards': {
        'absent': records.where((r) => r['status'] == 'absent').length,
        'late': records.where((r) => r['status'] == 'late').length,
        'overdue': overdue,
        'balance': balance,
        'dueDate': earliest?.toUtc().toIso8601String(),
        'reports': reports,
        if (reports == 0) 'marks': studentRows('assessment-results').length,
        'photo': photos.firstOrNull?['status'],
        'documents': studentRows('document-issuances')
            .where(
              (r) =>
                  r['academicYearId'] == year &&
                  r['status'] == 'ready' &&
                  isLeftoverFamilyPaper(r['templateKey'] as String),
            )
            .length,
        'surveys':
            (familyQuery('list-guardian-family-feedback-campaigns', {}) as List)
                .where(
                  (r) => r['studentId'] == student && r['slotState'] == 'open',
                )
                .length,
        'unread': rows('message-deliveries')
            .where(
              (r) => visible('message-deliveries', r) && r['status'] != 'read',
            )
            .length,
        'progress': subjects.isEmpty
            ? null
            : (subjects.fold<int>(
                        0,
                        (sum, r) =>
                            sum + (r['completedPercentage'] as int? ?? 0),
                      ) /
                      subjects.length)
                  .round(),
      },
    };
  }

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
