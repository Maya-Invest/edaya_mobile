import 'package:levit_flutter/levit_flutter.dart';

import '../../mock/mock_store.dart';

/// App-lifetime student / school / year selection over [MockStore].
class StudentContextController extends LevitController {
  StudentContextController({required MockStore store}) : _store = store;

  final MockStore _store;

  final storeTick = LxVar(0);

  MockStore get store => _store;

  MockStudent get activeStudent => _store.activeStudent;
  MockSchool get activeSchool => _store.activeSchool;
  String get selectedYear => _store.selectedYear;
  String get activeStudentId => _store.activeStudentId;
  String get guardianFullName => _store.guardianFullName;
  String get guardianInitials => _store.guardianInitials;
  bool get isAuthenticated => _store.isAuthenticated;
  List<SchoolStudentGroup> get studentsBySchool => _store.studentsBySchool;

  @override
  void onInit() {
    super.onInit();
    autoDispose(storeTick);
    _store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() => storeTick.value++;

  @override
  void onClose() {
    _store.removeListener(_onStoreChanged);
    super.onClose();
  }

  void selectStudent(String studentId) => _store.selectStudent(studentId);

  void selectYear(String year) => _store.selectYear(year);

  void selectYearForSchool(String schoolId, String year) =>
      _store.selectYearForSchool(schoolId, year);

  List<String> schoolYearsFor(String schoolId) =>
      _store.schoolYearsFor(schoolId);

  void signIn() => _store.signIn();

  void signOut() => _store.signOut();
}
