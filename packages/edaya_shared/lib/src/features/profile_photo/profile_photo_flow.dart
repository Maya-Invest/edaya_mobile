import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'profile_photo_crop_page.dart';
import 'profile_photo_pick.dart';

Future<Uint8List?> pickAndCropProfilePhoto(BuildContext context) async {
  final picked = await pickProfilePhotoSource();
  if (picked == null || !context.mounted) {
    return null;
  }
  final bytes = await picked.readAsBytes();
  if (!context.mounted) {
    return null;
  }
  return showProfilePhotoCropPage(context, source: bytes);
}
