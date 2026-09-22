// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_outbox_database.dart';

// ignore_for_file: type=lint
class $TeacherOutboxRowsTable extends TeacherOutboxRows
    with TableInfo<$TeacherOutboxRowsTable, TeacherOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeacherOutboxRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorKindMeta = const VerificationMeta(
    'actorKind',
  );
  @override
  late final GeneratedColumn<String> actorKind = GeneratedColumn<String>(
    'actor_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _academicYearIdMeta = const VerificationMeta(
    'academicYearId',
  );
  @override
  late final GeneratedColumn<String> academicYearId = GeneratedColumn<String>(
    'academic_year_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    idempotencyKey,
    payloadJson,
    state,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    origin,
    subjectId,
    actorKind,
    actorId,
    schoolId,
    academicYearId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teacher_outbox_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TeacherOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('actor_kind')) {
      context.handle(
        _actorKindMeta,
        actorKind.isAcceptableOrUnknown(data['actor_kind']!, _actorKindMeta),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    }
    if (data.containsKey('academic_year_id')) {
      context.handle(
        _academicYearIdMeta,
        academicYearId.isAcceptableOrUnknown(
          data['academic_year_id']!,
          _academicYearIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TeacherOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeacherOutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      actorKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_kind'],
      ),
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      ),
      academicYearId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year_id'],
      ),
    );
  }

  @override
  $TeacherOutboxRowsTable createAlias(String alias) {
    return $TeacherOutboxRowsTable(attachedDatabase, alias);
  }
}

