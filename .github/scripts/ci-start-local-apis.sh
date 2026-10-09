#!/usr/bin/env bash
# Start or stop empty unified API (no demo seed) for web Playwright CI.
set -euo pipefail

ACTION="${1:?usage: ci-start-local-apis.sh start|stop}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ROOT="${GITHUB_WORKSPACE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PARENT="$(dirname "$WEB_ROOT")"
BACKEND_ROOT="${BACKEND_ROOT:-$PARENT/edaya_backend}"
PID_DIR="${EDAYA_CI_API_PID_DIR:-/tmp/edaya-ci-apis}"
WAIT_SCRIPT="$SCRIPT_DIR/ci-wait-for-url.sh"
API_PORT="${EDAYA_CI_API_PORT:-9999}"
FILES_PORT="${EDAYA_CI_FILES_PORT:-9200}"
API_ORIGIN="http://127.0.0.1:$API_PORT"

TRUSTED_ORIGINS="http://localhost:5173,http://localhost:4173,http://127.0.0.1:5173,http://127.0.0.1:4173"
WEBAPP_ORIGIN="${EDAYA_CI_WEBAPP_ORIGIN:-http://127.0.0.1:4173}"
TRUSTED_ORIGINS="$TRUSTED_ORIGINS,$WEBAPP_ORIGIN${EDAYA_CI_EXTRA_ORIGINS:+,$EDAYA_CI_EXTRA_ORIGINS}"

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

overlay_school_env() {
	local file="$1"
	# Process overrides keep the temporary credential file secrets-only.
	export TRUSTED_ORIGINS WEBAPP_ORIGIN API_ORIGIN
	# Captured identity fixtures must never inherit live delivery providers.
	export EMAIL_TRANSPORT=log SMS_TRANSPORT=log PHONE_AUTH_MODE=disabled
	export PORT="$API_PORT" ALLOW_PUBLIC_SCHOOL_REGISTRATION=true LOG_LEVEL=error
	export LOCAL_FILES_URL="http://127.0.0.1:$FILES_PORT"
	export LOCAL_FILES_ROOT="$PID_DIR/files" LOCAL_FILES_PORT="$FILES_PORT"
	upsert_env "$file" LOCAL_FILES_SECRET dev-local-files-secret
}

dump_logs() {
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
		test -f "$BACKEND_ROOT/package.json"
		test -f "$BACKEND_ROOT/apps/api/.env.example"


		mkdir -p "$PID_DIR"
		# Disposable school configuration, leaving all checkout .env files intact.
		cp "$BACKEND_ROOT/apps/api/.env.example" "$PID_DIR/school.env"
		overlay_school_env "$PID_DIR/school.env"
		export DATABASE_URL="pglite:$PID_DIR/school-db"

		mkdir -p "$PID_DIR"
		export AUTH_DATABASE_URL="pglite:$PID_DIR/account-db"
		(cd "$BACKEND_ROOT" && bun install --frozen-lockfile)

		if [ -n "${GITHUB_ENV:-}" ]; then
			echo "SEED_ENV_FILE=$PID_DIR/school.env" >> "$GITHUB_ENV"
			echo "SEED_API_URL=$API_ORIGIN" >> "$GITHUB_ENV"
			echo "EDAYA_TEST_OTP_FILE=$PID_DIR/otp.jsonl" >> "$GITHUB_ENV"
			echo "EDAYA_TEST_POLICY_FILE=$PID_DIR/privileged-accounts.json" >> "$GITHUB_ENV"
			echo "EDAYA_TEST_CLOCK_FILE=$PID_DIR/clock-offset" >> "$GITHUB_ENV"
		fi

		echo "Starting unified testing API on :$API_PORT"
		start_background "$PID_DIR/school.pid" "$PID_DIR/school.log" "$BACKEND_ROOT" \
			env NODE_ENV=test EDAYA_LOCAL_ENV_FILE="$PID_DIR/school.env" EDAYA_TEST_PORT="$API_PORT" EDAYA_TEST_AUTH_DATABASE_URL="pglite:$PID_DIR/account-db" EDAYA_TEST_TRUSTED_ORIGINS="$TRUSTED_ORIGINS" EDAYA_TEST_POLICY_FILE="$PID_DIR/privileged-accounts.json" EDAYA_TEST_OTP_FILE="$PID_DIR/otp.jsonl" EDAYA_TEST_CLOCK_FILE="$PID_DIR/clock-offset" bun --no-env-file apps/api/src/identity/entries/testing.ts
		if ! bash "$WAIT_SCRIPT" "$API_ORIGIN/reference" 120; then dump_logs; exit 1; fi

		echo "Starting local files on :$FILES_PORT"
		start_background "$PID_DIR/files.pid" "$PID_DIR/files.log" "$BACKEND_ROOT" \
			env EDAYA_LOCAL_ENV_FILE="$PID_DIR/school.env" bun --no-env-file tooling/repo/dev/local-files.ts
		if ! bash "$WAIT_SCRIPT" "http://127.0.0.1:$FILES_PORT/health" 120; then
			dump_logs
			exit 1
		fi
		;;
	stop)
		kill_pidfile "$PID_DIR/files.pid"
		kill_pidfile "$PID_DIR/school.pid"
		rm -f "$PID_DIR/otp.jsonl" "$PID_DIR/clock-offset" "$PID_DIR/privileged-accounts.json" "$PID_DIR/school.env"
		;;
	*)
		echo "Unknown action: $ACTION" >&2
		exit 1
		;;
esac
