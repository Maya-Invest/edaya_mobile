import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/runtime.dart' show personInitials;

typedef AccountPortrait = ({String url, SchoolClientFactory? client});

/// School portraits predate account-wide display. Resolve one source in stable
/// order and download protected media with that school's own teacher grant.
class TeacherPortraitSource {
  TeacherPortraitSource(this.auth);
  final AuthClient auth;
  String? _key;
  Future<AccountPortrait?>? _request;
  DateTime? _expires;

  Future<AccountPortrait?> resolve(
    String account,
    String? image,
    List<SchoolAuthorizationProfile> profiles,
  ) {
    final teachers = profiles.where((p) => p.kind == 'teacher').toList()
      ..sort((a, b) {
        final school = a.schoolId.compareTo(b.schoolId);
        return school != 0 ? school : a.actorId.compareTo(b.actorId);
      });
    final key = [
      ApiBaseUrlConfig.apiBaseUrl,
      account,
      image,
      for (final p in teachers) '${p.schoolId}/${p.actorId}',
    ].join('|');
    if (_key == key && _request != null && DateTime.now().isBefore(_expires!)) {
      return _request!;
    }
    _key = key;
    _expires = DateTime.now().add(const Duration(minutes: 5));
    return _request = _read(image, teachers);
  }

  Future<AccountPortrait?> _read(
    String? image,
    List<SchoolAuthorizationProfile> teachers,
  ) async {
    if (image != null && image.trim().isNotEmpty) {
      return (url: image, client: null);
    }
    for (final profile in teachers) {
      SchoolClient factory() => createEdayaSchoolClient(
        auth,
        getSchoolId: () => profile.schoolId,
        getActorId: () => profile.actorId,
        getActorKind: () => 'teacher',
      );
      try {
        final row = await factory().teachers.get(profile.actorId);
        final url = row['photoUrl'] as String?;
        if (url != null && url.trim().isNotEmpty) {
          return (url: url, client: factory);
        }
      } on ApiError catch (error) {
        if (error.status != 403 && error.status != 404) rethrow;
      }
    }
    return null;
  }

  void invalidate() {
    _request = null;
  }
}

class TeacherPortrait extends StatelessWidget {
  const TeacherPortrait({super.key, required this.radius});
  final double radius;
  @override
  Widget build(BuildContext context) {
    final session = context.levit.find<AppSessionController>();
    final source = context.levit.find<TeacherPortraitSource>();
    return LWatch(() {
      final user = session.user.value;
      if (user == null) return SizedBox.square(dimension: radius * 2);
      final profiles = session.availableProfiles.value;
      return _PortraitView(
        key: ValueKey(user.id),
        radius: radius,
        name: user.name ?? '',
        source: source,
        read: () => source.resolve(user.id, user.image, profiles),
      );
    });
  }
}

class _PortraitView extends StatefulWidget {
  const _PortraitView({
    super.key,
    required this.radius,
    required this.name,
    required this.source,
    required this.read,
  });
  final double radius;
  final String name;
  final TeacherPortraitSource source;
  final Future<AccountPortrait?> Function() read;
  @override
  State<_PortraitView> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<_PortraitView> {
  @override
  Widget build(BuildContext context) {
    final request = widget.read();
    return FutureBuilder<AccountPortrait?>(
      key: ObjectKey(request),
      future: request,
      builder: (_, snapshot) {
        final portrait = snapshot.data;
        if (snapshot.hasError) {
          return IconButton(
            tooltip: context.tr.retry,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(widget.source.invalidate);
            },
          );
        }
        if (portrait == null) {
          return Icon(Icons.account_circle_outlined, size: widget.radius * 2);
        }
        return PersonAvatar(
          key: ObjectKey(portrait.client),
          name: widget.name,
          initials: personInitials(widget.name),
          photoUrl: portrait.url,
          schoolClient: portrait.client,
          retryTransientLoad: true,
          radius: widget.radius,
        );
      },
    );
  }
}
