# Apple push notifications

Guardian v2 and Teacher v2 use Firebase Cloud Messaging (FCM), which delivers iOS notifications through Apple Push Notification service (APNs).

| App | iOS bundle ID | Apple team | Firebase iOS app ID |
| --- | --- | --- | --- |
| `apps/guardian` | `ca.maya-invest.edaya.guardian` | `SQFU4GGCX2` (Maya Investissement Group Inc.) | `1:839288643279:ios:041e327d9cdaafbeea61ba` |
| `apps/teacher` | `ca.maya-invest.edaya.teacher` | `SQFU4GGCX2` (Maya Investissement Group Inc.) | `1:839288643279:ios:7c5afb285dbf11b9ea61ba` |

Both apps use Firebase project `edayaplus` and the enrolled Apple team **Maya Investissement Group Inc.** (`SQFU4GGCX2`). Each v2 app has a separate iOS identity and Firebase registration from its original app.

Both apps' Debug, Profile and Release configurations use `SQFU4GGCX2`. Xcode Run uses Debug: changing only Profile leaves normal launches signed by the previous team. A changed iOS bundle ID also requires a new Firebase iOS app registration; changing `BUNDLE_ID` in an old plist does not change that registration.

## App configuration

Both Runner targets enable Push Notifications and Background Modes, with `fetch` and `remote-notification` in `Info.plist`. All three build configurations (Debug, Profile and Release) sign with `Runner/Runner.entitlements`. Guardian's existing associated domains remain in that file.

The source entitlement uses `aps-environment = development` for development signing. Xcode's distribution export derives the final APNs environment from the distribution provisioning profile; inspect the exported app for `production` when validating a TestFlight/App Store build. Do not select an APNs environment based only on Flutter's debug/release mode.

Each `AppDelegate` assigns the notification center delegate for local notification presentation and taps. Firebase method swizzling remains enabled. The existing shared FCM service requests notification permission, registers the FCM token with the authenticated school API, listens for token refreshes, and routes notification taps. The apps already register their background message handlers in `main.dart`.

## Apple and Firebase setup

These account settings are required in addition to the source configuration:

1. In [Apple Developer Identifiers](https://developer.apple.com/account/resources/identifiers/list), select **Maya Investissement Group Inc.** (`SQFU4GGCX2`) and check that **Push Notifications** is enabled for both bundle IDs above. Xcode automatic signing registers these capabilities when creating the apps' development profiles. Refresh any manually managed distribution profiles after changing capabilities.
2. In [Apple Developer Keys](https://developer.apple.com/account/resources/authkeys/list), create an APNs key in the app's signing team using an Account Holder or Admin account. Configure the environment(s) required for development and distribution, and ensure its scope includes the app's bundle ID. If using topic-specific, environment-specific keys, configure the corresponding development and production keys. Follow [Apple's key creation instructions](https://developer.apple.com/help/account/keys/create-a-private-key/).
3. Download each `.p8` key once and retain its Key ID. Store private keys outside the repository and app bundles.
4. Open [Firebase project settings → Cloud Messaging](https://console.firebase.google.com/project/edayaplus/settings/cloudmessaging). Under **Edaya Guardian v2 (Maya Invest)** and **Edaya Teacher v2 (Maya Invest)**, upload the matching APNs authentication key(s), enter each Key ID and team ID `SQFU4GGCX2`, and save. Select the exact apps in the table, not the original Guardian/Teacher registrations. Configure both development (Sandbox) and production coverage, matching the Firebase slots to the key's environment. Keys can be reused for both apps when their scope covers both bundle IDs under this team.
5. Rebuild and install a signed app on a physical iPhone or iPad. Accept notification permission and sign in to the intended school/profile so its FCM token is registered.

Firebase's [Flutter setup guide](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) documents capabilities, APNs key upload and the APNs-token prerequisite for FCM registration.

## Validation

From each app directory, an unsigned compile checks native integration:

```sh
flutter build ios --debug --no-codesign --no-pub
```

An unsigned build or a simulated notification does not verify APNs credentials or delivery. After account setup, use a dedicated test installation and its FCM registration token to send a Firebase test notification. Check arrival while foregrounded, backgrounded, and after a normal cold start; verify the expected screen opens on a notification tap. Do not send test notifications to user audiences.

Check a development-signed install and a distribution-signed install separately. Inspect the final signed app's entitlement when diagnosing environment mismatches:

```sh
codesign -d --entitlements - /path/to/Runner.app
```

If delivery fails, verify notification permission, both bundle IDs, the Firebase APNs key environment/scope, the selected Apple team and provisioning profile, and that the authenticated device registration succeeded. Never log private keys or device registration tokens in shared diagnostics.
