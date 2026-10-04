"""Read-only CI candidate checks and credential-free evidence; standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
SHA = re.compile(r'[a-f0-9]{40}')


def resolve_backend(explicit, head, base, token, lookup):
    if not token:
        raise ValueError('IDENTITY_CHECKOUT_TOKEN: missing private backend checkout access')
    candidates = [explicit] if explicit else list(dict.fromkeys(ref for ref in (head, base) if ref))
    for ref in candidates:
        try:
            sha = lookup(ref, token)
        except urllib.error.HTTPError as error:
            if error.code == 404 and not explicit:
                continue
            raise ValueError('Backend reference inaccessible; check backend_ref and checkout access') from None
        if not isinstance(sha, str) or not SHA.fullmatch(sha):
            raise ValueError('Backend lookup returned an invalid immutable commit')
        return sha
    raise ValueError('No matching backend reference; supply backend_ref or create the matching branch')


def github_lookup(ref, token):
    owner = os.environ.get('GITHUB_REPOSITORY_OWNER', 'Maya-Invest')
    url = f'https://api.github.com/repos/{urllib.parse.quote(owner, safe="")}/edaya_backend/commits/{urllib.parse.quote(ref, safe="")}'
    request = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)['sha']


def assert_contract(consumer, backend, sha):
    if not SHA.fullmatch(sha or ''):
        raise ValueError('Expected a pinned backend SHA')
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=backend, text=True).strip()
    if actual != sha:
        raise ValueError('Backend checkout differs from the resolved candidate')
    backend_manifest = json.loads((backend / 'release-contract.json').read_text())
    if json.loads((consumer / 'release-contract.json').read_text()) != backend_manifest:
        raise ValueError('Consumer/backend release contracts differ; refresh the committed client contract')
    # This verifies generated artifacts and the content-addressed backend source,
    # rather than trusting two matching manifest files alone.
    subprocess.run(['python3', str(backend / 'scripts/release-contract.py'), '--role', 'backend'], check=True)


def require_success(results):
    if not results or any(value != 'success' for value in results.values()):
        raise ValueError('Full validation incomplete: ' + ', '.join(f'{name}={value}' for name, value in results.items()))


def safe_counts(summary):
    """Never copy free text, arbitrary keys, fixtures, tokens or test names."""
    counts = {}
    for key in ('passed', 'failed', 'total'):
        value = summary.get(key)
        if type(value) is int and value >= 0:
            counts[key] = value
    return counts


def web_counts(summary, name):
    if name == 'provisioned':
        return safe_counts(summary.get('matrix', {}))
    if name == 'demo':
        counts = safe_counts(summary)
        counts['total'] = len(summary.get('results', []))
        return counts
    rows = summary.get('scenes' if name == 'onboarding' else 'outcomes', [])
    if not rows:
        return safe_counts(summary)
    passed = sum(row.get('status') == 'passed' for row in rows)
    return {'total': len(rows), 'passed': passed, 'failed': len(rows) - passed}


def collect_evidence(root, role, backend_sha):
    if backend_sha and not SHA.fullmatch(backend_sha):
        raise ValueError('Evidence backend SHA is invalid')
    suites = {}
    if role == 'web':
        sources = {name: root / 'apps/webapp' / directory for name, directory in {
            'availability': '.availability-run', 'onboarding': '.onboarding-run',
            'provisioned': '.integration-run', 'webadmin': '.webadmin-run', 'demo': '.demo-dry-run',
        }.items()}
        for name, directory in sources.items():
            summary_file = directory / ('results.json' if name == 'demo' else 'summary.json')
            metadata_file = directory / 'execution.json'
            summary = json.loads(summary_file.read_text()) if summary_file.exists() else {}
            metadata = json.loads(metadata_file.read_text()) if metadata_file.exists() else {}
            counts = web_counts(summary, name)
            suites[name] = {'present': summary_file.exists(), 'completed': metadata.get('completed') is True,
                            'passed': summary.get('ok', metadata.get('completed') is True and counts.get('total', 0) > 0 and counts.get('failed') == 0) is True,
                            'counts': counts}
            fingerprint = metadata.get('fingerprint')
            if isinstance(fingerprint, str) and re.fullmatch(r'[a-f0-9]{64}', fingerprint):
                suites[name]['fingerprint'] = fingerprint
    else:
        file = root / '.integration-results/summary.json'
        summary = json.loads(file.read_text()) if file.exists() else {}
        for name in ('api', 'guardian', 'teacher'):
            if name in summary.get('suites', {}):
                row = summary['suites'][name]
                tests = row.get('tests', [])
                suites[name] = {'passed': row.get('ok') is True, 'counts': {'total': len(tests), 'passed': sum(test.get('status') == 'passed' for test in tests)}}
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    lock = root / ('pubspec.lock' if role == 'mobile' else 'bun.lock')
    return {'schemaVersion': 1, 'role': role, 'commit': revision, 'backendCommit': backend_sha or None,
            'lockSha256': hashlib.sha256(lock.read_bytes()).hexdigest(), 'suites': suites}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('resolve')
    contract = sub.add_parser('contract')
    contract.add_argument('--backend', type=Path, required=True)
    gate = sub.add_parser('gate')
    gate.add_argument('results', nargs='+', help='name=result for every required job')
    evidence = sub.add_parser('evidence')
    evidence.add_argument('--role', choices=['web', 'mobile'], required=True)
    args = parser.parse_args()
    try:
        if args.command == 'resolve':
            sha = resolve_backend(os.environ.get('BACKEND_REF', ''), os.environ.get('CANDIDATE_REF', ''), os.environ.get('BASE_REF', ''), os.environ.get('IDENTITY_CHECKOUT_TOKEN', ''), github_lookup)
            with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
                output.write(f'backend_sha={sha}\n')
            print(f'Pinned backend candidate: {sha}')
        elif args.command == 'contract':
            assert_contract(ROOT, args.backend.resolve(), os.environ.get('CI_BACKEND_SHA', ''))
        elif args.command == 'gate':
            require_success(dict(item.split('=', 1) for item in args.results))
            print('All required qualification jobs passed')
        else:
            output = ROOT / '.ci-evidence'
            output.mkdir(exist_ok=True)
            (output / 'results.json').write_text(json.dumps(collect_evidence(ROOT, args.role, os.environ.get('CI_BACKEND_SHA', '')), indent=2) + '\n')
    except ValueError as error:
        import sys
        message = 'Invalid CI JSON' if isinstance(error, json.JSONDecodeError) else str(error)
        print(message, file=sys.stderr)
        return 1
    except (OSError, subprocess.CalledProcessError, urllib.error.URLError):
        # Do not include provider diagnostics, request headers or secret values.
        import sys
        print('CI check failed: configuration, candidate, contract, results or checkout access is invalid', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
