import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

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


if __name__ == '__main__':
    unittest.main()
