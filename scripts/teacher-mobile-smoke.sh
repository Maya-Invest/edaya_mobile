#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export EDAYA_INTEGRATION_TESTS=1
export EDAYA_API_URL="${BASE_URL:-${EDAYA_API_URL:-http://localhost:9999}}"
export EDAYA_TEACHER_EMAIL="${TEACHER_EMAIL:-${EDAYA_TEACHER_EMAIL:-a.toure@ecole-ci.edaya.dev}}"
export EDAYA_ACADEMIC_YEAR_ID="${ACADEMIC_YEAR_ID:-${EDAYA_ACADEMIC_YEAR_ID:-2025-ci}}"
export EDAYA_CLASS_GROUP_ID="${CLASS_GROUP_ID:-${EDAYA_CLASS_GROUP_ID:-ci-6a}}"

cd "$ROOT/tooling/integration_tests"
dart test --tags integration "$@"
