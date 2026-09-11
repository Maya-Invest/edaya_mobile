import 'dart:typed_data';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Read-only avatar for staff, students, and guardians.
///
/// [photoUrl] is typically `{API_URL}/core/files/{attachmentId}/content`, which
/// redirects to a presigned object URL. Falls back to [initials] on load errors.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    required this.initials,
    this.photoUrl,
    this.radius = 20,
  });

  final String name;
  final String initials;
  final String? photoUrl;
  final double radius;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  bool _imageFailed = false;
  ImageProvider? _image;
  String? _loadedUrl;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final source = widget.photoUrl?.trim();
    if (_loadedUrl == source) return;
    _loadedUrl = source;
    final generation = ++_generation;
    _image = null;
    _imageFailed = false;
    if (source == null || source.isEmpty) return;
    try {
      final auth = context.levit.find<AuthClient>();
      final base = Uri.parse(auth.baseUrl);
      final uri = base.resolve(source);
      ImageProvider image;
      if (uri.origin == base.origin && uri.path.startsWith('/core/files/')) {
        final response = await auth.businessHttpClient.get(
          uri,
          headers: {'Authorization': 'Bearer ${await auth.getAccessToken()}'},
        );
        if (response.statusCode != 200) throw StateError('Image unavailable');
        image = MemoryImage(Uint8List.fromList(response.bodyBytes));
      } else {
        image = NetworkImage(source);
      }
      if (mounted && generation == _generation) setState(() => _image = image);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _imageFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant PersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final useImage = _image != null && !_imageFailed;

    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: useImage ? _image : null,
      onBackgroundImageError: useImage
          ? (_, _) {
              if (mounted) {
                setState(() => _imageFailed = true);
              }
            }
          : null,
      child: useImage ? null : Text(widget.initials),
    );
  }
}
