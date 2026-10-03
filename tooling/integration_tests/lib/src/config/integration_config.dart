import 'dart:io';

/// Environment-backed settings for live API integration tests.
class IntegrationConfig {
  const IntegrationConfig({
    required this.baseUrl,
    required this.email,
    required this.academicYearId,
    required this.classGroupId,
    required this.calendarReferenceDate,
  });

  /// Narrative "today" for demo-ci calendar/timetable probes — matches backend
  /// `SEED_REFERENCE_DATE` so integration tests stay stable across real dates.
  static const defaultCalendarReferenceDate = '2026-09-17';

  factory IntegrationConfig.fromEnvironment() {
    return IntegrationConfig(
      baseUrl: _readEnv(
        'EDAYA_API_URL',
        fallbackKeys: ['BASE_URL'],
        defaultValue: 'http://localhost:9999',
      ).replaceAll(RegExp(r'/+$'), ''),
      email: _readEnv(
        'EDAYA_TEACHER_EMAIL',
        fallbackKeys: ['TEACHER_EMAIL'],
        defaultValue: 'a.toure@ecole-ci.edaya.dev',
      ),
      academicYearId: _readEnv(
        'EDAYA_ACADEMIC_YEAR_ID',
        fallbackKeys: ['ACADEMIC_YEAR_ID'],
        defaultValue: '2025-ci',
      ),
      classGroupId: _readEnv(
        'EDAYA_CLASS_GROUP_ID',
        fallbackKeys: ['CLASS_GROUP_ID'],
        defaultValue: 'ci-6a',
      ),
      calendarReferenceDate: _readEnv(
        'EDAYA_CALENDAR_REFERENCE_DATE',
        defaultValue: defaultCalendarReferenceDate,
      ),
    );
  }

  String get authUrl => baseUrl;
  final String baseUrl;
  final String email;
  final String academicYearId;
  final String classGroupId;
  final String calendarReferenceDate;

  DateTime get calendarReferenceDay {
    final parsed = DateTime.tryParse(calendarReferenceDate);
    if (parsed == null) {
      throw FormatException(
        'Invalid EDAYA_CALENDAR_REFERENCE_DATE: $calendarReferenceDate',
      );
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  IntegrationConfig withTeacherEmail(String email) {
    return IntegrationConfig(
      baseUrl: baseUrl,
      email: email,
      academicYearId: academicYearId,
      classGroupId: classGroupId,
      calendarReferenceDate: calendarReferenceDate,
    );
  }

  IntegrationConfig withGuardianEmail(String email) {
    return withTeacherEmail(email);
  }

  /// Default guardian demo account (`ci-g1` parent of `ci-s1` in 6ème A).
  static const defaultGuardianEmail = 'm.kone@mail.ci';

  /// School owner used to publish private inbox fixtures through normal policies.
  static const defaultSchoolOwnerEmail = 'a.kone@ecole-ci.edaya.dev';

  IntegrationConfig withSchoolOwnerEmail([String? email]) {
    return IntegrationConfig(
      baseUrl: baseUrl,
      email: email ?? defaultSchoolOwnerEmail,
      academicYearId: academicYearId,
      classGroupId: classGroupId,
      calendarReferenceDate: calendarReferenceDate,
    );
  }

  static bool get isEnabled {
    final flag =
        Platform.environment['EDAYA_INTEGRATION_TESTS'] ??
        Platform.environment['RUN_INTEGRATION_TESTS'];
    return flag == '1' || flag == 'true';
  }

  static String _readEnv(
    String key, {
    List<String> fallbackKeys = const [],
    String defaultValue = '',
  }) {
    final direct = Platform.environment[key];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    for (final fallbackKey in fallbackKeys) {
      final fallback = Platform.environment[fallbackKey];
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }

    return defaultValue;
  }
}
