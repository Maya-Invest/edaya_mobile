import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'demo_school.dart';
import 'demo_grading.dart';

enum DemoRole { guardian, teacher }

/// Device-local session. The installed apps have independent preference and database directories.
class DemoStore {
  DemoStore._(this.role, this.id, this._db);
  final DemoRole role;
  final String id;
  final Database _db;
  bool closed = false;
  static const activeKey = 'edaya.offline-demo.v1';
  String get prefix => 'edaya.demo.$id.';
  String get actor => 'demo-${role.name}';
  AuthUser get user => AuthUser(
    id: '$actor-account',
    email: '${role.name}@example.invalid',
    name: role == DemoRole.guardian ? 'Moussa Koné' : 'Aminata Traoré',
  );
  late final auth = DemoAuthClient(this);
  static const _ending = 'ending:';
  static Future<DemoStore?> resume(DemoRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(activeKey);
    if (id == null) return null;
    if (id.startsWith(_ending)) {
      await _clear(id.substring(_ending.length), prefs);
      return null;
    }
    return _open(role, id);
  }

  static Future<DemoStore> start(DemoRole role) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final store = await _open(role, id);
    try {
      if (!await (await SharedPreferences.getInstance()).setString(
        activeKey,
        id,
      )) {
        throw StateError('Could not persist demo session');
      }
      return store;
    } catch (_) {
      await store.close();
      await deleteDatabase(store._db.path);
      rethrow;
    }
  }

  static Future<DemoStore> _open(DemoRole role, String id) async {
    final path = p.join(await getDatabasesPath(), 'edaya-demo-$id.db');
    final db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          final row = (await db.query(
            'school',
            columns: ['body'],
            where: 'id = 1',
          )).single;
          final school = jsonDecode(row['body'] as String) as Map;
          void updateGrade(Map record) {
            final grading = record['grading'];
            if (grading is Map &&
                grading['reportedValue'] is num &&
                grading['maximum'] == 20) {
              grading['mention'] = demoGrade(
                grading['reportedValue'] as num,
              )['mention'];
            }
            for (final child
                in (record['sectionResults'] ??
                        record['subResults'] ??
                        const [])
                    as List) {
              updateGrade(child as Map);
            }
          }

          for (final report in school['results'] as List) {
            updateGrade(report as Map);
          }
          await db.update('school', {
            'body': jsonEncode(school),
          }, where: 'id = 1');
        }
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE school (id INTEGER PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE media (id TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
        );
        final seed = await rootBundle.loadString(
          'packages/edaya_shared/assets/demo/school-v1.json',
        );
        await db.insert('school', {'id': 1, 'body': seed});
      },
    );
    return DemoStore._(role, id, db);
  }

  Future<Object?> request(
    String method,
    String path,
    Map<String, dynamic> body,
    String? year,
  ) {
    if (closed) throw StateError('Demo has ended');
    return _db.transaction((txn) async {
      final row = (await txn.query('school', columns: ['body'])).single;
      final school = DemoSchool(
        jsonDecode(row['body'] as String),
        role.name,
        year,
      );
      final result = school.request(method, path, body);
      if (school.changed) {
        await txn.update('school', {
          'body': jsonEncode(school.data),
        }, where: 'id = 1');
      }
      return result;
    });
  }

  Future<Uint8List?> readMedia(String id) async {
    if (closed) return null;
    final rows = await _db.query('media', where: 'id = ?', whereArgs: [id]);
    return rows.firstOrNull?['bytes'] as Uint8List?;
  }

  Future<void> writeMedia(String id, Uint8List bytes) async {
    if (closed) throw StateError('Demo has ended');
    await _db.insert('media', {
      'id': id,
      'bytes': bytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    closed = true;
    await _db.close();
  }

  Future<void> erase() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(activeKey, '$_ending$id')) {
      throw StateError('Could not end demo session');
    }
    await close();
    await _clear(id, prefs);
  }

  static Future<void> _clear(String id, SharedPreferences prefs) async {
    await deleteDatabase(p.join(await getDatabasesPath(), 'edaya-demo-$id.db'));
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('edaya.demo.$id.'),
    )) {
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear demo preference');
      }
    }
    if (!await prefs.remove(activeKey)) {
      throw StateError('Could not clear demo session');
    }
  }
}

class DemoAuthClient extends AuthClient {
  DemoAuthClient(this.store)
    : super(baseUrl: 'https://demo.invalid', client: DemoMediaClient(store));
  final DemoStore store;
  @override
  http.Client get businessHttpClient => httpClient;
}

/// Handles only the demo's local media references, including direct HTTP-client callers.
class DemoMediaClient extends http.BaseClient {
  DemoMediaClient(this.store);
  final DemoStore store;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host != 'demo.invalid' ||
        request.url.pathSegments.length != 2 ||
        request.url.pathSegments.first != 'media') {
      throw StateError('External requests are unavailable in the offline demo');
    }
    final id = request.url.pathSegments.last;
    if (request.method == 'PUT') {
      await store.writeMedia(id, await request.finalize().toBytes());
      return http.StreamedResponse(const Stream.empty(), 200);
    }
    if (request.method != 'GET') {
      throw StateError('Unsupported demo media operation');
    }
    final bytes = await store.readMedia(id);
    return http.StreamedResponse(
      bytes == null ? const Stream.empty() : Stream.value(bytes),
      bytes == null ? 404 : 200,
    );
  }
}
