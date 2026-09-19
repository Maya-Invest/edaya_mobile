import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:http/http.dart' as http;

import '../../config/api_base_url_config.dart';
import 'profile_photo_config.dart';
import 'profile_photo_ids.dart';

class UploadedProfilePhoto {
  const UploadedProfilePhoto({
    required this.attachmentId,
    required this.photoUrl,
  });

  final String attachmentId;
  final String photoUrl;
}

String profilePhotoContentPath(String attachmentId) {
  return '/core/files/$attachmentId/content';
}

Future<UploadedProfilePhoto> uploadProfilePhoto({
  required SchoolClient client,
  required String schoolId,
  required String ownerKind,
  required String ownerId,
  required Uint8List jpegBytes,
}) async {
  final storageKey = profilePhotoAttachmentStorageKey(ownerKind, ownerId);
  final storedAttachmentId = await readStoredId(storageKey);
  final intent = await client.createProfilePhotoUpload({
    'ownerKind': ownerKind,
    'ownerId': ownerId,
    'fileName': profilePhotoFileName,
    'mimeType': profilePhotoJpegMime,
    'sizeBytes': jpegBytes.length,
    if (storedAttachmentId != null) 'attachmentId': storedAttachmentId,
  });

  final attachmentId = intent['attachmentId'] as String;
  await persistStoredId(storageKey, attachmentId);

  final uploadUrl = ApiBaseUrlConfig.rewriteLocalDevUrl(
    intent['uploadUrl'] as String,
  );
  final rawHeaders = intent['headers'];
  final headers = <String, String>{
    if (rawHeaders is Map)
      for (final entry in rawHeaders.entries)
        entry.key.toString(): entry.value.toString(),
  };
  if (!headers.containsKey('Content-Type') &&
      !headers.containsKey('content-type')) {
    headers['Content-Type'] = profilePhotoJpegMime;
  }

  final put = await http.put(
    Uri.parse(uploadUrl),
    headers: headers,
    body: jpegBytes,
  );
  if (put.statusCode < 200 || put.statusCode >= 300) {
    throw StateError('Profile photo upload failed (${put.statusCode})');
  }

  await client.completeProfilePhotoUpload({
    'id': attachmentId,
    'schoolId': schoolId,
    'ownerKind': ownerKind,
    'ownerId': ownerId,
    'fileName': profilePhotoFileName,
    'storageKey': intent['storageKey'],
    'status': 'ready',
    'mimeType': profilePhotoJpegMime,
    'sizeBytes': jpegBytes.length,
  });

  return UploadedProfilePhoto(
    attachmentId: attachmentId,
    photoUrl: profilePhotoContentPath(attachmentId),
  );
}
