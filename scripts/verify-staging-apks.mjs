import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
if (!sdk) throw new Error("Android SDK path is required for APK verification");
const buildTools = resolve(sdk, "build-tools", readdirSync(resolve(sdk, "build-tools")).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).at(-1));
const run = (command, args, env = process.env) => execFileSync(command, args, { env, encoding: "utf8" });
const records = [];
for (const [app, applicationId] of [["guardian", "com.softilab.edaya.guardian"], ["teacher", "com.softilab.edaya.staff"]]) {
  const apk = resolve(root, `release-apks/edaya-${app}-staging.apk`);
  const android = resolve(root, `apps/${app}/android`);
  const properties = Object.fromEntries(readFileSync(resolve(android, "key.properties"), "utf8").split(/\r?\n/).filter(line => line.includes("=") && !line.startsWith("#")).map(line => [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)]));
  const certificate = execFileSync("keytool", ["-exportcert", "-alias", properties.keyAlias, "-keystore", resolve(android, properties.storeFile), "-storepass:env", "EDAYA_KEYSTORE_PASSWORD"], { env: { ...process.env, EDAYA_KEYSTORE_PASSWORD: properties.storePassword } });
  const fingerprint = createHash("sha256").update(certificate).digest("hex");
  const verification = run(resolve(buildTools, "apksigner"), ["verify", "--print-certs", apk]);
  const actualFingerprint = verification.match(/Signer #1 certificate SHA-256 digest: ([a-f0-9]+)/i)?.[1]?.toLowerCase();
  if (actualFingerprint !== fingerprint) throw new Error(`${app} APK does not match the existing signing certificate`);
  const actualId = run(resolve(buildTools, "aapt"), ["dump", "badging", apk]).match(/package: name='([^']+)'/)?.[1];
  if (actualId !== applicationId) throw new Error(`${app} APK application ID changed`);
  records.push({ app, applicationId, certificateSha256: fingerprint, sha256: createHash("sha256").update(readFileSync(apk)).digest("hex") });
}
writeFileSync(resolve(root, "release-apks/signatures.json"), `${JSON.stringify(records, null, 2)}\n`);
console.log("Both APK signatures match the existing keystore and application IDs.");
