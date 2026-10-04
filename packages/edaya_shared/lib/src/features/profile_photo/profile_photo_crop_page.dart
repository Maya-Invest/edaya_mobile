import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/edaya_tokens.g.dart';
import '../../l10n/l10n_extension.dart';
import 'profile_photo_config.dart';
import 'profile_photo_encode.dart';

Future<Uint8List?> showProfilePhotoCropPage(
  BuildContext context, {
  required Uint8List source,
}) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(builder: (_) => ProfilePhotoCropPage(source: source)),
  );
}

class ProfilePhotoCropPage extends StatefulWidget {
  const ProfilePhotoCropPage({super.key, required this.source});

  final Uint8List source;

  @override
  State<ProfilePhotoCropPage> createState() => _ProfilePhotoCropPageState();
}

class _ProfilePhotoCropPageState extends State<ProfilePhotoCropPage> {
  var _turns = 0;
  var _busy = false;

  Future<void> _confirm() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final encoded = encodeProfilePhotoJpeg(
        widget.source,
        rotationTurns: _turns,
      );
      if (mounted) {
        Navigator.of(context).pop(encoded);
      }
    } on ProfilePhotoTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr.profilePhotoTooLarge)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.profilePhotoCropTitle)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          children: [
            Text(context.tr.profilePhotoCropHint),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    EdayaTokens.radiusOverlay,
                  ),
                  child: Transform.rotate(
                    angle: _turns * 1.5707963267948966,
                    child: Image.memory(
                      widget.source,
                      fit: BoxFit.cover,
                      width: 280,
                      height: 280,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _turns = (_turns + 1) % 4),
              icon: const Icon(Icons.rotate_right),
              label: Text(context.tr.profilePhotoRotate),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr.profilePhotoConfirmCrop),
            ),
          ],
        ),
      ),
    );
  }
}
