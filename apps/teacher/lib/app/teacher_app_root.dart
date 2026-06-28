import 'package:edaya_shared/edaya_shared.dart';

import '../di/teacher_module.dart';

class TeacherAppRoot extends EdayaAppRoot {
  const TeacherAppRoot({super.key})
    : super(
        scopeName: 'teacher-app',
        appTitle: 'Edaya Teacher',
        registerDependencies: registerTeacherDependencies,
      );
}
