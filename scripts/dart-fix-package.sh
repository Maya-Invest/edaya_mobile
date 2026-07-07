#!/usr/bin/env bash
set -euo pipefail

if [ -d lib ]; then
  dart fix --apply lib
fi

if [ -d test ]; then
  dart fix --apply test
fi
