import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

const teacherSignatureMaxBytes = 1048576;
const teacherSignatureSourceMaxBytes = 20 * 1024 * 1024;

img.Image decodeSignatureImage(Uint8List bytes) {
  if (bytes.length > teacherSignatureSourceMaxBytes) {
    throw const FormatException('SIGNATURE_IMAGE_INVALID');
  }
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null ||
        decoded.width < 1 ||
        decoded.height < 1 ||
        decoded.width * decoded.height > 40000000) {
      throw const FormatException('SIGNATURE_IMAGE_INVALID');
    }
    return img.bakeOrientation(decoded);
  } catch (_) {
    throw const FormatException('SIGNATURE_IMAGE_INVALID');
  }
}

/// A rectangular crop and bounded PNG preserve ink proportions and alpha.
Uint8List encodeSignatureImage(img.Image source, {Rect? crop}) {
  var image = source.convert(format: img.Format.uint8, numChannels: 4);
  if (crop != null) {
    final x = crop.left.floor().clamp(0, source.width - 1);
    final y = crop.top.floor().clamp(0, source.height - 1);
    image = img.copyCrop(
      image,
      x: x,
      y: y,
      width: crop.width.ceil().clamp(1, source.width - x),
      height: crop.height.ceil().clamp(1, source.height - y),
    );
  }
  for (final maxSide in [1024, 768, 512, 384]) {
    final ratio = math.min(1.0, maxSide / math.max(image.width, image.height));
    final resized = ratio < 1
        ? img.copyResize(
            image,
            width: math.max(1, (image.width * ratio).round()),
            height: math.max(1, (image.height * ratio).round()),
            interpolation: img.Interpolation.linear,
          )
        : image;
    final result = Uint8List.fromList(img.encodePng(resized));
    if (result.length <= teacherSignatureMaxBytes) return result;
  }
  throw const FormatException('SIGNATURE_TOO_LARGE');
}