class TeacherOutboxRow extends DataClass
    implements Insertable<TeacherOutboxRow> {
  final String id;
  final String kind;
  final String idempotencyKey;
  final String payloadJson;
  final String state;
  final int attemptCount;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  final String? origin;
  final String? subjectId;
  final String? actorKind;
  final String? actorId;
  final String? schoolId;
  final String? academicYearId;
  const TeacherOutboxRow({
    required this.id,
    required this.kind,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.state,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.origin,
    this.subjectId,
    this.actorKind,
    this.actorId,
    this.schoolId,
    this.academicYearId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    if (!nullToAbsent || actorKind != null) {
      map['actor_kind'] = Variable<String>(actorKind);
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    if (!nullToAbsent || schoolId != null) {
      map['school_id'] = Variable<String>(schoolId);
    }
    if (!nullToAbsent || academicYearId != null) {
      map['academic_year_id'] = Variable<String>(academicYearId);
    }
    return map;
  }

  TeacherOutboxRowsCompanion toCompanion(bool nullToAbsent) {
    return TeacherOutboxRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      idempotencyKey: Value(idempotencyKey),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      actorKind: actorKind == null && nullToAbsent
          ? const Value.absent()
          : Value(actorKind),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      schoolId: schoolId == null && nullToAbsent
          ? const Value.absent()
          : Value(schoolId),
      academicYearId: academicYearId == null && nullToAbsent
          ? const Value.absent()
          : Value(academicYearId),
    );
  }

  factory TeacherOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeacherOutboxRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      origin: serializer.fromJson<String?>(json['origin']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      actorKind: serializer.fromJson<String?>(json['actorKind']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      schoolId: serializer.fromJson<String?>(json['schoolId']),
      academicYearId: serializer.fromJson<String?>(json['academicYearId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'origin': serializer.toJson<String?>(origin),
      'subjectId': serializer.toJson<String?>(subjectId),
      'actorKind': serializer.toJson<String?>(actorKind),
      'actorId': serializer.toJson<String?>(actorId),
      'schoolId': serializer.toJson<String?>(schoolId),
      'academicYearId': serializer.toJson<String?>(academicYearId),
    };
  }

  TeacherOutboxRow copyWith({
    String? id,
    String? kind,
    String? idempotencyKey,
    String? payloadJson,
    String? state,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> origin = const Value.absent(),
    Value<String?> subjectId = const Value.absent(),
    Value<String?> actorKind = const Value.absent(),
    Value<String?> actorId = const Value.absent(),
    Value<String?> schoolId = const Value.absent(),
    Value<String?> academicYearId = const Value.absent(),
  }) => TeacherOutboxRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    origin: origin.present ? origin.value : this.origin,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    actorKind: actorKind.present ? actorKind.value : this.actorKind,
    actorId: actorId.present ? actorId.value : this.actorId,
    schoolId: schoolId.present ? schoolId.value : this.schoolId,
    academicYearId: academicYearId.present
        ? academicYearId.value
        : this.academicYearId,
  );
  TeacherOutboxRow copyWithCompanion(TeacherOutboxRowsCompanion data) {
    return TeacherOutboxRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      origin: data.origin.present ? data.origin.value : this.origin,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      actorKind: data.actorKind.present ? data.actorKind.value : this.actorKind,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      academicYearId: data.academicYearId.present
          ? data.academicYearId.value
          : this.academicYearId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeacherOutboxRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('origin: $origin, ')
          ..write('subjectId: $subjectId, ')
          ..write('actorKind: $actorKind, ')
          ..write('actorId: $actorId, ')
          ..write('schoolId: $schoolId, ')
          ..write('academicYearId: $academicYearId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    idempotencyKey,
    payloadJson,
    state,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    origin,
    subjectId,
    actorKind,
    actorId,
    schoolId,
    academicYearId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeacherOutboxRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.idempotencyKey == this.idempotencyKey &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.origin == this.origin &&
          other.subjectId == this.subjectId &&
          other.actorKind == this.actorKind &&
          other.actorId == this.actorId &&
          other.schoolId == this.schoolId &&
          other.academicYearId == this.academicYearId);
}

class TeacherOutboxRowsCompanion extends UpdateCompanion<TeacherOutboxRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> idempotencyKey;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> origin;
  final Value<String?> subjectId;
  final Value<String?> actorKind;
  final Value<String?> actorId;
  final Value<String?> schoolId;
  final Value<String?> academicYearId;
  final Value<int> rowid;
  const TeacherOutboxRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.origin = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.actorKind = const Value.absent(),
    this.actorId = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TeacherOutboxRowsCompanion.insert({
    required String id,
    required String kind,
    required String idempotencyKey,
    required String payloadJson,
    required String state,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.origin = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.actorKind = const Value.absent(),
    this.actorId = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       idempotencyKey = Value(idempotencyKey),
       payloadJson = Value(payloadJson),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TeacherOutboxRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? idempotencyKey,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? origin,
    Expression<String>? subjectId,
    Expression<String>? actorKind,
    Expression<String>? actorId,
    Expression<String>? schoolId,
    Expression<String>? academicYearId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (origin != null) 'origin': origin,
      if (subjectId != null) 'subject_id': subjectId,
      if (actorKind != null) 'actor_kind': actorKind,
      if (actorId != null) 'actor_id': actorId,
      if (schoolId != null) 'school_id': schoolId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TeacherOutboxRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? idempotencyKey,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? origin,
    Value<String?>? subjectId,
    Value<String?>? actorKind,
    Value<String?>? actorId,
    Value<String?>? schoolId,
    Value<String?>? academicYearId,
    Value<int>? rowid,
  }) {
    return TeacherOutboxRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      origin: origin ?? this.origin,
      subjectId: subjectId ?? this.subjectId,
      actorKind: actorKind ?? this.actorKind,
      actorId: actorId ?? this.actorId,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (actorKind.present) {
      map['actor_kind'] = Variable<String>(actorKind.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (academicYearId.present) {
      map['academic_year_id'] = Variable<String>(academicYearId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeacherOutboxRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('origin: $origin, ')
          ..write('subjectId: $subjectId, ')
          ..write('actorKind: $actorKind, ')
          ..write('actorId: $actorId, ')
          ..write('schoolId: $schoolId, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TeacherOutboxDatabase extends GeneratedDatabase {
  _$TeacherOutboxDatabase(QueryExecutor e) : super(e);
  $TeacherOutboxDatabaseManager get managers =>
      $TeacherOutboxDatabaseManager(this);
  late final $TeacherOutboxRowsTable teacherOutboxRows =
      $TeacherOutboxRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [teacherOutboxRows];
}

typedef $$TeacherOutboxRowsTableCreateCompanionBuilder =
    TeacherOutboxRowsCompanion Function({
      required String id,
      required String kind,
      required String idempotencyKey,
      required String payloadJson,
      required String state,
      Value<int> attemptCount,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
      Value<String?> origin,
      Value<String?> subjectId,
      Value<String?> actorKind,
      Value<String?> actorId,
      Value<String?> schoolId,
      Value<String?> academicYearId,
      Value<int> rowid,
    });
typedef $$TeacherOutboxRowsTableUpdateCompanionBuilder =
    TeacherOutboxRowsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> idempotencyKey,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> origin,
      Value<String?> subjectId,
      Value<String?> actorKind,
      Value<String?> actorId,
      Value<String?> schoolId,
      Value<String?> academicYearId,
      Value<int> rowid,
    });

class $$TeacherOutboxRowsTableFilterComposer
    extends Composer<_$TeacherOutboxDatabase, $TeacherOutboxRowsTable> {
  $$TeacherOutboxRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorKind => $composableBuilder(
    column: $table.actorKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TeacherOutboxRowsTableOrderingComposer
    extends Composer<_$TeacherOutboxDatabase, $TeacherOutboxRowsTable> {
  $$TeacherOutboxRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorKind => $composableBuilder(
    column: $table.actorKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TeacherOutboxRowsTableAnnotationComposer
    extends Composer<_$TeacherOutboxDatabase, $TeacherOutboxRowsTable> {
  $$TeacherOutboxRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get actorKind =>
      $composableBuilder(column: $table.actorKind, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => column,
  );
}

class $$TeacherOutboxRowsTableTableManager
    extends
        RootTableManager<
          _$TeacherOutboxDatabase,
          $TeacherOutboxRowsTable,
          TeacherOutboxRow,
          $$TeacherOutboxRowsTableFilterComposer,
          $$TeacherOutboxRowsTableOrderingComposer,
          $$TeacherOutboxRowsTableAnnotationComposer,
          $$TeacherOutboxRowsTableCreateCompanionBuilder,
          $$TeacherOutboxRowsTableUpdateCompanionBuilder,
          (
            TeacherOutboxRow,
            BaseReferences<
              _$TeacherOutboxDatabase,
              $TeacherOutboxRowsTable,
              TeacherOutboxRow
            >,
          ),
          TeacherOutboxRow,
          PrefetchHooks Function()
        > {
  $$TeacherOutboxRowsTableTableManager(
    _$TeacherOutboxDatabase db,
    $TeacherOutboxRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeacherOutboxRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeacherOutboxRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeacherOutboxRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> actorKind = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<String?> schoolId = const Value.absent(),
                Value<String?> academicYearId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TeacherOutboxRowsCompanion(
                id: id,
                kind: kind,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                origin: origin,
                subjectId: subjectId,
                actorKind: actorKind,
                actorId: actorId,
                schoolId: schoolId,
                academicYearId: academicYearId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String idempotencyKey,
                required String payloadJson,
                required String state,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<String?> origin = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> actorKind = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<String?> schoolId = const Value.absent(),
                Value<String?> academicYearId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TeacherOutboxRowsCompanion.insert(
                id: id,
                kind: kind,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                origin: origin,
                subjectId: subjectId,
                actorKind: actorKind,
                actorId: actorId,
                schoolId: schoolId,
                academicYearId: academicYearId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TeacherOutboxRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$TeacherOutboxDatabase,
      $TeacherOutboxRowsTable,
      TeacherOutboxRow,
      $$TeacherOutboxRowsTableFilterComposer,
      $$TeacherOutboxRowsTableOrderingComposer,
      $$TeacherOutboxRowsTableAnnotationComposer,
      $$TeacherOutboxRowsTableCreateCompanionBuilder,
      $$TeacherOutboxRowsTableUpdateCompanionBuilder,
      (
        TeacherOutboxRow,
        BaseReferences<
          _$TeacherOutboxDatabase,
          $TeacherOutboxRowsTable,
          TeacherOutboxRow
        >,
      ),
      TeacherOutboxRow,
      PrefetchHooks Function()
    >;

class $TeacherOutboxDatabaseManager {
  final _$TeacherOutboxDatabase _db;
  $TeacherOutboxDatabaseManager(this._db);
  $$TeacherOutboxRowsTableTableManager get teacherOutboxRows =>
      $$TeacherOutboxRowsTableTableManager(_db, _db.teacherOutboxRows);
}
