import 'package:edaya_api_client/edaya_api_client.dart';
part 'demo_teaching.dart';
part 'demo_family.dart';

typedef Row = Map<String, dynamic>;

/// Local implementation of the school operations used by the two release apps.
/// A request runs inside one SQLite transaction, including its retry receipt.
class DemoSchool {
  DemoSchool(this.data, this.role, String? selectedYear)
    : year = selectedYear ?? 'demo-2026';
  final Row data;
  final String role, year;
  bool changed = false;
  bool get teacher => role == 'teacher';
  String get actor => 'demo-$role';
  static const school = 'demo-school';
  static const time = '2026-11-10T10:15:00.000Z';
  List<Row> rows(String table) => (data[table] as List? ?? []).cast<Row>();
  Row one(String table, dynamic id) =>
      rows(table).where((r) => r['id'] == id).firstOrNull ??
      (throw ApiError(404, 'Missing $table record'));
  List<Row> matching(String table, Row fields) => rows(
    table,
  ).where((r) => fields.entries.every((e) => r[e.key] == e.value)).toList();
  Row put(String table, Row values) {
    final entries = data.putIfAbsent(table, () => <dynamic>[]) as List;
    final previous =
        entries.where((r) => r['id'] == values['id']).firstOrNull as Row?;
    changed = true;
    if (previous == null) {
      entries.add(values);
      return values;
    }
    previous.addAll(values);
    return previous;
  }

  String newId(String table) => 'demo-$table-${rows(table).length + 1}';
  List<Row> roster(dynamic group) {
    final ids = matching('enrollments', {
      'academicYearId': year,
      'classGroupId': group,
    }).map((e) => e['studentId']).toSet();
    return rows('students').where((r) => ids.contains(r['id'])).toList();
  }

  List<String> conversationAssignments(Row body) {
    if (body['destination'] == 'school') return [];
    final group =
        body['classGroupId'] ??
        matching('enrollments', {
          'studentId': body['studentId'],
          'academicYearId': year,
        }).firstOrNull?['classGroupId'];
    return [
      for (final assignment in matching('teacher-assignments', {
        'classGroupId': group,
        'teacherId': 'demo-teacher',
        'academicYearId': year,
      }))
        assignment['id'] as String,
    ];
  }

  bool linked(dynamic id) => matching('guardian-links', {
    'guardianId': 'demo-guardian',
    'studentId': id,
  }).isNotEmpty;
  bool visible(String table, Row row) {
    if (row['academicYearId'] != null && row['academicYearId'] != year) {
      return false;
    }
    if (table == 'message-deliveries') return row['recipientId'] == actor;
    if (!teacher) {
      if (table == 'students') return linked(row['id']);
      if (table == 'assessment-results' &&
          one('assessments', row['assessmentId'])['marksStatus'] !=
              'submitted') {
        return false;
      }
      if (row['studentId'] != null && !linked(row['studentId'])) return false;
      if (table == 'results' && row['status'] != 'published') return false;
    }
    return true;
  }

  Object? request(String method, String path, Row body) {
    final parts = Uri.parse(path).pathSegments;
    if (parts.length < 3 || parts.first != 'core') throw ApiError(404, path);
    if (!teacher && body['studentId'] is String && !linked(body['studentId'])) {
      throw ApiError(403, 'Unlinked pupil');
    }
    switch (parts[1]) {
      case 'authorization':
        final profile = {
          'kind': role,
          'actorId': actor,
          'schoolId': school,
          'schoolName': one('schools', school)['name'],
          'schoolShortName': 'Collège Lumière',
        };
        if (parts.last == 'profiles') {
          return {
            'profiles': [profile],
          };
        }
        if (parts.last == 'effective-grants') {
          return {
            ...profile,
            'assuranceLevel': 'standard',
            'grants': [
              {
                'permission': teacher ? 'teaching.read' : 'guardian.read',
                'source': teacher ? 'assignment' : 'relationship',
                'scopes': teacher
                    ? [
                        for (final c in matching('class-groups', {
                          'academicYearId': year,
                        }))
                          {'kind': 'class_group', 'classGroupId': c['id']},
                      ]
                    : [
                        for (final link in rows('guardian-links'))
                          {'kind': 'student', 'studentId': link['studentId']},
                      ],
              },
            ],
          };
        }
      case 'entities':
        final table = parts[2], action = parts.last;
        if (method == 'GET') {
          final row = one(table, action);
          if (!visible(table, row)) throw ApiError(404, path);
          return row;
        }
        final list = rows(
          table,
        ).where((r) => visible(table, r) && matches(r, body)).toList();
        if (teacher &&
            action == 'save' &&
            ['class-subject-progress', 'lesson-sessions'].contains(table)) {
          return put(table, body);
        }
        if (action == 'count') return {'count': list.length};
        if (action == 'one') {
          return list.firstOrNull ?? (throw ApiError(404, path));
        }
        if (action == 'list') {
          return list
              .skip(body[r'$offset'] as int? ?? 0)
              .take(body[r'$limit'] as int? ?? 500)
              .toList();
        }
      case 'files':
        if (parts.last == 'download-url') {
          return {'downloadUrl': 'https://demo.invalid/media/${parts[2]}'};
        }
      case 'queries':
        return query(parts.last, body);
      case 'commands':
        final key = body['requestId'] == null
            ? null
            : '${parts.last}:${body['requestId']}';
        final receipts =
            data.putIfAbsent('_receipts', () => <String, dynamic>{}) as Row;
        if (key != null && receipts.containsKey(key)) return receipts[key];
        final result = command(parts.last, body);
        if (key != null) {
          receipts[key] = result;
          changed = true;
        }
        return result;
    }
    throw ApiError(404, path);
  }

