abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:9999',
  );

  static const devStaffEmail = String.fromEnvironment(
    'DEV_STAFF_EMAIL',
    defaultValue: 'm.dupont@school.edu',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
