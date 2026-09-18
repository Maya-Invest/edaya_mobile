import 'dart:typed_data';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('encodeProfilePhotoJpeg writes a JPEG under the byte cap', () {
    final source = img.Image(width: 80, height: 120);
    img.fill(source, color: img.ColorRgb8(30, 80, 180));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 95));

    final encoded = encodeProfilePhotoJpeg(bytes, maxBytes: 20 * 1024);

    expect(encoded.length, lessThanOrEqualTo(20 * 1024));
    expect(encoded[0], 0xFF);
    expect(encoded[1], 0xD8);
    final decoded = img.decodeJpg(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.width, decoded.height);
  });
}
