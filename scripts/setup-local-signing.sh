#!/bin/bash
# Creates a stable, self-signed identity for Kiki development builds.
set -euo pipefail

IDENTITY="${KIKI_LOCAL_SIGNING_IDENTITY:-Kiki Local Code Signing}"
KEYCHAIN="${KIKI_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
CERT_DAYS="${KIKI_LOCAL_CERT_DAYS:-3650}"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
    echo "Code-signing identity already exists: $IDENTITY"
    exit 0
fi

command -v openssl >/dev/null || {
    echo "error: openssl is required to create the local signing identity" >&2
    exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kiki-signing.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = subject
prompt = no
x509_extensions = signing_cert

[subject]
CN = $IDENTITY
O = Kiki Local Development

[signing_cert]
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl req \
    -newkey rsa:2048 \
    -x509 \
    -sha256 \
    -nodes \
    -days "$CERT_DAYS" \
    -config "$WORK_DIR/openssl.cnf" \
    -keyout "$WORK_DIR/signing-key.pem" \
    -out "$WORK_DIR/signing-cert.pem"

P12_PASSWORD="$(openssl rand -hex 32)"
openssl pkcs12 \
    -export \
    -legacy \
    -inkey "$WORK_DIR/signing-key.pem" \
    -in "$WORK_DIR/signing-cert.pem" \
    -name "$IDENTITY" \
    -passout "pass:$P12_PASSWORD" \
    -out "$WORK_DIR/signing-identity.p12"

# Restrict private-key access to Apple's code-signing tool.
security import "$WORK_DIR/signing-identity.p12" \
    -k "$KEYCHAIN" \
    -f pkcs12 \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign

# Trust the self-signed certificate in the current user's login keychain.
security add-trusted-cert \
    -r trustRoot \
    -k "$KEYCHAIN" \
    "$WORK_DIR/signing-cert.pem"

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
    echo "error: $IDENTITY was imported but is not a valid code-signing identity" >&2
    exit 1
fi

echo
echo "Created and trusted local code-signing identity: $IDENTITY"
echo "Kiki development builds will select it automatically."