  Object? query(String name, Row b) {
    switch (name) {
      case 'get-teacher-timetable':
      case 'get-class-group-timetable':
      case 'get-student-timetable':
        final group =
            b['classGroupId'] ??
            (b['studentId'] == null
                ? null
                : matching('enrollments', {
                    'studentId': b['studentId'],
                    'academicYearId': year,
                  }).firstOrNull?['classGroupId']);
        return {
          'events': rows('lesson-sessions').where((e) {
            final date = (e['startsAt'] as String).substring(0, 10);
            return (group == null || e['classGroupId'] == group) &&
                e['academicYearId'] == year &&
                date.compareTo(b['startDate'] ?? '') >= 0 &&
                date.compareTo(b['endDate'] ?? '9999') <= 0;
          }).toList(),
        };
      case 'get-student-subject-enrollments':
        final links = matching('subject-enrollments', {
          'studentId': b['studentId'],
          'academicYearId': year,
        });
        return {
          'enrollments': links,
          'offerings': [
            for (final l in links) one('class-subjects', l['classSubjectId']),
          ],
        };
      case 'get-class-subject-roster':
        final people = roster(
          one('class-subjects', b['classSubjectId'])['classGroupId'],
        );
        return {
          'students': people,
          'studentIds': [for (final s in people) s['id']],
        };
      case 'list-conversation-recipients':
        return {
          'schoolAvailable': true,
          'schoolName': one('schools', school)['name'],
          'teachers': [
            {
              'id': 'demo-teacher',
              'name': 'Aminata Traoré',
              'subjects': ['Mathématiques'],
            },
          ],
        };
      case 'list-teacher-guardian-recipients':
        return {
          'guardians': linked(b['studentId'])
              ? [
                  {'id': 'demo-guardian', 'name': 'Moussa Koné'},
                ]
              : <Row>[],
        };
      case 'list-conversations':
        final list = rows('conversations').reversed.toList();
        return {
          'items': list.skip(b['offset'] ?? 0).take(b['limit'] ?? 25).toList(),
          'total': list.length,
          'unreadCount': list.where((r) => r['unread'] == true).length,
        };
      case 'get-conversation':
        final messages =
            matching('messages', {'conversationId': b['conversationId']})
                .where(
                  (m) =>
                      b['beforeSequence'] == null ||
                      m['sequence'] < b['beforeSequence'],
                )
                .toList();
        final skip = (messages.length - (b['limit'] as int? ?? 50)).clamp(
          0,
          messages.length,
        );
        return {
          'conversation': one('conversations', b['conversationId']),
          'messages': messages.skip(skip).toList(),
          'hasMore': skip > 0,
        };
      case 'list-document-issuances':
        return {
          'items': rows('document-issuances')
              .where((r) => visible('document-issuances', r) && matches(r, b))
              .toList(),
        };
      case 'get-document-issuance':
        final doc = one('document-issuances', b['id']);
        if (!visible('document-issuances', doc)) throw ApiError(404, name);
        return doc;
      case 'grant-document-download':
        final doc = one('document-issuances', b['id']);
        return {
          'downloadUrl': Uri(
            scheme: 'edaya-demo',
            host: 'document',
            pathSegments: [doc['id']],
          ).toString(),
        };
    }
    return teacher ? teachingQuery(name, b) : familyQuery(name, b);
  }

