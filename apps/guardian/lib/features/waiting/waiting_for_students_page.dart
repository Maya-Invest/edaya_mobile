import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'waiting_for_students_controller.dart';

class WaitingForStudentsPage extends LScopedView<WaitingForStudentsController> {
  const WaitingForStudentsPage({super.key, required this.onCheckAgain});

  final Future<void> Function() onCheckAgain;

  @override
  WaitingForStudentsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => WaitingForStudentsController(
        session: scope.find<AppSessionController>(),
        onCheckAgain: onCheckAgain,
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    WaitingForStudentsController controller,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.appTitleGuardian)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LWatch(() {
                  final session = context.levit.find<AppSessionController>();
                  final busy =
                      controller.isBusy.value || session.isSigningOut.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: EdayaBrandLogo(
                          variant: EdayaLogoVariant.vertical,
                          width: 112,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr.waitingForStudentsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr.waitingForStudentsBody,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy ? null : controller.checkAgain,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr.waitingForStudentsCheckAgain),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: busy ? null : controller.signOut,
                        child: Text(context.tr.signOut),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
