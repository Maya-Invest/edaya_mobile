import { test } from 'node:test';
import assert from 'node:assert/strict';
import { verifyApkIdentity } from './apk-signature.mjs';
const fingerprint = 'a'.repeat(64);
const certificate = `Signer #1 certificate SHA-256 digest: ${fingerprint}`;
const badging = "package: name='com.softilab.edaya.guardian'";
test('matching current certificate and application ID pass', () => verifyApkIdentity('guardian', fingerprint, certificate, 'com.softilab.edaya.guardian', badging));
test('different or absent signing certificates reject retries', () => {
  assert.throws(() => verifyApkIdentity('guardian', 'b'.repeat(64), certificate, 'com.softilab.edaya.guardian', badging), /signing certificate/);
  assert.throws(() => verifyApkIdentity('guardian', fingerprint, '', 'com.softilab.edaya.guardian', badging), /signing certificate/);
});
test('changed application IDs reject retries', () => assert.throws(() => verifyApkIdentity('guardian', fingerprint, certificate, 'com.softilab.edaya.staff', badging), /application ID/));
