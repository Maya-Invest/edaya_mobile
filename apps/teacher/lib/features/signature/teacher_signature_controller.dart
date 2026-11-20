import 'dart:async';
import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:http/http.dart' as http;
import 'package:levit_flutter/levit_flutter.dart';

import 'signature_encode.dart';

class TeacherSignatureController extends LevitController {
  TeacherSignatureController({
    required this.session,
    required this.schoolClient,
    http.Client? httpClient,
  }) : _http = httpClient ?? schoolMediaClient(schoolClient());
  final AppSessionController session;
  final SchoolClientFactory schoolClient;
  final http.Client _http;
  final currentAttachmentId = LxVar<String?>(null);
  final currentImage = LxVar<Uint8List?>(null);
  final draft = LxVar<Uint8List?>(null);
  bool confirmingClose = false;
  final loading = LxVar(false);
  final saving = LxVar(false);
  final error = LxVar('');
  final message = LxVar('');
  final identity = LxVar('');
  Map<String, dynamic>? _intent;
  String? _attemptId;
  String? _clearRequestId;
  bool _putDone = false;
  bool _closed = false;
  int _generation = 0;

  String get sessionKey {
    final grants = session.grants.value;
    return '${session.user.value?.id}|${grants?.schoolId}|${grants?.kind}|${grants?.actorId}';
  }

  bool get available => session.grants.value?.kind == 'teacher';
  bool _current(String key, int generation) =>
      !_closed && key == sessionKey && generation == _generation;

  @override
  void onInit() {
    super.onInit();
    for (final reactive in [
      currentAttachmentId,
      currentImage,
      draft,
      loading,
      saving,
      error,
      message,
      identity,
    ]) {
      autoDispose(reactive);
    }
    identity(sessionKey);
    void changed() {
      if (sessionKey == identity.value) return;
      _generation++;
      identity(sessionKey);
      currentAttachmentId(null);
      currentImage(null);
      discardDraft();
      loading(false);
      saving(false);
      error('');
      message('');
      unawaited(load());
    }

    autoDispose(session.grants.stream.listen((_) => changed()));
    autoDispose(session.user.stream.listen((_) => changed()));
    unawaited(load());
  }

  @override
  void onClose() {
    _closed = true;
    _generation++;
    _intent = null;
    _attemptId = null;
    _http.close();
    super.onClose();
  }

  void setDraft(Uint8List bytes) {
    if (!available || saving.value) return;
    draft(bytes);
    _intent = null;
    _attemptId = null;
    _putDone = false;
    error('');
    message('');
  }

  void discardDraft() {
    draft(null);
    _intent = null;
    _attemptId = null;
    _clearRequestId = null;
    _putDone = false;
  }

  Future<Uint8List?> _preview(
    api.SchoolClient client,
    String? id,
    String key,
    int generation,
  ) async {
    if (id == null) return null;
    final grant = await client.getDownloadUrl(attachmentId: id);
    if (!_current(key, generation)) return null;
    final response = await _http
        .get(
          Uri.parse(
            ApiBaseUrlConfig.rewriteLocalDevUrl(grant['downloadUrl'] as String),
          ),
        )
        .timeout(const Duration(seconds: 30));
    if (!_current(key, generation)) return null;
    if (response.statusCode != 200 ||
        response.bodyBytes.length > teacherSignatureMaxBytes) {
      throw StateError('SIGNATURE_UNAVAILABLE');
    }
    return response.bodyBytes;
  }

  Future<void> load() async {
    if (!available || saving.value || loading.value) return;
    final key = sessionKey;
    final generation = _generation;
    final client = schoolClient();
    final id = session.grants.value!.actorId;
    loading(true);
    error('');
    try {
      final teacher = await client.teachers.get(id);
      if (!_current(key, generation)) return;
      final attachmentId = teacher['signatureAttachmentId'] as String?;
      if (currentAttachmentId.value != attachmentId) {
        currentImage(null);
        _clearRequestId = null;
      }
      currentAttachmentId(attachmentId);
      final image = await _preview(client, attachmentId, key, generation);
      if (!_current(key, generation)) return;
      currentImage(image);
    } catch (_) {
      if (_current(key, generation)) {
        error(systemL10n().teacherSignatureLoadError);
      }
    } finally {
      if (_current(key, generation)) loading(false);
    }
  }

