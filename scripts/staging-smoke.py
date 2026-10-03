#!/usr/bin/env python3
"""Native staging smoke using already provisioned private sessions."""
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ["staging.identity.email-only", "staging.identity.no-test-access", "staging.teacher.subject", "staging.teacher.homeroom", "staging.guardian.ci-g1", "staging.guardian.ci-g4"]


def preflight(env):
    errors = []
    for field, expected in [("EDAYA_API_URL", "https://staging.api.edayaplus.com")]:
        if env.get(field) != expected:
            errors.append(field + ": recorded staging URL required")
    if env.get("TEST_OTP_ACCESS", "false") != "false" or any(env.get(field) for field in ["EDAYA_TEST_OTP_FILE", "EDAYA_TEST_CLOCK_FILE"]):
        errors.append("OTP capture and test clock configuration are forbidden in staging smoke")
    try:
        file = Path(env["SEED_AUTH_SESSIONS_FILE"])
        if stat.S_IMODE(file.stat().st_mode) & 0o077:
            raise ValueError()
        credentials = json.loads(file.read_text())
        for email in ["a.toure@ecole-ci.edaya.dev", "k.diomande@ecole-ci.edaya.dev", "m.kone@mail.ci", "k.yao@mail.ci"]:
            if not isinstance(credentials.get(email), str) or not credentials[email]:
                raise ValueError()
    except (KeyError, OSError, ValueError, AttributeError):
        errors.append("SEED_AUTH_SESSIONS_FILE: valid private fixture sessions required (mode 0600)")
    return errors


def main():
    errors = preflight(os.environ)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    spec = importlib.util.spec_from_file_location("local_integration_runner", ROOT / "scripts/integration-runner.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    result = subprocess.run(["dart", "-DTEST_OTP_ACCESS=false", "test", "test/staging", "--tags", "staging", "--reporter", "json"], cwd=ROOT / "tooling/integration_tests", env={**os.environ, "TEST_OTP_ACCESS": "false"}, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = [runner.redact_event(line) for line in result.stdout.splitlines(True)]
    report = runner.evaluate(lines, result.returncode, REQUIRED)
    directory = Path(os.environ.get("RELEASE_ROOT", str(ROOT.parent))) / "release/mobile-staging-smoke"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "events.jsonl").write_text("".join(lines))
    (directory / "summary.json").write_text(json.dumps(report, indent=2))
    print("Staging native smoke passed" if report["ok"] else "Staging native smoke failed; see redacted release evidence")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
