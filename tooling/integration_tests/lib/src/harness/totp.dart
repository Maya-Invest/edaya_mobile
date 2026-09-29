import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// RFC 6238 test authenticator. Secrets and generated codes must never be logged.
String authenticatorCode(String secret, {DateTime? at}) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var buffer = 0;
  var bits = 0;
  final key = <int>[];
  for (final character in secret.toUpperCase().replaceAll('=', '').split('')) {
    final value = alphabet.indexOf(character);
    if (value < 0) throw StateError('Invalid authenticator setup secret');
    buffer = (buffer << 5) | value;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      key.add((buffer >> bits) & 255);
      buffer &= (1 << bits) - 1;
    }
  }
  final counter = ByteData(8)
    ..setUint64(0, (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 30000);
  final digest = Hmac(sha1, key).convert(counter.buffer.asUint8List()).bytes;
  final offset = digest.last & 15;
  final value =
      ((digest[offset] & 127) << 24) |
      (digest[offset + 1] << 16) |
      (digest[offset + 2] << 8) |
      digest[offset + 3];
  return (value % 1000000).toString().padLeft(6, '0');
}
