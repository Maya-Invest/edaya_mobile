import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('ci_support', Path(__file__).with_name('ci_support.py'))
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)
SHA = 'a' * 40


class CandidateTests(unittest.TestCase):
    def test_explicit_overrides_matching_and_base(self):
        seen = []
        self.assertEqual(ci.resolve_backend('exact', 'feature/x', 'main', 'private', lambda ref, token: seen.append(ref) or SHA), SHA)
        self.assertEqual(seen, ['exact'])

    def test_matching_branch_selected_once(self):
        seen = []
        self.assertEqual(ci.resolve_backend('', 'feature/x', 'main', 'private', lambda ref, token: seen.append(ref) or SHA), SHA)
        self.assertEqual(seen, ['feature/x'])

    def test_missing_branch_falls_back_to_pr_base(self):
        seen = []
        def lookup(ref, token):
            seen.append(ref)
            if ref == 'feature/x':
                raise urllib.error.HTTPError('private', 404, 'missing', {}, None)
            return SHA
        self.assertEqual(ci.resolve_backend('', 'feature/x', 'dev', 'private', lookup), SHA)
        self.assertEqual(seen, ['feature/x', 'dev'])

    def test_access_failure_never_falls_back(self):
        for status in (401, 403, 500):
            with self.subTest(status=status), self.assertRaisesRegex(ValueError, 'inaccessible'):
                ci.resolve_backend('', 'feature', 'main', 'private', lambda *_: (_ for _ in ()).throw(urllib.error.HTTPError('private', status, 'secret diagnostics', {}, None)))

    def test_explicit_missing_ref_never_falls_back(self):
        with self.assertRaises(ValueError):
            ci.resolve_backend('missing', 'head', 'main', 'private', lambda *_: (_ for _ in ()).throw(urllib.error.HTTPError('private', 404, 'missing', {}, None)))

    def test_missing_token_and_invalid_sha(self):
        with self.assertRaisesRegex(ValueError, 'IDENTITY_CHECKOUT_TOKEN'):
            ci.resolve_backend('', 'head', 'main', '', lambda *_: self.fail('lookup must not run'))
        with self.assertRaisesRegex(ValueError, 'immutable'):
            ci.resolve_backend('', 'head', 'main', 'private', lambda *_: 'moving-tag')
        with self.assertRaises(ValueError):
            ci.resolve_backend('', '', '', 'private', lambda *_: SHA)

    def test_required_gate_rejects_every_non_success(self):
        ci.require_success({'unit': 'success', 'integration': 'success'})
        for status in ('failure', 'skipped', 'cancelled', '', None):
            with self.subTest(status=status), self.assertRaises(ValueError):
                ci.require_success({'unit': 'success', 'integration': status})
        with self.assertRaises(ValueError):
            ci.require_success({})

    def test_contract_checks_checkout_manifest_and_backend_source(self):
        with tempfile.TemporaryDirectory() as folder:
            consumer, backend = Path(folder) / 'web', Path(folder) / 'backend'
            consumer.mkdir(); backend.mkdir()
            for root in (consumer, backend):
                (root / 'release-contract.json').write_text(json.dumps({'releaseId': 'matching'}))
            with patch.object(ci.subprocess, 'check_output', return_value=SHA), patch.object(ci.subprocess, 'run') as verify:
                ci.assert_contract(consumer, backend, SHA)
                verify.assert_called_once()
            with patch.object(ci.subprocess, 'check_output', return_value='b' * 40), self.assertRaisesRegex(ValueError, 'checkout'):
                ci.assert_contract(consumer, backend, SHA)
            (consumer / 'release-contract.json').write_text('{}')
            with patch.object(ci.subprocess, 'check_output', return_value=SHA), self.assertRaisesRegex(ValueError, 'contracts'):
                ci.assert_contract(consumer, backend, SHA)
            (consumer / 'release-contract.json').write_text((backend / 'release-contract.json').read_text())
            with patch.object(ci.subprocess, 'check_output', return_value=SHA), patch.object(ci.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'verify')), self.assertRaises(subprocess.CalledProcessError):
                ci.assert_contract(consumer, backend, SHA)

    def test_evidence_allowlist_excludes_private_fields_and_raw_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'bun.lock').write_text('lock')
            directory = root / 'apps/webapp/.onboarding-run'
            directory.mkdir(parents=True)
            (directory / 'summary.json').write_text(json.dumps({'passed': 3, 'failed': 0, 'token': 'private', 'password': 'private', 'scenes': [{'cookie': 'private', 'status': 'passed'}] * 3}))
            (directory / 'execution.json').write_text(json.dumps({'completed': True, 'token': 'private'}))
            (directory / 'fixture.json').write_text('private')
            with patch.object(ci.subprocess, 'check_output', return_value=SHA):
                report = ci.collect_evidence(root, 'web', SHA)
            self.assertNotIn('private', json.dumps(report))
            self.assertEqual(set(report['suites']), {'availability', 'onboarding', 'provisioned', 'webadmin', 'demo'})
            self.assertEqual(report['suites']['onboarding']['counts'], {'passed': 3, 'failed': 0, 'total': 3})
            self.assertFalse(report['suites']['availability']['present'])

    def test_web_evidence_counts_every_suite_without_free_text(self):
        fixtures = {
            'availability': {'outcomes': [{'status': 'passed', 'token': 'private'}, {'status': 'failed'}]},
            'onboarding': {'scenes': [{'status': 'passed', 'email': 'private'}]},
            'provisioned': {'matrix': {'passed': 3, 'failed': 0, 'total': 3, 'base': 'private'}},
            'webadmin': {'outcomes': [{'status': 'passed', 'id': 'private'}]},
            'demo': {'passed': 2, 'failed': 0, 'results': [{'status': 'pass'}, {'status': 'pass'}]},
        }
        expected = [(1, 1, 2), (1, 0, 1), (3, 0, 3), (1, 0, 1), (2, 0, 2)]
        for (name, summary), (passed, failed, total) in zip(fixtures.items(), expected):
            with self.subTest(name=name):
                counts = ci.web_counts(summary, name)
                self.assertEqual(counts, {'passed': passed, 'failed': failed, 'total': total})
                self.assertNotIn('private', json.dumps(counts))
