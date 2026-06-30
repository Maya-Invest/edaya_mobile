#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_DIR="$ROOT/android-signing"
KEYSTORE="$SIGNING_DIR/edaya-upload.jks"

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE"
  exit 0
fi

mkdir -p "$SIGNING_DIR"

STORE_PASSWORD="${EDAYA_KEYSTORE_STORE_PASSWORD:-}"
KEY_PASSWORD="${EDAYA_KEYSTORE_KEY_PASSWORD:-}"

if [[ -z "$STORE_PASSWORD" || -z "$KEY_PASSWORD" ]]; then
  STORE_PASSWORD="$(openssl rand -base64 24)"
  KEY_PASSWORD="$STORE_PASSWORD"
  echo "Generated random keystore passwords (save these securely):"
  echo "  EDAYA_KEYSTORE_STORE_PASSWORD=$STORE_PASSWORD"
  echo "  EDAYA_KEYSTORE_KEY_PASSWORD=$KEY_PASSWORD"
fi

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -storetype JKS \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -alias guardian \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Edaya Guardian, OU=Mobile, O=SoftiLab, L=Abidjan, ST=Abidjan, C=CI"

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -storetype JKS \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -alias teacher \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Edaya Teacher, OU=Mobile, O=SoftiLab, L=Abidjan, ST=Abidjan, C=CI"

write_key_properties() {
  local app="$1"
  local alias="$2"
  local dest="$ROOT/apps/$app/android/key.properties"

  cat >"$dest" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$alias
storeFile=../../../android-signing/edaya-upload.jks
EOF
  echo "Wrote $dest"
}

write_key_properties guardian guardian
write_key_properties teacher teacher

echo "Upload keystore ready: $KEYSTORE"
