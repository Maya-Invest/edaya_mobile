#!/usr/bin/env bash
set -euo pipefail

url="${1:?URL required}"
max_attempts="${2:-60}"

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if curl -sf "$url" > /dev/null; then
    echo "Ready: $url"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for $url after $((max_attempts * 2))s"
exit 1
