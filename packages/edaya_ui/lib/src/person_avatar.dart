import 'package:flutter/material.dart';

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

  @override
  void didUpdateWidget(covariant PersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl?.trim();
    final useImage = url != null && url.isNotEmpty && !_imageFailed;

    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: useImage ? NetworkImage(url) : null,
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
