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

  TextColumn get origin => text().nullable()();

  TextColumn get subjectId => text().nullable()();

  TextColumn get actorKind => text().nullable()();

  TextColumn get actorId => text().nullable()();

  TextColumn get schoolId => text().nullable()();

  TextColumn get academicYearId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [TeacherOutboxRows])
class TeacherOutboxDatabase extends _$TeacherOutboxDatabase {
  TeacherOutboxDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  TeacherOutboxDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(teacherOutboxRows, teacherOutboxRows.origin);
          await migrator.addColumn(
            teacherOutboxRows,
            teacherOutboxRows.subjectId,
          );
          await migrator.addColumn(
            teacherOutboxRows,
            teacherOutboxRows.actorKind,
          );
          await migrator.addColumn(teacherOutboxRows, teacherOutboxRows.actorId);
          await migrator.addColumn(
            teacherOutboxRows,
            teacherOutboxRows.schoolId,
          );
          await migrator.addColumn(
            teacherOutboxRows,
            teacherOutboxRows.academicYearId,
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'teacher_outbox',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
