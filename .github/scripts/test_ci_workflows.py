"""Regression checks for mandatory workflow gates and artifact boundaries."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def jobs(file):
    text = file.read_text().split('\njobs:\n', 1)[1]
    matches = list(re.finditer(r'^  ([a-zA-Z0-9_-]+):\s*$', text, re.M))
    return {match[1]: text[match.start():matches[index + 1].start() if index + 1 < len(matches) else len(text)] for index, match in enumerate(matches)}


def dependencies(job):
    match = re.search(r'^    needs: \[([^]]+)\]', job, re.M)
    return set(item.strip() for item in match[1].split(',')) if match else set()


class WorkflowGates(unittest.TestCase):
    def test_full_pr_gate_requires_units_and_integration(self):
        file = ROOT / '.github/workflows/deploy_pr.yml'
        text = file.read_text()
        self.assertNotIn('run_verify:', text)
        self.assertNotIn('run_integration:', text)
        self.assertNotRegex(text, r'pull_request:\s*\n\s+branches:')
        graph = jobs(file)
        expected = {'verify', 'integration'} | ({'backend'} if 'backend' in graph else set())
        self.assertEqual(dependencies(graph['qualification']), expected)
        self.assertIn('if: always()', graph['qualification'])
        self.assertIn('ci_support.py gate', graph['qualification'])
        for name in expected:
            self.assertIn(f'{name}="$' + name.upper() + '_RESULT"', graph['qualification'])

    def test_every_publication_and_deployment_depends_on_full_validation(self):
        file = ROOT / '.github/workflows/deploy_push.yml'
        if not file.exists():
            self.assertNotRegex((ROOT / '.github/workflows/push.yml').read_text(), r'branches-ignore:')
            return
        graph = jobs(file)
        for name, job in graph.items():
            if re.search(r'uses: ./\.github/workflows/_(?:publish|deploy|migrate)', job):
                with self.subTest(job=name):
                    self.assertIn('qualification', dependencies(job))
        self.assertTrue({'verify', 'integration'}.issubset(dependencies(graph['qualification'])))

    def test_unit_jobs_do_not_require_publication_or_live_integrations(self):
        text = (ROOT / '.github/workflows/_verify.yml').read_text()
        for obsolete in ('ci-use-published-api-client', 'npm view', 'test:integration', 'IDENTITY_CHECKOUT_TOKEN'):
            self.assertNotIn(obsolete, text)
        text = (ROOT / '.github/workflows/push.yml').read_text()
        self.assertNotIn('publish', text)

    def test_external_actions_are_immutable_and_jobs_are_bounded(self):
        files = [*(ROOT / '.github/workflows').glob('*.yml'), *(ROOT / '.github/actions').glob('*/action.yml')]
        for file in files:
            with self.subTest(file=file.name):
                for action in re.findall(r'uses:\s+([^\s]+)', file.read_text()):
                    if not action.startswith('./'):
                        self.assertRegex(action, r'@[a-f0-9]{40}$')
                if 'jobs:\n' in file.read_text():
                    for job in jobs(file).values():
                        if 'runs-on:' in job:
                            self.assertIn('timeout-minutes:', job)
                            self.assertIn('runs-on: ubuntu-24.04', job)

    def test_integrations_use_one_resolved_backend_and_allowlisted_artifacts(self):
        file = ROOT / '.github/workflows/_integration.yml'
        text = file.read_text()
        if (ROOT / '.github/workflows/_backend-candidate.yml').exists():
            self.assertIn('ref: ${{ inputs.backend_sha }}', text)
            self.assertIn('CI_BACKEND_SHA: ${{ inputs.backend_sha }}', text)
            self.assertIn('persist-credentials: false', text)
            self.assertIn('ci_support.py contract', text)
            self.assertNotIn('ci_support.py resolve', text)
            self.assertIn('path: .ci-evidence/results.json', text)
            self.assertNotIn('identity-client', text)
            for raw in ('.integration-results/', '.onboarding-run/', '.integration-run/', '.webadmin-run/'):
                self.assertNotIn('path: ' + raw, text)
        else:
            self.assertLess(text.index('pg_config'), text.index('bun run test:integration:seed'))
            for suite in ('test:integration', 'test:integration:seed', 'test:integration:native'):
                self.assertEqual(len(re.findall(r'run: bun run ' + re.escape(suite) + r'\s*$', text, re.M)), 1)

    def test_staging_validation_and_early_failure_evidence_are_retained(self):
        file = ROOT / '.github/workflows/release-staging.yml'
        if file.exists():
            text = file.read_text()
            self.assertLess(text.index('actions/setup-node@'), text.index('--configuration-only'))
            self.assertIn("if: always() && steps.candidate.outcome == 'success'", text)
            self.assertNotRegex(text, r'path: release/\s*\n')
            self.assertIn('release/preflight.json', text)
            self.assertGreaterEqual(text.count('if: ${{ !inputs.validate_only }}'), 2)
