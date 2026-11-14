# Google Play releases

The current release targets are Guardian v2 (`ca.mayainvest.edaya.guardian`) and Teacher v2 (`ca.mayainvest.edaya.staff`), built from `apps/guardian_v2` and `apps/teacher_v2`. The existing store identities, signing aliases, and logical artifact names `guardian`/`teacher` are preserved. The original app workspaces are not published.

## Release flow

1. Push to `main`, or manually run **Deploy production** for a revision containing this release tooling. The existing qualification job must succeed. Its signed production AABs use `https://api.edayaplus.com`.
2. The deployment job verifies both artifact hashes, uploads both bundles, and releases them to the Google Play `internal` track. Version codes appear in the job summary, `.release/manifest.json`, and `.release/play-internal.json` in the release artifact.
3. Test both apps using their Play Console internal-testing opt-in links.
4. In GitHub Actions, run **Promote Google Play to production** on `main`. Enter `guardian_version_code` and `teacher_version_code` from the tested release. Both fields are required; they may differ if the apps have different tested versions.
5. Approve the `google-play-production` environment if reviewers are configured. Promotion checks both apps before writing, requires each selected version to be a completed internal release, rejects a newer existing production version, and promotes exactly those bundles. It does not build, sign, or upload another bundle.

Promotion requests a completed production release (100% rollout). Google review and any Play Console managed-publishing settings still determine public availability. The workflow does not edit listings, policy declarations, tester lists, or countries. A later internal release replaces the earlier internal track release: promote the tested version before publishing its replacement, or test and select the replacement.

## GitHub credentials

Create these **environment secrets** under repository Settings → Environments:

| Environment | Secret | Value |
| --- | --- | --- |
| `production` | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Complete JSON key for the internal publisher service account |
| `google-play-production` | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Complete JSON key for the production promoter service account |
| `production` | `ANDROID_SIGNING_BUNDLE` | Existing Android upload keystore, passwords, and Firebase configuration bundle |

Use separate service accounts so the automatic publisher has no production release permission. Keep their JSON keys in environment secrets, not repository files or artifacts. The Google auth action creates a short-lived Android Publisher access token in memory; no credential file is written. Restrict `google-play-production` to the `main` branch and configure required reviewers if your GitHub plan supports them. The workflow itself only runs its promotion job on `main` and only has a manual trigger.

The existing `IDENTITY_CHECKOUT_TOKEN` repository secret is still required for qualification: read-only contents access to `Maya-Invest/edaya_backend`. GitHub provides `GITHUB_TOKEN` automatically. Promotion does not require the Android signing secret or the backend token.

### Create the Google service accounts

1. In a Google Cloud project, enable **Google Play Android Developer API** (`androidpublisher.googleapis.com`) and **IAM Service Account Credentials API** (`iamcredentials.googleapis.com`). Create an internal publisher service account and a production promoter service account.
2. For each account, grant that account **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) on **itself**, as required by the Google authentication action's JSON-key access-token flow. No project-wide Owner/Editor role is needed.
3. Create a JSON key for each account. Store the complete JSON, preferably minified, under the corresponding environment secret above.
4. In Play Console → Users and permissions, add each service account's `client_email`. Grant app access to **both** package IDs above and **View app information (read-only)**.
5. Grant the internal account **Release apps to testing tracks**. Grant the production account **Release to production, exclude devices, and use Play App Signing**. Its read access allows it to verify the internal track. Admin, financial, and tester-list management permissions are not needed by these workflows.

