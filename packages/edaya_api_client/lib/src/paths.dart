/// Must stay aligned with apps/api/src/lib/school-api/routes/paths.ts
const schoolApiBasePath = '/core';

String schoolApiPath(List<String> segments) {
  return '$schoolApiBasePath/${segments.join('/')}';
}
