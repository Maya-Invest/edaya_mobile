import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess

spec = importlib.util.spec_from_file_location('staging_smoke', Path(__file__).with_name('staging-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class StagingSmokePreflightTests(unittest.TestCase):
    def test_missing_fixture_sessions_and_wrong_targets_block(self):
        errors = smoke.preflight({})
        self.assertEqual(len(errors), 2)
        self.assertTrue(any('SEED_AUTH_SESSIONS_FILE' in error for error in errors))

    def test_private_sessions_and_no_otp_capture_required(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'sessions.json'
            file.write_text(json.dumps({email: 'private-session' for email in ['a.toure@ecole-ci.edaya.dev', 'k.diomande@ecole-ci.edaya.dev', 'm.kone@mail.ci', 'k.yao@mail.ci']}))
            os.chmod(file, 0o600)
            env = {'EDAYA_API_URL': 'https://staging.api.edayaplus.com', 'SEED_AUTH_SESSIONS_FILE': str(file)}
            self.assertEqual(smoke.preflight(env), [])
            self.assertTrue(smoke.preflight({**env, 'TEST_OTP_ACCESS': 'true'}))
            self.assertTrue(smoke.preflight({**env, 'EDAYA_TEST_CLOCK_FILE': '/fixture'}))
            os.chmod(file, 0o644)
            self.assertTrue(smoke.preflight(env))

    def test_smoke_has_six_registered_cases_and_no_local_suite_invocation(self):
        self.assertEqual(len(smoke.REQUIRED), 6)
        self.assertEqual(len(set(smoke.REQUIRED)), 6)

    def events(self, ids, skipped=False, result="success"):
        events = []
        for index, scenario in enumerate(ids):
            events.extend([
                {"type": "testStart", "test": {"id": index, "name": f"[{scenario}] smoke", "line": 1}},
                {"type": "testDone", "testID": index, "result": result, "skipped": skipped},
            ])
        events.append({"type": "done", "success": True})
        return [json.dumps(event) for event in events]

    def test_all_six_cases_must_pass_exactly_once(self):
        evaluate = smoke.load_runner().evaluate
        self.assertTrue(evaluate(self.events(smoke.REQUIRED), 0, smoke.REQUIRED)['ok'])
        for events in [self.events(smoke.REQUIRED[:-1]), self.events(smoke.REQUIRED + [smoke.REQUIRED[0]]), self.events(smoke.REQUIRED, skipped=True), self.events(smoke.REQUIRED, result='failure')]:
            self.assertFalse(evaluate(events, 0, smoke.REQUIRED)['ok'])

    def test_validation_compiles_runner_without_sessions_and_cannot_claim_live_smoke(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {'RELEASE_ROOT': directory}), patch('sys.argv', ['staging-smoke.py', '--validate-runner']), patch.object(smoke.subprocess, 'run') as run:
                run.return_value = subprocess.CompletedProcess([], 0, stdout='\n'.join(self.events(smoke.REQUIRED)))
                self.assertEqual(smoke.main(), 0)
                self.assertEqual(run.call_args.kwargs['env']['EDAYA_STAGING_VALIDATE_ONLY'], 'true')
                self.assertIn('test/staging', run.call_args.args[0])
                self.assertFalse((Path(directory) / 'release/mobile-staging-smoke').exists())
                self.assertEqual(json.loads((Path(directory) / 'release/mobile-staging-runner/summary.json').read_text())['mode'], 'runner-validation')


if __name__ == '__main__':
    unittest.main()
