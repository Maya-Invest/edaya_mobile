import 'package:edaya_shared/edaya_shared.dart';

import '../di/teacher_module.dart';

class TeacherAppRoot extends EdayaAppRoot {
  TeacherAppRoot({super.key})
    : super(
        scopeName: 'teacher-app',
        appTitle: systemL10n().appTitleTeacher,
        registerDependencies: registerTeacherDependencies,
      );
}
