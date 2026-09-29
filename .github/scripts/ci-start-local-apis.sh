#!/usr/bin/env bash
# Start or stop empty local Identity + school (no demo seed) for mobile integration CI.
# Seed runs as a separate workflow step: bun repo seed --skip-profile-photos --skip-attachments
set -euo pipefail

ACTION="${1:?usage: ci-start-local-apis.sh start|stop}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${GITHUB_WORKSPACE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PARENT="$(dirname "$REPO_ROOT")"
BACKEND_ROOT="${BACKEND_ROOT:-$PARENT/edaya_backend}"
IDENTITY_ROOT="$BACKEND_ROOT"
PID_DIR="${EDAYA_CI_API_PID_DIR:-/tmp/edaya-ci-apis}"
WAIT_SCRIPT="$SCRIPT_DIR/ci-wait-for-url.sh"
AUTH_PORT="${EDAYA_CI_AUTH_PORT:-9900}"
API_PORT="${EDAYA_CI_API_PORT:-9999}"
FILES_PORT="${EDAYA_CI_FILES_PORT:-9200}"
AUTH_ORIGIN="http://127.0.0.1:$AUTH_PORT"
API_ORIGIN="http://127.0.0.1:$API_PORT"

TRUSTED_ORIGINS="http://localhost:5173,http://localhost:4173,http://127.0.0.1:5173,http://127.0.0.1:4173"
DIRECTORY_SECRET="local-directory-secret"
WEBAPP_ORIGIN="http://localhost:5173"

upsert_env() {
	local file="$1"
	local key="$2"
	local value="$3"
	python3 - "$file" "$key" "$value" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
text = path.read_text() if path.exists() else ""
lines = text.splitlines()
pattern = re.compile(rf"^[ \t]*#?[ \t]*{re.escape(key)}=")
out = []
found = False
for line in lines:
	if pattern.match(line):
		out.append(f"{key}={value}")
		found = True
	else:
		out.append(line)
if not found:
	out.append(f"{key}={value}")
path.write_text("\n".join(out) + "\n")
PY
}

overlay_identity_env() {
	local file="$1"
	upsert_env "$file" TRUSTED_ORIGINS "$TRUSTED_ORIGINS"
	upsert_env "$file" WEBAPP_ORIGIN "$WEBAPP_ORIGIN"
	upsert_env "$file" IDENTITY_DIRECTORY_SECRET "$DIRECTORY_SECRET"
	upsert_env "$file" REQUIRE_EMAIL_VERIFICATION false
	upsert_env "$file" AUTH_DEV_OTP_PEEK false
	upsert_env "$file" AUTH_EMAIL_LOG_OTP false
	upsert_env "$file" TELEGRAM_GATEWAY_TOKEN test-only-captured
	upsert_env "$file" WHATSAPP_ACCESS_TOKEN test-only-captured
	upsert_env "$file" WHATSAPP_PHONE_NUMBER_ID 123456789
	upsert_env "$file" WHATSAPP_API_VERSION v23.0
	upsert_env "$file" WHATSAPP_AUTH_TEMPLATE test
	upsert_env "$file" PORT "$AUTH_PORT"
	upsert_env "$file" BETTER_AUTH_URL "$AUTH_ORIGIN"
	upsert_env "$file" FIRST_PARTY_API_ORIGINS "$API_ORIGIN"
}

overlay_school_env() {
	local file="$1"
	upsert_env "$file" TRUSTED_ORIGINS "$TRUSTED_ORIGINS"
	upsert_env "$file" WEBAPP_ORIGIN "$WEBAPP_ORIGIN"
	upsert_env "$file" IDENTITY_DIRECTORY_SECRET "$DIRECTORY_SECRET"
	upsert_env "$file" PORT "$API_PORT"
	upsert_env "$file" IDENTITY_ISSUER "$AUTH_ORIGIN"
	upsert_env "$file" IDENTITY_DIRECTORY_URL "$AUTH_ORIGIN"
	upsert_env "$file" API_ORIGIN "$API_ORIGIN"
	upsert_env "$file" LOG_LEVEL error
	upsert_env "$file" LOCAL_FILES_URL "http://127.0.0.1:$FILES_PORT"
	upsert_env "$file" LOCAL_FILES_ROOT .data/files
	upsert_env "$file" LOCAL_FILES_SECRET dev-local-files-secret
	upsert_env "$file" LOCAL_FILES_PORT "$FILES_PORT"
}

