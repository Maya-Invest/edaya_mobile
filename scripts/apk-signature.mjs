export function verifyApkIdentity(app, expectedFingerprint, verification, applicationId, badging) {
  const actualFingerprint = verification.match(/Signer #1 certificate SHA-256 digest: ([a-f0-9]+)/i)?.[1]?.toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(expectedFingerprint) || actualFingerprint !== expectedFingerprint) throw new Error(`${app} APK does not match the existing signing certificate`);
  const actualId = badging.match(/package: name='([^']+)'/)?.[1];
  if (actualId !== applicationId) throw new Error(`${app} APK application ID changed`);
}