References: [Google Play API setup](https://developers.google.com/android-publisher/getting_started), [Play Console permissions](https://support.google.com/googleplay/android-developer/answer/9844686), [Google authentication action](https://github.com/google-github-actions/auth#service-account-key-json).

### Existing signing bundle format

`ANDROID_SIGNING_BUNDLE` is one JSON object, not base64 of the entire object. Only `keystore` is base64. Use the existing upload keys registered for each app in Play Console; do not replace them to configure CI.

```json
{
  "keystore": "BASE64_OF_EXISTING_EDAYA_UPLOAD_JKS",
  "apps": {
    "guardian": {
      "keyAlias": "guardian",
      "keyPassword": "EXISTING_KEY_PASSWORD",
      "storePassword": "EXISTING_STORE_PASSWORD",
      "firebase": { "client": ["REPLACE_WITH_FULL_GUARDIAN_GOOGLE_SERVICES_JSON_CLIENTS"] }
    },
    "teacher": {
      "keyAlias": "teacher",
      "keyPassword": "EXISTING_KEY_PASSWORD",
      "storePassword": "EXISTING_STORE_PASSWORD",
      "firebase": { "client": ["REPLACE_WITH_FULL_TEACHER_GOOGLE_SERVICES_JSON_CLIENTS"] }
    }
  }
}
```

Replace each entire `firebase` object with that app's complete `google-services.json` object. The example placeholders are not valid signing configuration. Keep actual alias names if they differ from the example. Guardian's Android client must use `ca.mayainvest.edaya.guardian`; its separate iOS bundle ID is not an Android package name. If an existing signing secret contains the old hyphenated Android ID, update its Firebase client data before running CI. Checked-in Firebase files are preserved and must match the Firebase Android registration in the signing bundle; only files created by CI are removed during cleanup.

## First release and version codes

Before enabling automatic uploads, create both Play Console apps, enroll them in Play App Signing, upload an initial signed AAB manually, and finish the setup needed to roll out an internal-testing release. Configure internal testers and share the opt-in links. Draft-only apps cannot accept the workflow's completed releases. Complete the store listing, data safety and other Play requirements before production promotion; any Google account-specific production-access requirements still apply.

CI assigns both apps a version code using:

```text
PLAY_VERSION_CODE_BASE + GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT
```

`PLAY_VERSION_CODE_BASE` is an optional GitHub variable in the `production` environment, defaulting to `1000000`. Before the first run, ensure the resulting code exceeds **every code already uploaded for either app**. Increase the base if needed and do not lower it later. Codes above `2100000000`, invalid bases, and attempts outside 1–99 fail the build. Normal reruns get a new code. An older run retried after a newer release is rejected if it would move the internal track backwards. Local builds retain their pubspec version codes. The base need not be a secret.

## Recovery and evidence

Internal publishing and manual promotion share a GitHub concurrency group so they cannot modify Play tracks simultaneously. GitHub may replace older pending jobs in that group; it does not cancel the active release. Avoid overlapping manual edits in Play Console while a release runs.

Google Play has no transaction spanning both apps. A network or API failure may leave Guardian committed and Teacher unfinished. Each successful app is recorded immediately in the job summary and the release/promotion evidence artifact. A failed workflow is not evidence that neither app was released; inspect Play Console if a commit response was lost.

- For a failed **internal release**, fix the reported configuration/API issue and rerun **all jobs** of Deploy production so qualification and release share the same run attempt. This builds a new version code for both apps. Test the resulting pair before promotion. Reusing an already uploaded version is allowed by the publisher only when the AAB SHA-256 matches exactly.
- For a failed **production promotion**, rerun with the same two version codes. An app already completed on production is skipped; the remaining app is promoted after validation. If a newer production release exists, stop and select the appropriate tested versions; the tool will not downgrade it.
- HTTP errors stop the workflow; no production fallback or automatic relaxation of Play review rules is performed. Check Play Console publishing status, API enablement, permissions and initial app setup. Production promotion evidence is `play-promotion-<run_id>-<attempt>`; internal evidence is included in `release-production-<run_id>-<attempt>`.

Repository tooling commands are `dart run edaya_repo:play internal` and `dart run edaya_repo:play promote`. They require a short-lived `PLAY_ACCESS_TOKEN`; promotion also requires `PLAY_GUARDIAN_VERSION` and `PLAY_TEACHER_VERSION`. These commands perform real store mutations. Tests use an in-memory API and never publish.
