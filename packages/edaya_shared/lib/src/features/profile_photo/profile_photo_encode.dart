import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'profile_photo_config.dart';

Uint8List encodeProfilePhotoJpeg(
  Uint8List source, {
  int rotationTurns = 0,
  int? maxBytes,
}) {
  final decoded = img.decodeImage(source);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const FormatException('PROFILE_PHOTO_DECODE_FAILED');
  }

  var image = decoded;
  final turns = ((rotationTurns % 4) + 4) % 4;
  if (turns != 0) {
    image = img.copyRotate(image, angle: turns * 90);
  }

  final side = math.min(image.width, image.height);
  final cropped = img.copyCrop(
    image,
    x: ((image.width - side) / 2).floor(),
    y: ((image.height - side) / 2).floor(),
    width: side,
    height: side,
  );
  final output = math.min(profilePhotoExportSize, side);
  final resized = img.copyResize(
    cropped,
    width: output,
    height: output,
    interpolation: img.Interpolation.linear,
  );

  final cap = maxBytes ?? profilePhotoMaxBytes();
  const qualities = [92, 85, 75, 62, 50];
  Uint8List? encoded;
  for (final quality in qualities) {
    encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    if (encoded.length <= cap) {
      return encoded;
    }
  }
  throw const ProfilePhotoTooLargeException();
}
