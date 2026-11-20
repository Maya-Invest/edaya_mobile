import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';

/// guardian login. Real auth via shared [LoginController];
/// mock harnesses sign in through [MockStore].
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.defaultEmail, required this.onSignInSuccess, this.mockStore});

  final String defaultEmail;
  final Future<void> Function() onSignInSuccess;
  final MockStore? mockStore;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveLoginPage(defaultEmail: defaultEmail, onSignInSuccess: onSignInSuccess);
    }
    return _MockLoginPage(defaultEmail: defaultEmail);
  }
}

class _LiveLoginPage extends LScopedView<LoginController> {
  const _LiveLoginPage({required this.defaultEmail, required this.onSignInSuccess});

  final String defaultEmail;
  final Future<void> Function() onSignInSuccess;

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        invitationToken: () => scope.find<PendingInvitationStore>().token,
        defaultEmail: defaultEmail,
        onSignInSuccess: onSignInSuccess,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LoginController controller) {
    return _LoginChrome(child: PasswordlessLoginForm(controller: controller));
  }
}

class _MockLoginPage extends StatelessWidget {
  const _MockLoginPage({required this.defaultEmail});

  final String defaultEmail;

  @override
  Widget build(BuildContext context) {
    return _LoginChrome(
      child: _MockLogin(defaultEmail: defaultEmail, mockStore: context.levit.find<MockStore>()),
    );
  }
}

class _LoginChrome extends StatelessWidget {
  const _LoginChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrototypeSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const EdayaBrandLogo(variant: EdayaLogoVariant.vertical, width: 160),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(context.tr.guardianSpace, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: PrototypeSpacing.sectionGap),
                  SurfaceCard(child: child),
                  const DemoButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockLogin extends StatefulWidget {
  const _MockLogin({required this.defaultEmail, required this.mockStore});

  final String defaultEmail;
  final MockStore mockStore;

  @override
  State<_MockLogin> createState() => _MockLoginState();
}

class _MockLoginState extends State<_MockLogin> {
  var _codeSent = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _codeSent ? context.tr.verifyEmailTitle : context.tr.signInTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrototypeSpacing.xs),
        Text(
          _codeSent
              ? context.tr.enterTheCodeSentTo(widget.defaultEmail)
              : context.tr.seeYourChildrenSSchoolInformation,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrototypeSpacing.xl),
        if (!_codeSent) ...[
          TextFormField(
            initialValue: widget.defaultEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          FilledButton(
            onPressed: () => setState(() => _codeSent = true),
            child: Text(context.tr.sendCodeButton),
          ),
        ] else ...[
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr.code,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrototypeSpacing.xl),
          FilledButton(
            onPressed: () {
              widget.mockStore.signIn();
              context.go('/home');
            },
            child: Text(context.tr.verifyCode),
          ),
        ],
      ],
    );
  }
}
