#!/bin/bash
# Auto-updater for librewolf (Codeberg package listing API)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT_DOT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest LibreWolf version from Codeberg..."

API_URL="https://codeberg.org/api/v1/packages/librewolf"
RESPONSE=$(curl -fsSL -H "Accept: application/json" "$API_URL") || {
    echo "ERROR: Failed to query Codeberg packages API" >&2
    exit 1
}

DASH_VERSION=$(echo "$RESPONSE" | python3 -c "
import sys, json
packages = json.load(sys.stdin)
for p in packages:
    if p.get('name') == 'librewolf' and p.get('type') == 'generic':
        print(p['version'])
        break
" 2>/dev/null) || {
    echo "ERROR: Could not find librewolf package in API response" >&2
    exit 1
}

if [ -z "$DASH_VERSION" ]; then
    echo "ERROR: No version found" >&2
    exit 1
fi

DOT_VERSION="${DASH_VERSION//-/.}"

if [ "$CURRENT_DOT" = "$DOT_VERSION" ]; then
    echo "librewolf: ${CURRENT_DOT} — already up to date"
    exit 0
fi

echo "librewolf: ${CURRENT_DOT} → ${DOT_VERSION}"

ARCHIVE_URL="https://codeberg.org/api/packages/librewolf/generic/librewolf/${DASH_VERSION}/librewolf-${DASH_VERSION}-linux-x86_64-package.tar.xz"
echo "URL: ${ARCHIVE_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${ARCHIVE_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${DOT_VERSION}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"https://codeberg.org/api/packages/librewolf/generic/librewolf/${DASH_VERSION}/librewolf-${DASH_VERSION}-linux-x86_64-package.tar.xz\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${DOT_VERSION} (${CHECKSUM:0:16}...)"