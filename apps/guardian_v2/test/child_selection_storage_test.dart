import 'package:edaya_guardian_v2/features/auth/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'child preferences keep the account and school captured before async storage access',
    () async {
      SharedPreferences.setMockInitialValues({});
      var identity = 'first/school-a';
      final storage = SessionStorage(contextKey: () => identity);
      final write = storage.writeActiveStudentId('first-child');
      identity = 'second/school-b';
      await write;
      expect(await storage.readActiveStudentId(), isNull);
      identity = 'first/school-a';
      final read = storage.readActiveStudentId();
      identity = 'second/school-b';
      expect(await read, 'first-child');
      expect(await storage.readActiveStudentId(), isNull);
    },
  );
}
