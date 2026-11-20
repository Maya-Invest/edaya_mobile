# Account authentication client

`AuthClient.sendOtp(value: ..., channel: 'email' | 'phone', locale: 'fr' | 'en')` starts verification. Phone delivery is selected by Identity. `primaryStatus` contains the transient challenge, channel, delivery result, lifecycle, expiry and server-adjusted cooldown. `phoneAvailable()` reads the advertised deployment availability.

Call `resendOtp()` to replace the current challenge on its current channel or `resendOtp(action: 'sms')` to switch WhatsApp to SMS after cooldown. Resends retain destination, purpose and linking identity on the server. Clear the code field after every successful replacement. `otpStatus()` observes delivery with a POST body; it never sends a message. Poll only while the verification screen is visible and the app is active.

A lost or unavailable HTTP response retains its request ID. `canRetryOtpRequest` and `retryOtpRequest()` recover that original request even when the old challenge has been superseded; they do not create another send. A deliberate successful resend uses a new request ID. Delivery failure and uncertainty retain a usable challenge. Each OTP expires after five minutes; expired pending metadata can still request replacement for an hour.

`linkIdentifier` uses the same flow and requires a recent completed session. OTP state, pending request IDs, authenticator secrets and recovery codes stay in memory. Only completed renewal credentials are persisted by application session storage. Existing verification, MFA, recovery and API-token methods retain their behavior.

Explicit test access uses `--dart-define=TEST_OTP_ACCESS=true` in debug builds only. `testingOtpAvailable()` discovers capabilities once; `revealTestOtp(challenge)` returns a transient capture without changing authentication. Normal builds return false/null without a testing request. Teacher_v2 fills an empty verification field with the pending test code and requires manual submission. Other apps use the shared Show test code/Copy controls. Captured codes stay in memory.

`LoginIdentifier.detect` classifies and normalizes a login contact as an email or an international phone number, using the service's validation rules. Invalid input returns null. Country support remains a server policy.

`AuthClient.getTerms(locale:)` loads the backend terms policy. `sendOtp(termsAcceptance:)` sends explicit acceptance of the displayed version; retries retain the original request and acceptance. Terms DTOs use generated API contracts. Loading errors must block the login UI; existing credential restoration and token renewal are unchanged.

The teacher app calls `AuthClient.teacherCode(code, acceptance)` for school-issued reusable codes. The server pins the session to the issuing teacher and school. Only the session credential is saved on the device.
