#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]] || [[ "$1" != guardian && "$1" != teacher ]]; then
  echo "Usage: bash scripts/design-review.sh <guardian|teacher>" >&2
  exit 1
fi

APP="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/$APP"

LOCALE="${EDAYA_DESIGN_REVIEW_LOCALE:-fr}"
echo "Design review locale: $LOCALE (set EDAYA_DESIGN_REVIEW_LOCALE to change)"
echo "Using mock fixtures for $APP — no API required."

if pgrep -x flutter_tester >/dev/null 2>&1; then
  echo "error: flutter_tester is already running." >&2
  echo "Stop flutter run and other Flutter tests, then retry." >&2
  exit 1
fi

if ! EDAYA_DESIGN_REVIEW_LOCALE="$LOCALE" \
  flutter test "test/integration/${APP}_design_review_test.dart" \
    --tags design-review \
    --concurrency=1; then
  echo "error: design review test failed." >&2
  exit 1
fi

INDEX="$ROOT/apps/$APP/design-review/index.html"
if [[ ! -f "$INDEX" ]]; then
  echo "error: expected output missing: $INDEX" >&2
  exit 1
fi

echo ""
echo "Design review pack ready:"
echo "  $INDEX"