  Future<bool> save() async {
    final bytes = draft.value;
    if (!available || bytes == null || saving.value) return false;
    final key = sessionKey;
    final generation = _generation;
    final client = schoolClient();
    saving(true);
    error('');
    message('');
    try {
      if (!_putDone &&
          _intent != null &&
          DateTime.parse(
            _intent!['expiresAt'] as String,
          ).isBefore(DateTime.now())) {
        _intent = null;
        _attemptId = null;
      }
      _attemptId ??= newProfilePhotoRequestId();
      final intent =
          _intent ??
          await client.createTeacherSignatureUpload({
            'attachmentId': _attemptId,
            'fileName': 'signature.png',
            'mimeType': 'image/png',
            'sizeBytes': bytes.length,
          });
      if (!_current(key, generation)) return false;
      _intent = intent;
      if (!_putDone) {
        final rawHeaders = intent['headers'];
        final headers = <String, String>{
          if (rawHeaders is Map)
            for (final entry in rawHeaders.entries)
              entry.key.toString(): entry.value.toString(),
          'Content-Type': 'image/png',
        };
        final response = await _http
            .put(
              Uri.parse(
                ApiBaseUrlConfig.rewriteLocalDevUrl(
                  intent['uploadUrl'] as String,
                ),
              ),
              headers: headers,
              body: bytes,
            )
            .timeout(const Duration(seconds: 30));
        if (!_current(key, generation)) return false;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('SIGNATURE_UPLOAD_FAILED');
        }
        _putDone = true;
      }
      final teacher = await client.completeTeacherSignatureUpload({
        'attachmentId': intent['attachmentId'],
      });
      if (!_current(key, generation)) return false;
      final savedId = teacher['signatureAttachmentId'] as String?;
      currentAttachmentId(savedId);
      final preview = savedId == intent['attachmentId']
          ? bytes
          : await _preview(client, savedId, key, generation);
      if (!_current(key, generation)) return false;
      currentImage(preview);
      discardDraft();
      message(systemL10n().teacherSignatureSaved);
      return true;
    } catch (failure) {
      if (_current(key, generation)) {
        if (failure is api.ApiError &&
            failure.body.toString().contains('ATTACHMENT_UPLOAD_EXPIRED')) {
          _intent = null;
          _attemptId = null;
          _putDone = false;
        }
        error(systemL10n().teacherSignatureSaveError);
      }
      return false;
    } finally {
      if (_current(key, generation)) saving(false);
    }
  }

  Future<bool> remove() async {
    final id = currentAttachmentId.value;
    if (!available || id == null || saving.value) return false;
    final key = sessionKey;
    final generation = _generation;
    final client = schoolClient();
    saving(true);
    error('');
    try {
      _clearRequestId ??= newProfilePhotoRequestId();
      final teacher = await client.clearTeacherSignature({
        'requestId': _clearRequestId,
        'attachmentId': id,
      });
      if (!_current(key, generation)) return false;
      final savedId = teacher['signatureAttachmentId'] as String?;
      currentAttachmentId(savedId);
      final preview = await _preview(client, savedId, key, generation);
      if (!_current(key, generation)) return false;
      currentImage(preview);
      discardDraft();
      message(systemL10n().teacherSignatureRemoved);
      return true;
    } catch (_) {
      if (_current(key, generation)) {
        error(systemL10n().teacherSignatureSaveError);
      }
      return false;
    } finally {
      if (_current(key, generation)) saving(false);
    }
  }
}
