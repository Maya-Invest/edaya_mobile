#!/usr/bin/env python3
"""Run every live suite and judge success from machine events, not exit code alone."""
import argparse
import hashlib
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITES = {
    "api": ("tooling/integration_tests", ["dart", "-DTEST_OTP_ACCESS=true", "test", "--tags", "integration", "--reporter", "json"]),
    "guardian": ("apps/guardian", ["flutter", "test", "test/integration", "--tags", "integration", "--concurrency=1", "--dart-define=TEST_OTP_ACCESS=true", "--machine"]),
    "teacher": ("apps/teacher", ["flutter", "test", "test/integration", "--tags", "integration", "--concurrency=1", "--dart-define=TEST_OTP_ACCESS=true", "--machine"]),
}


def source_fingerprint():
    digest = hashlib.sha256()
    paths = [ROOT / 'scripts/integration-runner.py', ROOT / 'tooling/integration_tests/features.json', ROOT / 'tooling/integration_tests/scenarios.json']
    for parent in ('apps', 'packages', 'tooling'):
        for package in (ROOT / parent).iterdir():
            if package.is_dir():
                for directory in ('lib', 'test'):
                    paths.extend((package / directory).rglob('*.dart'))
                paths.extend(package.glob('pubspec.yaml'))
    for path in sorted(set(paths)):
        digest.update(str(path.relative_to(ROOT)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def validate_freshness(metadata, fingerprint):
    return [] if metadata.get('completed') and metadata.get('fingerprint') == fingerprint else ['missing, incomplete, or stale execution metadata; rerun the suite']


def redact(value):
    value = re.sub(r"(?<![0-9])[0-9]{6}(?![0-9])", "[REDACTED]", value)
    value = re.sub(r"(?i)Bearer\s+[^\s\"']+", "Bearer [REDACTED]", value)
    value = re.sub(r"/invite/(?!:token(?:[\s/?\"']|$))[^\s/?\"']+", "/invite/[REDACTED]", value)
    return re.sub(r'(?i)(\b(?:authorization|cookie|token|secret|password|otp|code|recoveryCode)\b[\"\s]*[:=]\s*[\"\']?)[^\s\"\',}]+', r'\1[REDACTED]', value)


def redact_event(line):
    try:
        event = json.loads(line)
    except ValueError:
        return redact(line)
    def visit(value):
        if isinstance(value, str):
            return redact(value)
        if isinstance(value, dict):
            return {key: visit(item) for key, item in value.items()}
        if isinstance(value, list):
            return [visit(item) for item in value]
        return value
    return json.dumps(visit(event)) + '\n'


def validate_registry(registry):
    if set(registry) != set(SUITES):
        raise ValueError('The scenario registry must declare all integration suites')
    ids = [scenario for scenarios in registry.values() for scenario in scenarios]
    if any(not scenarios for scenarios in registry.values()) or len(ids) != len(set(ids)):
        raise ValueError('Empty suite or duplicate scenario IDs')
    if any(not re.fullmatch(r'[a-z0-9][a-z0-9.-]+', scenario) for scenario in ids):
        raise ValueError('Invalid scenario ID')


def evaluate(lines, exit_code, required=None):
    tests, outcomes, errors, completions = {}, {}, [], []
    for line in lines:
        try:
            event = json.loads(line)
        except (ValueError, TypeError):
            continue  # Flutter also emits build progress on stdout.
        if not isinstance(event, dict):
            continue
        kind = event.get("type")
        if kind == "testStart":
            test = event["test"]
            # package:test reports synthetic suite loading and lifecycle tests.
            if test.get("line") is not None and not re.search(r"\((?:setUpAll|tearDownAll)\)$", test["name"]):
                tests[test["id"]] = test["name"]
        elif kind == "testDone":
            outcomes[event["testID"]] = event
        elif kind == "error":
            errors.append(redact(str(event.get("error", "test error"))))
        elif kind == "done":
            completions.append(event.get("success") is True)
    scenarios = []
    for test_id, name in tests.items():
        outcome = outcomes.get(test_id, {})
        status = ("skipped" if outcome.get("skipped") else
                  "passed" if outcome.get("result") == "success" else
                  "blocked" if not outcome else "failed")
        match = re.search(r'\[([a-z0-9][a-z0-9.-]+)\]', name)
        scenarios.append({"id": match[1] if match else None, "name": name, "status": status})
    ids = [row['id'] for row in scenarios]
    missing = [name for name in required or () if name not in ids]
    problems = []
    if exit_code != 0:
        problems.append(f"child process exited {exit_code}")
    if not tests:
        problems.append("zero executable tests discovered")
    if not completions or not all(completions):
        problems.append("missing or unsuccessful runner completion")
    if any(row["status"] != "passed" for row in scenarios):
        problems.append("failed, blocked, or skipped tests")
    if errors:
        problems.append("runner reported errors")
    if missing:
        problems.append(f"missing required scenarios: {', '.join(missing)}")
    if required is not None:
        if any(scenario not in required for scenario in ids):
            problems.append('unregistered executable scenarios')
        if len(ids) != len(set(ids)):
            problems.append('duplicate executed scenario IDs')
    return {"ok": not problems, "tests": scenarios, "problems": problems, "errors": errors}


def validate_feature_contract(contract, registered, routes):
    """Every router path and explicit non-route action must name executable scenarios."""
    problems, ids, paths = [], [], []
    for feature in contract['features']:
        ids.append(feature['id'])
        paths.extend(feature['routes'])
        if not feature['actions']:
            problems.append(f"feature has no actions: {feature['id']}")
        for action in feature['actions']:
            ids.append(action['id'])
            if not action['scenarios']:
                problems.append(f"action has no scenarios: {action['id']}")
            for scenario in action['scenarios']:
                if scenario not in registered:
                    problems.append(f"removed or unregistered scenario: {scenario}")
    if len(ids) != len(set(ids)):
        problems.append('duplicate feature/action IDs')
    if len(paths) != len(set(paths)):
        problems.append('duplicate registered routes')
    if routes is None:
        problems.append('missing executed GoRouter inventory')
    else:
        problems.extend(f"unmapped current route: {route}" for route in sorted(set(routes) - set(paths)))
        problems.extend(f"removed route still registered: {route}" for route in sorted(set(paths) - set(routes)))
    return problems


def read_route_inventory(lines):
    inventories = []
    for line in lines:
        try:
            event = json.loads(line)
            message = event.get('message', '')
            if event.get('type') == 'print' and message.startswith('EDAYA_ROUTE_INVENTORY:'):
                inventories.append(json.loads(message.removeprefix('EDAYA_ROUTE_INVENTORY:')))
        except (ValueError, TypeError, AttributeError):
            continue
    return inventories[0] if len(inventories) == 1 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=list(SUITES), action="append")
    parser.add_argument("--results", type=Path, default=ROOT / ".integration-results")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    registry = json.loads((ROOT / 'tooling/integration_tests/scenarios.json').read_text())
    validate_registry(registry)
    features = json.loads((ROOT / 'tooling/integration_tests/features.json').read_text())
    args.results.mkdir(parents=True, exist_ok=True)
    summaries = {}
    for name in args.suite or SUITES:
        cwd, command = SUITES[name]
        log = args.results / f"{name}.jsonl"
        exit_file = args.results / f"{name}.exit.json"
        metadata_file = args.results / f"{name}.run.json"
        if not args.validate_only:
            fingerprint = source_fingerprint()
            metadata = {'fingerprint': fingerprint, 'startedAt': datetime.now(timezone.utc).isoformat(), 'completed': False}
            metadata_file.write_text(json.dumps(metadata))
            print(f"Running {name} integration suite", flush=True)
            try:
                with log.open("w") as output:
                    process = subprocess.Popen(command, cwd=ROOT / cwd, env={**os.environ, "EDAYA_INTEGRATION_TESTS": "1", "EDAYA_INTEGRATION_ARTIFACTS": str((args.results / name / 'failures').resolve())}, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                    for line in process.stdout:
                        output.write(redact_event(line))
                        output.flush()
                    exit_code = process.wait()
            except OSError as error:
                log.write_text(json.dumps({"type": "error", "error": str(error)}) + "\n")
                exit_code = 127
            exit_file.write_text(json.dumps(exit_code))
            metadata.update(completed=True, completedAt=datetime.now(timezone.utc).isoformat())
            metadata_file.write_text(json.dumps(metadata))
        if not log.exists() or not exit_file.exists():
            summaries[name] = {"ok": False, "problems": ["missing suite artifacts"], "tests": []}
        else:
            summaries[name] = evaluate(log.read_text().splitlines(), json.loads(exit_file.read_text()), registry[name])
        metadata = json.loads(metadata_file.read_text()) if metadata_file.exists() else {}
        freshness = validate_freshness(metadata, source_fingerprint())
        summaries[name]['problems'].extend(freshness)
        summaries[name]['ok'] = summaries[name]['ok'] and not freshness
        if name in features:
            lines = log.read_text().splitlines() if log.exists() else []
            problems = validate_feature_contract(features[name], registry[name], read_route_inventory(lines))
            summaries[name]['problems'].extend(problems)
            summaries[name]['ok'] = summaries[name]['ok'] and not problems
            passed = {row['id'] for row in summaries[name]['tests'] if row['status'] == 'passed'}
            summaries[name]['features'] = [
                {'id': feature['id'], 'covered': all(scenario in passed for action in feature['actions'] for scenario in action['scenarios'])}
                for feature in features[name]['features']
            ]
            summaries[name]['limits'] = features[name].get('limits', [])
        print(f"{name}: {'PASS' if summaries[name]['ok'] else 'FAIL'} ({len(summaries[name]['tests'])} tests)", flush=True)
    result = {"ok": all(row["ok"] for row in summaries.values()), "suites": summaries}
    (args.results / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
