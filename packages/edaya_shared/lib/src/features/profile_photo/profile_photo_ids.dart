import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

String profilePhotoAttachmentStorageKey(String ownerKind, String ownerId) {
  return 'edaya.profile-photo.attachment.$ownerKind.$ownerId';
}

String studentPhotoCommandStorageKey(String command, String studentId) {
  return 'edaya.student-photo.$command.$studentId';
}

Future<String?> readStoredId(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(key)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

Future<void> persistStoredId(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

String newProfilePhotoRequestId() {
  final random = Random.secure();
  return '${DateTime.now().toUtc().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}

Future<String> stableRequestId(String key) async {
  final existing = await readStoredId(key);
  if (existing != null) {
    return existing;
  }
  final next = newProfilePhotoRequestId();
  await persistStoredId(key, next);
  return next;
}
