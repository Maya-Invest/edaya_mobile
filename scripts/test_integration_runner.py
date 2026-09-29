import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("runner", Path(__file__).with_name("integration-runner.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def events(self, result="success", skipped=False):
        return [json.dumps(event) for event in [
            {"type": "testStart", "test": {"id": 1, "name": "[teacher.roster.read] roster", "line": 42}},
            {"type": "testDone", "testID": 1, "result": result, "skipped": skipped},
            {"type": "done", "success": True},
        ]]

    def test_redaction_preserves_json_and_route_inventory(self):
        event = {'type': 'print', 'message': 'EDAYA_ROUTE_INVENTORY:' + json.dumps(['/invite/:token', '/login'])}
        line = runner.redact_event(json.dumps(event))
        self.assertEqual(runner.read_route_inventory([line]), ['/invite/:token', '/login'])
        safe = json.loads(runner.redact_event(json.dumps({'message': '/invite/private-credential'})))
        self.assertNotIn('private-credential', safe['message'])

    def test_rejects_stale_success_artifacts(self):
        self.assertTrue(runner.validate_freshness({'completed': True, 'fingerprint': 'old'}, 'new'))
        self.assertTrue(runner.validate_freshness({'completed': False, 'fingerprint': 'new'}, 'new'))
        self.assertEqual(runner.validate_freshness({'completed': True, 'fingerprint': 'new'}, 'new'), [])

    def test_accepts_real_success(self):
        self.assertTrue(runner.evaluate(self.events(), 0)["ok"])

    def test_rejects_failure_even_with_exit_zero(self):
        self.assertFalse(runner.evaluate(self.events(result="failure"), 0)["ok"])

    def test_rejects_skip(self):
        self.assertFalse(runner.evaluate(self.events(skipped=True), 0)["ok"])

    def test_rejects_zero_tests(self):
        self.assertFalse(runner.evaluate(['{"type":"done","success":true}'], 0)["ok"])

    def test_rejects_removed_required_scenario(self):
        self.assertFalse(runner.evaluate(self.events(), 0, ["teacher.attendance.save"])["ok"])

    def test_rejects_incomplete_run(self):
        self.assertFalse(runner.evaluate(self.events()[:-1], 0)["ok"])

    def test_rejects_fixture_error(self):
        events = self.events() + ['{"type":"error","error":"missing fixture"}']
        self.assertFalse(runner.evaluate(events, 0)["ok"])

    def test_rejects_duplicate_ids(self):
        with self.assertRaises(ValueError):
            runner.validate_registry({'api': ['same.id'], 'guardian': ['same.id'], 'teacher': ['teacher.read']})

    def test_rejects_unregistered_test(self):
        self.assertFalse(runner.evaluate(self.events(), 0, ["teacher.account.read"])["ok"])


class FeatureContractTests(unittest.TestCase):
    contract = {'features': [{'id': 'teacher.classes', 'routes': ['/classes'], 'actions': [{'id': 'teacher.classes.read', 'scenarios': ['teacher.roster.read']}]}]}

    def test_current_surface_is_mapped(self):
        self.assertEqual(runner.validate_feature_contract(self.contract, ['teacher.roster.read'], ['/classes']), [])

    def test_new_unmapped_router_path_fails(self):
        self.assertTrue(runner.validate_feature_contract(self.contract, ['teacher.roster.read'], ['/classes', '/new-feature']))

    def test_removed_scenario_fails(self):
        self.assertTrue(runner.validate_feature_contract(self.contract, [], ['/classes']))

    def test_missing_execution_inventory_fails(self):
        self.assertTrue(runner.validate_feature_contract(self.contract, ['teacher.roster.read'], None))

    def test_removed_route_fails(self):
        self.assertTrue(runner.validate_feature_contract(self.contract, ['teacher.roster.read'], []))


if __name__ == "__main__":
    unittest.main()
