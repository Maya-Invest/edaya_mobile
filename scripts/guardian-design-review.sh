#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/guardian"

API_URL="${EDAYA_API_URL:-http://localhost:9999}"
LOCALE="${EDAYA_DESIGN_REVIEW_LOCALE:-fr}"

if [[ -z "${EDAYA_API_URL:-}" ]]; then
  echo "Using default API URL ($API_URL). Set EDAYA_API_URL to target staging."
fi
echo "Design review locale: $LOCALE (set EDAYA_DESIGN_REVIEW_LOCALE to change)"

if ! curl -sf --max-time 5 "${API_URL}/auth/get-session" >/dev/null; then
  echo "error: API not reachable at ${API_URL}" >&2
  echo "Start the backend first (e.g. cd edaya_backend && bun dev)." >&2
  exit 1
fi

echo "Loading Google Fonts for readable text (network required)."

EDAYA_API_URL="$API_URL" \
EDAYA_INTEGRATION_TESTS=1 \
EDAYA_DESIGN_REVIEW_LOCALE="$LOCALE" \
flutter test test/integration/guardian_design_review_test.dart --tags design-review

echo ""
echo "Design review pack ready:"
echo "  $ROOT/apps/guardian/design-review/index.html"
