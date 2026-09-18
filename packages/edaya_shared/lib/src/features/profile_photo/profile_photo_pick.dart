import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickProfilePhotoSource() async {
  final picker = ImagePicker();
  try {
    final camera = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (camera != null) {
      return camera;
    }
  } on PlatformException {
    // Fall through to the gallery when the camera is denied or unavailable.
  }
  return picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
}
