#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_root="$repo_root/packages/edaya_api_client"
bindings_spec="$package_root/spec/client-bindings.json"
output_dir="$package_root/lib/src/generated"
generator="$package_root/tool/generate_api_bindings.dart"

generator_args=(
  dart run "$generator"
  --bindings "$bindings_spec"
  --output-dir "$output_dir"
)

if [[ -n "${EDAYA_OPENAPI_URL:-}" ]]; then
  generator_args+=(--openapi-url "$EDAYA_OPENAPI_URL")
elif [[ -n "${EDAYA_OPENAPI_SPEC:-}" ]]; then
  generator_args+=(--openapi "$EDAYA_OPENAPI_SPEC")
else
  cat >&2 <<'EOF'
OpenAPI source required. Set one of:
  EDAYA_OPENAPI_URL   — download the published /doc OpenAPI JSON
  EDAYA_OPENAPI_SPEC  — path to a local openapi.json file
EOF
  exit 1
fi

"${generator_args[@]}"
