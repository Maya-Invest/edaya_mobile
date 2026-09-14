/// Must stay aligned with apps/api/src/lib/school-api/routes/paths.ts
const schoolApiBasePath = '/core';

String schoolApiPath(List<String> segments) {
  return '$schoolApiBasePath/${segments.join('/')}';
}

String resolveGeneratedPath(
  String pathTemplate,
  Map<String, String> params, {
  String basePath = 'core',
}) {
  final segments = pathTemplate.split('/').map((segment) {
    if (segment.startsWith('{') && segment.endsWith('}')) {
      final name = segment.substring(1, segment.length - 1);
      final value = params[name];
      if (value == null || value.isEmpty) {
        throw ArgumentError('Missing path param $name');
      }
      return Uri.encodeComponent(value);
    }
    return segment;
  }).toList();

  if (basePath == 'root') {
    return '/${segments.join('/')}';
  }
  return schoolApiPath(segments);
}
