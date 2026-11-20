import '../../app/workspace_navigation.dart';
import 'dart:typed_data';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'signature_editor_page.dart';
import 'signature_encode.dart';
import 'teacher_signature_controller.dart';

/// School-scoped teacher signature management, opened from the teacher profile.
class TeacherSignaturePage extends LScopedView<TeacherSignatureController> {
  const TeacherSignaturePage({
    super.key,
    required this.session,
    required this.schoolClient,
  });
  final AppSessionController session;
  final SchoolClientFactory schoolClient;

  @override
  TeacherSignatureController onConfigScope(LevitScope scope) => scope.put(
    () => TeacherSignatureController(
      session: session,
      schoolClient: schoolClient,
    ),
  );

  Future<void> _edit(
    BuildContext context,
    TeacherSignatureController controller,
    ImageSource? source,
  ) async {
    final key = controller.sessionKey;
    try {
      Uint8List? bytes;
      if (source != null) {
        final picked = await ImagePicker().pickImage(source: source);
        if (picked == null ||
            !context.mounted ||
            controller.sessionKey != key) {
          return;
        }
        if (await picked.length() > teacherSignatureSourceMaxBytes) {
          throw const FormatException('SIGNATURE_IMAGE_INVALID');
        }
        bytes = await picked.readAsBytes();
      }
      if (!context.mounted || controller.sessionKey != key) return;
      final decoded = bytes == null ? null : decodeSignatureImage(bytes);
      final result = await showWorkspaceEditor<Uint8List>(
        context: context,
        title: context.tr.teacherSignatureTitle,
        builder: (_, finish) => SignatureEditorPage(
          session: session,
          identity: key,
          source: decoded,
          onComplete: finish,
        ),
      );
      if (result != null && context.mounted && controller.sessionKey == key) {
        controller.setDraft(result);
      }
    } catch (_) {
      if (context.mounted && controller.sessionKey == key) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr.teacherSignatureImageError)),
        );
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    TeacherSignatureController controller,
  ) async {
    final key = controller.sessionKey;
    final confirmed = await showWorkspaceEditor<bool>(
      context: context,
      title: context.tr.teacherSignatureRemove,
      builder: (context, finish) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(context.tr.teacherSignatureRemoveConfirm),
            TextButton(
              onPressed: () => finish(false),
              child: Text(context.tr.cancel),
            ),
            FilledButton(
              onPressed: () => finish(true),
              child: Text(context.tr.teacherSignatureRemove),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted && key == controller.sessionKey) {
      await controller.remove();
    }
  }

  @override
  Widget buildView(
    BuildContext context,
    TeacherSignatureController controller,
  ) {
    controller.identity.value;
    final image = controller.draft.value ?? controller.currentImage.value;
    final busy = controller.saving.value || controller.loading.value;
    return PopScope(
      canPop: controller.draft.value == null && !busy,
      onPopInvokedWithResult: (popped, _) async {
        if (popped || busy || controller.confirmingClose) return;
        controller.confirmingClose = true;
        final discard = await confirmWorkspaceDiscard(context);
        if (!context.mounted) return;
        controller.confirmingClose = false;
        if (!discard) return;
        controller.discardDraft();
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          closeWorkspaceSheet(context);
        }
      },
      child: Scaffold(
        appBar: ModalRoute.of(context) is ModalBottomSheetRoute
            ? null
            : AppBar(title: Text(context.tr.teacherSignatureTitle)),
        body: !controller.available
            ? Center(child: Text(context.tr.accountProfileUnavailable))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(context.tr.teacherSignatureUsage),
                  const SizedBox(height: 24),
                  if (controller.loading.value)
                    const Center(child: CircularProgressIndicator()),
                  if (image != null)
                    Semantics(
                      label: context.tr.teacherSignaturePreview,
                      image: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: EdayaTokens.lightCard,
                          borderRadius: BorderRadius.circular(
                            EdayaTokens.radiusSurface,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.memory(
                            image,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  else if (!controller.loading.value)
                    Center(child: Text(context.tr.teacherSignatureEmpty)),
                  if (controller.draft.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(context.tr.teacherSignatureDraft),
                    ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('signature-draw'),
                        onPressed: busy
                            ? null
                            : () => _edit(context, controller, null),
                        icon: const Icon(Icons.draw_outlined),
                        label: Text(context.tr.teacherSignatureDraw),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _edit(
                                context,
                                controller,
                                ImageSource.gallery,
                              ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(context.tr.teacherSignatureChooseImage),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _edit(
                                context,
                                controller,
                                ImageSource.camera,
                              ),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(context.tr.teacherSignatureTakePhoto),
                      ),
                    ],
                  ),
                  if (controller.error.value.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.error.value,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (controller.draft.value == null)
                      TextButton(
                        onPressed: busy ? null : controller.load,
                        child: Text(context.tr.retry),
                      ),
                  ],
                  if (controller.message.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(controller.message.value),
                    ),
                  if (controller.draft.value != null) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : controller.save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: controller.saving.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr.save),
                    ),
                    TextButton(
                      onPressed: busy ? null : controller.discardDraft,
                      child: Text(context.tr.teacherSignatureDiscard),
                    ),
                  ],
                  if (controller.currentAttachmentId.value != null) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => _remove(context, controller),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr.teacherSignatureRemove),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
