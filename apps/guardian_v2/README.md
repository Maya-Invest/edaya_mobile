# Guardian v2

Child-first family workspace aligned with Teacher v2. See [the normative workspace specification](../../docs/specs/guardian-v2-workspace-spec.md).

Run from this directory with `flutter run --dart-define=API_URL=http://127.0.0.1:19998`. The API must include `get-guardian-period-results`; regenerate the workspace API client after backend changes. Android uses `ca.mayainvest.edaya.guardian`, shares Guardian’s app identity, and replaces its installed build. Android package names cannot contain hyphens. iOS uses `ca.maya-invest.edaya.guardian` under Maya Investissement Group Inc. (`SQFU4GGCX2`), with its own Firebase iOS registration.

Run `flutter test test --exclude-tags integration` for controller and layout checks. Run the registered `guardian_v2` integration suite against an isolated seeded backend. The layout matrix covers Home/results/subject navigation in FR/EN, light/dark, phone/tablet and 100%/200% text.

## Apple push notifications

The iOS target includes the push entitlement and background modes. Complete the [Apple/Firebase account setup and device validation](../../docs/reference/apple-push-notifications.md) to enable delivery.
