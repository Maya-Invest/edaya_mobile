import 'dart:async';
import 'dart:typed_data';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_base_url_config.dart';
import '../access/school_client.dart';

/// Read-only avatar for staff, students, and guardians.
///
/// [photoUrl] is typically `{API_URL}/core/files/{attachmentId}/content`, which
/// resolves an authorized download grant before fetching image bytes. Falls back
/// to [initials] on load errors; API credentials stay on same-origin API routes.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    required this.initials,
    this.photoUrl,
    this.schoolClient,
    this.retryTransientLoad = false,
    this.radius = 20,
    this.backgroundColor,
    this.initialsStyle,
  });

  final String name;
  final String initials;
  final String? photoUrl;
  final SchoolClientFactory? schoolClient;
  final bool retryTransientLoad;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? initialsStyle;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  bool _imageFailed = false;
  ImageProvider? _image;
  String? _loadedUrl;
  int _generation = 0;
  Timer? _retry;
  int _attempts = 0;
  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final source = widget.photoUrl?.trim();
    if (_loadedUrl == source) return;
    _retry?.cancel();
    _loadedUrl = source;
    final generation = ++_generation;
    _image = null;
    _imageFailed = false;
    if (source == null || source.isEmpty) return;
    try {
      final auth = context.levit.find<AuthClient>();
      final apiBase = Uri.parse(ApiBaseUrlConfig.apiBaseUrl);
      final parsed = Uri.parse(source);
      final uri = parsed.hasScheme ? parsed : apiBase.resolve(source);
      ImageProvider image;
      if (uri.origin == apiBase.origin && uri.path.startsWith('/core/files/')) {
        final segments = uri.pathSegments;
        if (segments.length != 4 || segments.last != 'content') {
          throw StateError('Unsupported photo resource');
        }
        final client =
            (widget.schoolClient ??
            context.levit.find<SchoolClientFactory>())();
        final grant = await client.getDownloadUrl(attachmentId: segments[2]);
        final downloadUrl = ApiBaseUrlConfig.rewriteLocalDevUrl(
          grant['downloadUrl'] as String,
        );
        final downloadUri = Uri.parse(downloadUrl);
        final localApiStorage =
            downloadUri.origin == apiBase.origin &&
            downloadUri.path.startsWith('/core/files/memory/');
        // Local development serves private bytes through the API. Signed
        // object-storage URLs must never receive the API bearer token.
        final resource = Uri.parse(apiBase.origin);
        var token = localApiStorage
            ? await auth.getAccessToken(resource: resource)
            : null;
        Future<http.Response> fetch() async {
          final request = http.Request('GET', downloadUri)
            ..followRedirects = !localApiStorage;
          if (token != null) request.headers['Authorization'] = 'Bearer $token';
          return http.Response.fromStream(
            await auth.businessHttpClient.send(request),
          );
        }

        var response = await fetch();
        if (localApiStorage && response.statusCode == 401) {
          auth.invalidateAccessToken(resource: resource, token: token!);
          token = await auth.getAccessToken(resource: resource);
          response = await fetch();
        }
        if (response.statusCode != 200) throw StateError('Image unavailable');
        image = MemoryImage(Uint8List.fromList(response.bodyBytes));
      } else {
        image = NetworkImage(uri.toString());
      }
      if (mounted && generation == _generation) setState(() => _image = image);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _imageFailed = true);
        if (widget.retryTransientLoad && _attempts < 2) {
          _attempts++;
          _retry = Timer(Duration(seconds: _attempts), () {
            if (!mounted || generation != _generation) return;
            _loadedUrl = null;
            _loadImage();
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant PersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.schoolClient != widget.schoolClient) {
      _loadedUrl = null;
      _attempts = 0;
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final useImage = _image != null && !_imageFailed;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: useImage ? _image : null,
      onBackgroundImageError: useImage
          ? (_, _) {
              if (mounted) {
                setState(() => _imageFailed = true);
              }
            }
          : null,
      child: useImage
          ? null
          : Text(widget.initials, style: widget.initialsStyle),
    );
  }
}