dump_logs() {
	echo "--- identity.log ---" >&2
	cat "$PID_DIR/identity.log" >&2 || true
	echo "--- school.log ---" >&2
	cat "$PID_DIR/school.log" >&2 || true
}

kill_tree() {
	local pid="$1"
	local child
	if [ -z "$pid" ]; then
		return 0
	fi
	for child in $(pgrep -P "$pid" 2>/dev/null || true); do
		kill_tree "$child"
	done
	kill -TERM "$pid" 2>/dev/null || true
}

kill_pidfile() {
	local pidfile="$1"
	if [ ! -f "$pidfile" ]; then
		return 0
	fi
	local pid
	pid="$(tr -d '[:space:]' <"$pidfile")"
	kill_tree "$pid"
	sleep 1
	kill_tree "$pid"
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		kill -KILL "$pid" 2>/dev/null || true
	fi
	rm -f "$pidfile"
}

start_background() {
	local pidfile="$1"
	local logfile="$2"
	local cwd="$3"
	shift 3
	(
		cd "$cwd"
		"$@"
	) >"$logfile" 2>&1 &
	echo $! >"$pidfile"
}

case "$ACTION" in
	start)
		test -f "$IDENTITY_ROOT/package/identity-client/package.json"
		test -f "$BACKEND_ROOT/package.json"
		test -f "$IDENTITY_ROOT/.env.example"
		test -f "$BACKEND_ROOT/apps/api/.env.example"

		mkdir -p "$PID_DIR" "$IDENTITY_ROOT/apps/identity" "$BACKEND_ROOT/apps/api"

		cp "$IDENTITY_ROOT/.env.example" "$IDENTITY_ROOT/.env"
		if [ -f "$IDENTITY_ROOT/apps/identity/.env.example" ]; then
			cp "$IDENTITY_ROOT/apps/identity/.env.example" "$IDENTITY_ROOT/apps/identity/.env"
		else
			cp "$IDENTITY_ROOT/.env.example" "$IDENTITY_ROOT/apps/identity/.env"
		fi
		cp "$BACKEND_ROOT/apps/api/.env.example" "$BACKEND_ROOT/apps/api/.env"

		overlay_identity_env "$IDENTITY_ROOT/apps/identity/.env"
		overlay_school_env "$BACKEND_ROOT/apps/api/.env"

		echo "Installing Identity dependencies"
		(cd "$IDENTITY_ROOT" && bun install --frozen-lockfile)

		echo "Installing school dependencies"
		(cd "$BACKEND_ROOT" && bun install --frozen-lockfile)

		if [ -n "${GITHUB_ENV:-}" ]; then
			echo "EDAYA_TEST_OTP_FILE=$PID_DIR/otp.jsonl" >> "$GITHUB_ENV"
			echo "EDAYA_TEST_POLICY_FILE=$PID_DIR/privileged-accounts.json" >> "$GITHUB_ENV"
			echo "EDAYA_TEST_CLOCK_FILE=$PID_DIR/clock-offset" >> "$GITHUB_ENV"
		fi

		echo "Starting Identity on :$AUTH_PORT (empty, no seed)"
		start_background "$PID_DIR/identity.pid" "$PID_DIR/identity.log" "$IDENTITY_ROOT" \
			env NODE_ENV=test EDAYA_TEST_POLICY_FILE="$PID_DIR/privileged-accounts.json" EDAYA_TEST_OTP_FILE="$PID_DIR/otp.jsonl" EDAYA_TEST_CLOCK_FILE="$PID_DIR/clock-offset" bun apps/identity/tests/support/live-integration-server.ts
		if ! bash "$WAIT_SCRIPT" "$AUTH_ORIGIN/" 120; then
			dump_logs
			exit 1
		fi

		echo "Starting school API on :$API_PORT (empty, no seed)"
		start_background "$PID_DIR/school.pid" "$PID_DIR/school.log" "$BACKEND_ROOT" \
			bun repo dev
		if ! bash "$WAIT_SCRIPT" "$API_ORIGIN/reference" 120; then
			dump_logs
			exit 1
		fi
		;;
	stop)
		kill_pidfile "$PID_DIR/school.pid"
		kill_pidfile "$PID_DIR/identity.pid"
		;;
	*)
		echo "Unknown action: $ACTION" >&2
		exit 1
		;;
esac