  Object? command(String name, Row b) {
    if ((!teacher &&
            {
              'start-teacher-conversation',
              'update-teacher-self-profile',
              'create-teacher-signature-upload',
              'complete-teacher-signature-upload',
              'clear-teacher-signature',
            }.contains(name)) ||
        (teacher && name == 'update-guardian-profile')) {
      throw ApiError(403, 'Wrong profile');
    }
    switch (name) {
      case 'start-teacher-conversation':
      case 'start-conversation':
      case 'reply-conversation':
        final thread = name == 'reply-conversation'
            ? one('conversations', b['conversationId'])
            : put('conversations', {
                'id': newId('conversations'),
                'schoolName': one('schools', school)['name'],
                'teacherName': 'Aminata Traoré',
                'guardianName': 'Moussa Koné',
                'guardianId': 'demo-guardian',
                'teacherId': 'demo-teacher',
                'studentName': b['studentId'] == null
                    ? null
                    : studentName(b['studentId']),
                'status': b['destination'] == 'school' ? 'open' : null,
                'destination': b['destination'] ?? 'teacher',
                'allowedActions': {'reply': true},
                'version': 0,
                ...b,
                'assignmentIds': conversationAssignments(b),
              });
        if (b['expectedVersion'] != null &&
            b['expectedVersion'] != thread['version']) {
          throw ApiError(409, 'CONVERSATION_CHANGED');
        }
        final sequence = (thread['version'] as int) + 1;
        final text = b['body'] as String;
        put('messages', {
          'id': newId('messages'),
          'conversationId': thread['id'],
          'authorKind': role,
          'authorId': actor,
          'authorName': teacher ? 'Aminata Traoré' : 'Moussa Koné',
          'body': text,
          'createdAt': time,
          'sequence': sequence,
        });
        return put('conversations', {
          'id': thread['id'],
          'version': sequence,
          'updatedAt': time,
          'lastMessage': text,
          'unread': false,
        });
      case 'mark-conversation-read':
        final thread = one('conversations', b['conversationId']);
        return thread['unread'] == true
            ? put('conversations', {'id': thread['id'], 'unread': false})
            : thread;
      case 'mark-delivery-read':
        return put('message-deliveries', {
          'id': b['deliveryId'] ?? b['id'],
          'status': 'read',
          'readAt': time,
        });
      case 'update-guardian-profile':
      case 'update-teacher-self-profile':
        return put(teacher ? 'teachers' : 'guardians', {...b, 'id': actor});
      case 'create-profile-photo-upload':
      case 'create-teacher-signature-upload':
        final id = b['attachmentId'] ?? newId('attachments');
        put('attachments', {'id': id, 'ownerId': b['ownerId'] ?? actor});
        return {
          'attachmentId': id,
          'storageKey': id,
          'uploadUrl': 'https://demo.invalid/media/$id',
          'headers': <String, String>{},
          'expiresAt': '2099-12-31T00:00:00Z',
        };
      case 'complete-profile-photo-upload':
        if (b['ownerKind'] == 'teacher') {
          put('teachers', {
            'id': actor,
            'photoUrl': '/core/files/${b['id']}/content',
          });
        }
        return put('attachments', b);
      case 'complete-teacher-signature-upload':
        return put('teachers', {
          'id': actor,
          'signatureAttachmentId': b['attachmentId'],
        });
      case 'clear-teacher-signature':
        if (one('teachers', actor)['signatureAttachmentId'] !=
            b['attachmentId']) {
          throw ApiError(409, 'SIGNATURE_CHANGED');
        }
        return put('teachers', {'id': actor, 'signatureAttachmentId': null});
      case 'request-document-issuance':
        final existing = rows('document-issuances')
            .where(
              (r) =>
                  visible('document-issuances', r) &&
                  r['sourceId'] == b['sourceId'] &&
                  r['templateKey'] == b['templateKey'],
            )
            .firstOrNull;
        return existing ??
            put('document-issuances', {
              ...b,
              'id': newId('document-issuances'),
              'status': 'pending',
              'createdAt': time,
            });
    }
    return teacher ? teachingCommand(name, b) : familyCommand(name, b);
  }

  String studentName(dynamic id) {
    final row = one('students', id);
    return '${row['firstName']} ${row['lastName']}';
  }

  static bool matches(Row row, Row filter) {
    for (final entry in filter.entries) {
      if (entry.key == r'$or') {
        if (!(entry.value as List).any((q) => matches(row, q as Row))) {
          return false;
        }
        continue;
      }
      if (entry.key.startsWith(r'$')) continue;
      final value = row[entry.key], expected = entry.value;
      if (expected is! Map) {
        if (value != expected) return false;
        continue;
      }
      for (final condition in expected.entries) {
        final rhs = condition.value;
        final compare = '$value'.compareTo('$rhs');
        final accepted = switch (condition.key) {
          r'$in' => (rhs as List).contains(value),
          r'$ne' => value != rhs,
          r'$gte' => compare >= 0,
          r'$lte' => compare <= 0,
          r'$gt' => compare > 0,
          r'$lt' => compare < 0,
          _ => false,
        };
        if (!accepted) return false;
      }
    }
    return true;
  }
}
