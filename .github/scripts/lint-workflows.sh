#!/usr/bin/env bash
set -euo pipefail
version=1.7.12
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux_amd64; checksum=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 ;;
  Linux-aarch64) platform=linux_arm64; checksum=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6 ;;
  Darwin-arm64) platform=darwin_arm64; checksum=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f ;;
  Darwin-x86_64) platform=darwin_amd64; checksum=5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644 ;;
  *) echo 'Unsupported workflow validator platform' >&2; exit 1 ;;
esac
binary="${ACTIONLINT_BIN:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/edaya-ci-tools/actionlint-$version-$platform/actionlint}"
if [ ! -x "$binary" ]; then
  directory="$(dirname "$binary")"
  mkdir -p "$directory"
  archive="$(mktemp "${TMPDIR:-/tmp}/edaya-actionlint-XXXXXX")"
  trap 'rm -f "$archive"' EXIT
  curl --fail --silent --show-error --location --retry 3 --max-time 60 \
    "https://github.com/rhysd/actionlint/releases/download/v$version/actionlint_${version}_${platform}.tar.gz" -o "$archive"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
  fi
  test "$actual" = "$checksum"
  tar -xzf "$archive" -C "$directory" actionlint
fi
test "$("$binary" --version | head -n 1)" = "$version"
# Shell syntax is checked separately; no optional linter dependencies are installed.
"$binary" -shellcheck= .github/workflows/*.yml
for script in .github/scripts/*.sh; do bash -n "$script"; done
