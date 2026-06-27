import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../app/router.dart';
import '../../config/api_config.dart';
import 'app_session_controller.dart';

class LoginController extends LevitController with LevitReactiveTasksMixin {
  LoginController({
    required AuthClient authClient,
    required AppSessionController session,
    required AppRouter appRouter,
  }) : _authClient = authClient,
       _session = session,
       _appRouter = appRouter;

  final AuthClient _authClient;
  final AppSessionController _session;
  final AppRouter _appRouter;
  final email = LxVar(ApiConfig.devGuardianEmail);
  final password = LxVar(ApiConfig.devPassword);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(email);
    autoDispose(password);
    autoDispose(errorMessage);
  }

  Future<void> signInWithPassword() async {
    errorMessage('');
    await runTask(() async {
      final result = await _authClient.signInWithEmail(
        email: email.value.trim(),
        password: password.value,
      );

      if (!result.isSuccess || result.data == null) {
        errorMessage(result.error?.message ?? 'Sign-in failed');
        return;
      }

      final sessionError = await _session.completeSignIn(result.data!);
      if (sessionError != null) {
        errorMessage(sessionError);
        return;
      }

      await AppRuntime.academicYear.loadYears();
      await AppRuntime.studentContext.initializeFromSession();
      _appRouter.router.go('/calendar');
    }, id: 'sign-in');
  }
}
