#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_URL="${EDAYA_AUTH_URL:-https://staging.identity.api.edayaplus.com}"
API_URL="${EDAYA_API_URL:-https://staging.school.api.edayaplus.com}"
APPS=(guardian teacher)

if [[ $# -gt 0 ]]; then
  APPS=("$@")
fi

require_key_properties() {
  local app="$1"
  local props="$ROOT/apps/$app/android/key.properties"
  if [[ ! -f "$props" ]]; then
    echo "Missing $props — run: melos run android:keystore:create" >&2
    exit 1
  fi
}

build_app() {
  local app="$1"
  require_key_properties "$app"

  echo "Building Play Store AAB for $app (AUTH_URL=$AUTH_URL, API_URL=$API_URL)..."
  (
    cd "$ROOT/apps/$app"
    flutter build appbundle \
      --release \
      --dart-define="AUTH_URL=$AUTH_URL" \
      --dart-define="API_URL=$API_URL"
  )

  local aab="$ROOT/apps/$app/build/app/outputs/bundle/release/app-release.aab"
  if [[ -f "$aab" ]]; then
    echo "Built: $aab"
    ls -lh "$aab"
  else
    echo "Expected AAB not found: $aab" >&2
    exit 1
  fi
}

cd "$ROOT"
dart pub get

for app in "${APPS[@]}"; do
  build_app "$app"
done

echo "All Play Store AABs built successfully."
