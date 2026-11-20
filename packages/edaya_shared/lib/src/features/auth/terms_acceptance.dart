import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../l10n/l10n_extension.dart';
import 'login_controller.dart';

/// Opens a scrollable terms dialog; acceptance belongs to the login route.
class TermsAcceptance extends StatefulWidget {
  const TermsAcceptance({super.key, required this.controller});
  final LoginController controller;
  @override
  State<TermsAcceptance> createState() => _TermsAcceptanceState();
}

class _TermsAcceptanceState extends State<TermsAcceptance> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'fr';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.syncTermsLocale(locale);
      }
    });
  }

  void _readTerms() {
    final controller = widget.controller;
    final document = controller.terms.value?.document;
    if (document == null || controller.isBusy.value) return;
    final identifier = controller.email.value.trim().toLowerCase();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('auth-terms-dialog'),
        scrollable: true,
        title: Text(document.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (document.status == 'draft') Text(dialogContext.tr.termsDraft),
            for (final section in document.sections) ...[
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  section.heading,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
              ),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(paragraph),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('auth-terms-close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).closeButtonLabel,
            ),
          ),
          FilledButton(
            key: const Key('auth-terms-confirm'),
            onPressed: () {
              // Never accept a different document or identity than the one reviewed.
              if (mounted &&
                  !controller.isBusy.value &&
                  !controller.termsLoading.value &&
                  !controller.termsLoadError.value &&
                  identical(controller.terms.value?.document, document) &&
                  controller.email.value.trim().toLowerCase() == identifier) {
                controller.setTermsAccepted(true);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(dialogContext.tr.termsConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LWatch(() {
    final controller = widget.controller;
    if (controller.termsLoading.value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(context.tr.termsLoading),
        ),
      );
    }
    if (controller.termsLoadError.value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              context.tr.termsUnavailable,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => controller.loadTerms(
              locale: Localizations.localeOf(context).languageCode == 'en'
                  ? 'en'
                  : 'fr',
            ),
            child: Text(context.tr.termsRetry),
          ),
        ],
      );
    }
    final terms = controller.terms.value;
    final document = terms?.document;
    if (document == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (document.status == 'draft') Text(context.tr.termsDraft),
        TextButton(
          key: const Key('auth-terms-read'),
          onPressed: controller.isBusy.value ? null : _readTerms,
          child: Text(context.tr.termsRead),
        ),
        if (terms!.enforced)
          CheckboxListTile(
            key: const Key('auth-terms-accept'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.tr.termsAccept),
            value: controller.termsAccepted.value,
            onChanged: controller.isBusy.value
                ? null
                : (value) => controller.setTermsAccepted(value == true),
          ),
        const SizedBox(height: 16),
      ],
    );
  });
}
