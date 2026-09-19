import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'teacher_outbox_database.g.dart';

class TeacherOutboxRows extends Table {
  TextColumn get id => text()();

  TextColumn get kind => text()();

  TextColumn get idempotencyKey => text().unique()();

  TextColumn get payloadJson => text()();

  TextColumn get state => text()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [TeacherOutboxRows])
class TeacherOutboxDatabase extends _$TeacherOutboxDatabase {
  TeacherOutboxDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  TeacherOutboxDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'teacher_outbox',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
