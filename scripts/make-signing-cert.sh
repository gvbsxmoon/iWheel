#!/bin/bash
# ONE-TIME setup: creates a local self-signed code-signing identity named
# "iWheel Local Dev" so TCC permissions survive rebuilds (ad-hoc signatures
# change every build, and macOS ties permissions to the code signature).
# Run from YOUR terminal: it asks for sudo (to trust the cert) and the first
# build afterwards shows a keychain prompt - click "Always Allow".
set -euo pipefail

NAME="iWheel Local Dev"

if security find-identity -p codesigning -v 2>/dev/null | grep -q "$NAME"; then
    echo "Identity '$NAME' already exists - nothing to do."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Idempotent: if the cert already exists (e.g. an earlier run stopped at
# the sudo step), skip generation and only complete the trust step.
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Certificate already in the keychain - completing the trust step only."
    security find-certificate -c "$NAME" -p > "$TMP/cert.pem"
else
cat > "$TMP/ext.cnf" <<'EOF'
[req]
distinguished_name = dn
[dn]
[ext]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
EOF

# System LibreSSL, NOT a Homebrew OpenSSL 3: v3 defaults to AES/SHA-256
# PKCS12 that macOS `security import` rejects (MAC verification failed).
OPENSSL=/usr/bin/openssl

$OPENSSL req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -subj "/CN=$NAME" -config "$TMP/ext.cnf" -extensions ext
$OPENSSL pkcs12 -export -out "$TMP/identity.p12" -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" -passout pass:iwheel

security import "$TMP/identity.p12" -k ~/Library/Keychains/login.keychain-db \
    -P iwheel -T /usr/bin/codesign
fi

echo "Trusting the certificate for code signing (sudo)..."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$TMP/cert.pem"

echo
echo "Done. Rebuild with scripts/release.sh - it now signs as '$NAME'."
echo "On the first signing, click 'Always Allow' at the keychain prompt."
echo "Then reset the stale permission entries once:"
echo "  tccutil reset All dev.lucanatale.iWheel"
echo "and re-grant them at next launch. From then on they persist."
