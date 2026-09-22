#!/usr/bin/env bash
# Compare mobile-required operations with the sibling backend contract when it
# is checked out next to this repo. Staff-only API growth is not a mobile gap.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_root="${EDAYA_BACKEND_ROOT:-$(cd "$repo_root/../edaya_backend" 2>/dev/null && pwd || true)}"

require_file() {
  local file="$1"
  local text="$2"
  if ! grep -q "$text" "$file"; then
    echo "Missing mobile contract text '$text' in $file" >&2
    exit 1
  fi
}

require_file "$repo_root/packages/edaya_api_client/lib/src/school_client.dart" "authorizationProfiles"
require_file "$repo_root/apps/teacher/lib/features/evaluations/live_evaluations_controller.dart" "assessmentId"
require_file "$repo_root/packages/edaya_shared/lib/src/academic/normalized_average.dart" "normalizedAverageOutOf20"

if [[ -z "$backend_root" || ! -d "$backend_root" ]]; then
  echo "Sibling backend checkout not found; skipped backend operation comparison."
  exit 0
fi

require_file "$backend_root/package/domain-service/src/services/runtime/school-command-catalog.ts" "writeReportCardSectionComments"
require_file "$backend_root/package/domain-service/src/services/runtime/school-command-catalog.ts" "updateTeacherSelfProfile"
require_file "$backend_root/apps/api/src/routes/authorization-profiles.route.ts" "authorization/profiles"
require_file "$backend_root/apps/api/src/lib/school-api/registry.ts" "getTeacherTimetable"
echo "Mobile-required backend operations are present."
