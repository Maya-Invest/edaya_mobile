# Google Play releases

The current release targets are Guardian v2 (`ca.mayainvest.edaya.guardian`) and Teacher v2 (`ca.mayainvest.edaya.teacher`), built from `apps/guardian` and `apps/teacher`. Both keep their existing upload keys. Google Play treats the renamed Teacher package as a new app: complete the first-release setup for this package and grant the publishing service accounts access to its listing. Users of the previous package cannot receive it as an update.

## Release flow

| Branch | Compiled API | Destination |
| --- | --- | --- |
| `staging` | `https://staging.api.edayaplus.com` | Google Play internal testing, plus both signed APKs in GitHub |
| `main` | `https://api.edayaplus.com` | Google Play production track, sent for review |

**Deploy testing** and **Deploy live** each qualify the pushed commit and build fresh signed bundles for both apps. Guardian and Teacher stage their Play edits in parallel. Each publishing job commits its own verified edit after both preparations pass. After testing staging, merge the intended source into `main` to start production qualification. Each commit requests a completed release. Enable managed publishing for eligible apps in Play Console to hold an approved update for manual publication. Google controls first-release eligibility. [Google Play publishing controls](https://support.google.com/googleplay/android-developer/answer/9859654)

## GitHub credentials

Set `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` to the complete service-account key. If using one repository secret, grant that account testing and production release access to both apps. With environment secrets, set the same name in `staging` for a testing publisher and in `production` for a production publisher. Restrict the production environment to `main` where available. Both environments also use the existing `ANDROID_SIGNING_BUNDLE` and qualification uses `BACKEND_CHECKOUT_TOKEN` for read access to the backend.

### Create the Google service accounts

1. In a Google Cloud project, enable **Google Play Android Developer API** (`androidpublisher.googleapis.com`) and **IAM Service Account Credentials API** (`iamcredentials.googleapis.com`). Create an internal publisher service account and a production promoter service account.
2. For each account, grant that account **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) on **itself**, as required by the Google authentication action's JSON-key access-token flow. No project-wide Owner/Editor role is needed.
3. Create a JSON key for each account. Store the complete JSON, preferably minified, under the corresponding environment secret above.
4. In Play Console → Users and permissions, add each service account's `client_email`. Grant app access to **both** package IDs above and **View app information (read-only)**.
5. Grant the internal account **Release apps to testing tracks**. Grant the production account **Release to production, exclude devices, and use Play App Signing**. Admin, financial, and tester-list management permissions are not needed by these workflows.

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

CI assigns both apps the same version code.

```text
PLAY_VERSION_CODE_BASE + storeBuild
```

`PLAY_VERSION_CODE_BASE` is an optional repository Actions variable shared by staging and production, defaulting to `1000000`. Before the first run, ensure the resulting code exceeds **every code already uploaded for either app**. Increase the base if needed and do not lower it later. Codes above `2100000000`, invalid bases, and nonpositive build numbers fail the build. A full rerun at the branch tip gets a new code. Dispatch the current tip if the original revision has been superseded. Local builds retain their pubspec version codes. The base need not be a secret.

## Recovery and evidence

Both entry points share one release queue. Each release attempt reserves the previous `storeBuild` plus one and records it in the prepared artifact. A failed attempt keeps its reservation. Within each run, the two Play jobs can commit in parallel. Their receipts appear in the Actions summary and in `.release/<app>/play-<environment>.json`. Each manifest identifies the source commit, API URL, version code, and artifact checksums. [Build number allocation](ci-setup.md#store-build-counter)

Google commits one edit per app. If one commit fails, inspect both apps in Play Console before retrying. After resolving the cause, rerun **all jobs** on the intended branch to qualify and build both apps with a new version code. The publisher verifies any existing bundle by SHA-256 and rejects a downgrade on the target track. A production run uses its own production AABs.

The CI command is `dart run edaya_repo:play staging|production`. It requires the qualified local artifacts and a short-lived `PLAY_ACCESS_TOKEN`. Local publisher tests use an in-memory Play API.
