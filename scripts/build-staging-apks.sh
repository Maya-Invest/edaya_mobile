#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_URL="https://staging.identity.edayaplus.com"
API_URL="https://staging.api.school.edayaplus.com"
test "${RELEASE_TARGET:-staging}" = staging
flutter --version --machine | python3 -c 'import json,sys; assert json.load(sys.stdin)["frameworkVersion"] == "3.44.8", "Flutter 3.44.8 required"'
mkdir -p "$ROOT/release-apks"
for app in guardian teacher; do
  test -s "$ROOT/apps/$app/android/key.properties" || { echo "Missing release signing configuration for $app" >&2; exit 1; }
  test -s "$ROOT/apps/$app/android/app/google-services.json" || { echo "Missing Firebase configuration for $app" >&2; exit 1; }
  (
    cd "$ROOT/apps/$app"
    flutter build apk --release --dart-define="AUTH_URL=$AUTH_URL" --dart-define="API_URL=$API_URL"
  )
  cp "$ROOT/apps/$app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/release-apks/edaya-$app-staging.apk"
done
python3 - "$ROOT/release-apks" <<'PY'
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
(root / 'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in sorted(root.glob('*.apk'))))
PY
