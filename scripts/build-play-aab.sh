#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${EDAYA_API_URL:-}" ]]; then
  echo "Set EDAYA_API_URL before building a distributable app." >&2
  exit 1
fi
API_URL="$EDAYA_API_URL"
APPS=(guardian teacher)

if [[ $# -gt 0 ]]; then
  APPS=("$@")
fi

require_key_properties() {
  local app="$1"
  local props="$ROOT/apps/$app/android/key.properties"
  if [[ ! -f "$props" ]]; then
    echo "Missing $props — run: bash scripts/create-android-keystore.sh" >&2
    exit 1
  fi
}

build_app() {
  local app="$1"
  require_key_properties "$app"

  echo "Building Play Store AAB for $app (API_URL=$API_URL)..."
  (
    cd "$ROOT/apps/$app"
    flutter build appbundle \
      --release \
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
