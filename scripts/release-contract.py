#!/usr/bin/env python3
"""Content-addressed release contract. --write is run from the backend after code generation."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = 'release-contract.json'
ROLES = {'backend': 'edaya_backend', 'web': 'edaya_frontend', 'mobile': 'edaya_mobile'}
TS_FILES = ['openapi.json', 'schema.d.ts', 'generated/client-bindings.ts', 'generated/create-client.ts']
ARTIFACTS = {
    'backend': ['package/api-client/src/' + p for p in TS_FILES] + ['tooling/repo/fixtures/openapi.json'],
    'web': ['apps/webapp/node_modules/@maya-invest/edaya-api-client/src/' + p for p in TS_FILES],
    'mobile': ['packages/edaya_api_client/spec/client-bindings.json', 'packages/edaya_api_client/lib/src/generated/client_bindings.dart', 'packages/edaya_api_client/lib/src/generated/school_client_surface.dart'],
}


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def artifact_hash(path):
    return digest(canonical(json.loads(path.read_text()))) if path.suffix == '.json' else digest(path.read_bytes())


def source_fingerprint(root):
    files = sorted([*root.glob('apps/api/src/**/*'), *root.glob('package/*/src/**/*'), *root.glob('package/adaptor-postgres/drizzle/*.sql')])
    return digest(canonical({str(p.relative_to(root)): digest(p.read_bytes()) for p in files if p.is_file() and '.test.' not in p.name}))


def write():
    roots = {role: ROOT.parent / name for role, name in ROLES.items()}
    assert ROOT == roots['backend'], '--write must run from the backend checkout'
    backend = json.loads((ROOT / 'tooling/repo/fixtures/openapi.json').read_text())
    ts = (ROOT / 'package/api-client/src/generated/client-bindings.ts').read_text()
    bindings = json.loads(ts[ts.index('{'):ts.rindex('}') + 1])
    mobile = json.loads((roots['mobile'] / ARTIFACTS['mobile'][0]).read_text())
    if bindings != mobile:
        raise SystemExit('Mobile binding specification differs from backend; regenerate Dart from the tracked backend OpenAPI.')
    manifest = {'formatVersion': 1, 'schemaFingerprint': digest(canonical(backend)), 'backendSourceRevision': 'sha256:' + source_fingerprint(ROOT), 'artifacts': {role: {path: artifact_hash(root / path) for path in ARTIFACTS[role]} for role, root in roots.items()}}
    for path in TS_FILES:
        if manifest['artifacts']['backend']['package/api-client/src/' + path] != manifest['artifacts']['web']['apps/webapp/node_modules/@maya-invest/edaya-api-client/src/' + path]:
            raise SystemExit('Refresh the web installed API client: ' + path)
    manifest['releaseId'] = digest(canonical(manifest))
    for role, root in roots.items():
        (root / MANIFEST).write_text(json.dumps(manifest, indent=2) + '\n')
        if role != 'backend':
            (root / 'scripts/release-contract.py').write_text(Path(__file__).read_text())
    print('Pinned backend source and all client artifacts to release ' + manifest['releaseId'])


def check(role):
    manifest = json.loads((ROOT / MANIFEST).read_text())
    failures = []
    for path, expected in manifest['artifacts'][role].items():
        file = ROOT / path
        if not file.exists() or artifact_hash(file) != expected:
            failures.append(str(file))
    if role == 'backend' and 'sha256:' + source_fingerprint(ROOT) != manifest['backendSourceRevision']:
        failures.append('backend source revision changed; regenerate and repin after verification')
    for sibling in ROLES.values():
        other = ROOT.parent / sibling / MANIFEST
        if other.exists() and json.loads(other.read_text()) != manifest:
            failures.append(str(other))
    if failures:
        raise SystemExit('Release contract drift:\n  ' + '\n  '.join(failures))
    print('Release contract matches: ' + manifest['releaseId'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--role', choices=ROLES)
    args = parser.parse_args()
    if args.write:
        write()
    elif args.role:
        check(args.role)
    else:
        parser.error('Choose --write or --role backend|web|mobile')
