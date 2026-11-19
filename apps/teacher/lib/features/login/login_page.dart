import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage, PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../config/api_config.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../di/prototype_module.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveLoginPage();
    }
    return const _MockLoginPage();
  }
}

class _MockLoginPage extends StatefulWidget {
  const _MockLoginPage();

  @override
  State<_MockLoginPage> createState() => _MockLoginPageState();
}

class _MockLoginPageState extends State<_MockLoginPage> {
  var _codeSent = false;

  @override
  Widget build(BuildContext context) {
    final store = context.levit.find<MockStore>();

    return _LoginChrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _codeSent ? context.tr.verifyContactTitle : context.tr.signInTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          Text(
            _codeSent
                ? context.tr.teacherMockVerifyHint
                : context.tr.teacherMockSignInHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PrototypeSpacing.md),
          if (!_codeSent) ...[
            TextField(
              decoration: InputDecoration(
                labelText: context.tr.emailLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: PrototypeSpacing.lg),
            FilledButton(
              onPressed: () => setState(() => _codeSent = true),
              child: Text(context.tr.sendCodeButton),
            ),
          ] else ...[
            TextField(
              decoration: InputDecoration(
                labelText: context.tr.otpLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: PrototypeSpacing.lg),
            FilledButton(
              onPressed: () {
                store.signIn();
                context.go('/home');
              },
              child: Text(context.tr.verifyCodeButton),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveLoginPage extends LScopedView<LoginController> {
  const _LiveLoginPage();

  @override
  LoginController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LoginController(
        authClient: scope.find<AuthClient>(),
        session: scope.find<AppSessionController>(),
        defaultEmail: ApiConfig.devTeacherEmail,
        onSignInSuccess: () => initializeTeacherAuthenticatedContext(scope),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LoginController controller) {
    return _LoginChrome(
      child: PasswordlessLoginForm(
        controller: controller,
        teacherQuickLogin: true,
      ),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(16) + 40,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: PrototypeSpacing.md,
        ),
        actions: const [_LoginLanguagePicker()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrototypeSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EdayaBrandLogo(
                    variant: EdayaLogoVariant.vertical,
                    width: 160,
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  Text(
                    context.tr.teacherSpace,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PrototypeSpacing.xl),
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

class _LoginLanguagePicker extends StatelessWidget {
  const _LoginLanguagePicker();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = Localizations.localeOf(context).languageCode;
    return MenuAnchor(
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        minimumSize: const WidgetStatePropertyAll(Size(176, 0)),
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrototypeRadii.md),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final (option, flag, label) in const [
          (LanguagePreference.en, '🇬🇧', 'English'),
          (LanguagePreference.fr, '🇫🇷', 'Français'),
        ])
          MenuItemButton(
            key: ValueKey('login-language-${option.name}'),
            onPressed: () =>
                context.levit.find<AppSettingsController>().setLanguage(option),
            leadingIcon: ExcludeSemantics(child: Text(flag)),
            trailingIcon: option.name == current
                ? Icon(Icons.check, size: 18, color: colors.primary)
                : null,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
              backgroundColor: option.name == current
                  ? WidgetStatePropertyAll(
                      colors.primary.withValues(alpha: 0.05),
                    )
                  : null,
            ),
            child: Semantics(
              selected: option.name == current,
              child: Text(label),
            ),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        expanded: controller.isOpen,
        child: TextButton(
          key: const ValueKey('login-language'),
          onPressed: controller.isOpen ? controller.close : controller.open,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: colors.onSurface,
            backgroundColor: colors.surface,
            side: BorderSide(color: colors.outlineVariant),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
              horizontal: PrototypeSpacing.sm,
            ),
          ),
          child: Tooltip(
            message: context.tr.settingsLanguage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(current.toUpperCase()),
                const SizedBox(width: 6),
                Icon(
                  controller.isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
