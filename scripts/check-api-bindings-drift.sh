#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_root="$repo_root/packages/edaya_api_client"
bindings_spec="$package_root/spec/client-bindings.json"
generator="$package_root/tool/generate_api_bindings.dart"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/edaya-mobile-generated-XXXXXX")"

trap 'rm -rf "$temp_dir"' EXIT

if [[ ! -f "$bindings_spec" ]]; then
  echo "Missing bindings spec at $bindings_spec. Run \`melos run generated:update\` first." >&2
  exit 1
fi

backend_spec="${EDAYA_OPENAPI_SPEC:-$repo_root/../edaya_backend/tooling/repo/fixtures/openapi.json}"
if [[ -f "$backend_spec" ]]; then
  dart run "$generator" --openapi "$backend_spec" --output-dir "$temp_dir"
else
  dart run "$generator" --bindings-input "$bindings_spec" --output-dir "$temp_dir"
fi

changed=()
files=(client_bindings.dart school_client_surface.dart)
if [[ -f "$backend_spec" ]]; then files+=(auth_contracts.dart); fi
for file in "${files[@]}"; do
  if [[ ! -f "$package_root/lib/src/generated/$file" ]] \
    || ! cmp -s "$temp_dir/$file" "$package_root/lib/src/generated/$file"; then
    changed+=("$file")
  fi
done

if ((${#changed[@]} > 0)); then
  echo "Generated API client bindings are out of date. Run \`melos run generated:update\` and commit the changes." >&2
  echo "Changed files:" >&2
  for file in "${changed[@]}"; do
    echo "  - packages/edaya_api_client/lib/src/generated/$file" >&2
  done
  exit 1
fi

echo "Generated API client bindings are up to date."
bash "$repo_root/scripts/check-mobile-contract.sh"
