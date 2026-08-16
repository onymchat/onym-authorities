#!/usr/bin/env bash
# Sign authorities.json with the directory root key and emit
# authorities.json.sig — the detached signature every release MUST
# attach alongside the asset (clients that pin the root key refuse an
# unsigned directory outright).
#
# Wire contract (mirrors the authority-manifest .sig in onym-infra):
# base64 of the 64-byte raw Ed25519 signature, trailing newline.
# Verifiers trim whitespace before decoding.
#
# The private key NEVER enters this repository or any CI secret — it
# is the root of the moderation consent trust chain, held offline by
# the release manager. Pass its path via ONYM_DIRECTORY_ROOT_KEY.
#
# Release procedure:
#   1. edit authorities.json on a branch, review, merge
#   2. ./sign.sh
#   3. gh release create v<N> authorities.json authorities.json.sig
#      (both assets in ONE release — a release with the json but no
#      sig bricks consent on pinning clients until the sig lands)
#   4. verify the served pair:
#      base=https://github.com/onymchat/onym-authorities/releases/latest/download
#      curl -sL $base/authorities.json      -o /tmp/a.json
#      curl -sL $base/authorities.json.sig  -o /tmp/a.sig
#      ./sign.sh --verify /tmp/a.json /tmp/a.sig
set -euo pipefail

cd "$(dirname "$0")"

OPENSSL="${OPENSSL:-openssl}"
if ! "$OPENSSL" genpkey -algorithm ed25519 -out /dev/null 2>/dev/null; then
    # macOS system LibreSSL has no ed25519; prefer brew's OpenSSL 3.
    for candidate in /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl; do
        [ -x "$candidate" ] && OPENSSL="$candidate" && break
    done
fi

PUBKEY_FILE="directory-root-pubkey.txt"

if [ "${1:-}" = "--verify" ]; then
    asset="$2"; sigfile="$3"
    workdir=$(mktemp -d)
    trap 'rm -rf "$workdir"' EXIT
    tr -d ' \n\r' < "$sigfile" | base64 -d > "$workdir/sig.raw"
    # SPKI DER = the fixed 12-byte Ed25519 header + the 32 raw key bytes.
    printf '302a300506032b6570032100' | xxd -r -p > "$workdir/pub.der"
    base64 -d < "$PUBKEY_FILE" >> "$workdir/pub.der"
    "$OPENSSL" pkeyutl -verify -rawin -pubin -keyform DER \
        -inkey "$workdir/pub.der" -in "$asset" -sigfile "$workdir/sig.raw"
    exit 0
fi

: "${ONYM_DIRECTORY_ROOT_KEY:?set ONYM_DIRECTORY_ROOT_KEY to the offline root key PEM path}"

# The public half derived from the offered key must be the committed
# one: signing with a different key would publish a signature no
# shipped client accepts.
derived=$("$OPENSSL" pkey -in "$ONYM_DIRECTORY_ROOT_KEY" -pubout -outform DER | tail -c 32 | base64)
committed=$(tr -d ' \n\r' < "$PUBKEY_FILE")
if [ "$derived" != "$committed" ]; then
    echo "refusing: key at ONYM_DIRECTORY_ROOT_KEY does not match $PUBKEY_FILE" >&2
    exit 1
fi

"$OPENSSL" pkeyutl -sign -rawin -inkey "$ONYM_DIRECTORY_ROOT_KEY" \
    -in authorities.json -out /tmp/onym-authorities-sig.bin
base64 < /tmp/onym-authorities-sig.bin > authorities.json.sig
printf '\n' >> authorities.json.sig
rm -f /tmp/onym-authorities-sig.bin
echo "wrote authorities.json.sig"
