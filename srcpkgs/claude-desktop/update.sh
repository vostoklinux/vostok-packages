#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT_VERSION=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
CURRENT_RELEASE=$(grep '^_release=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"
RELEASE_JSON=$(curl -sL "$API_URL")

TAG=$(echo "$RELEASE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
RELEASE="${TAG#v}"
RELEASE="${RELEASE%%+*}"
VERSION="${TAG##*+claude}"

if [ "${CURRENT_VERSION}" = "${VERSION}" ] && [ "${CURRENT_RELEASE}" = "${RELEASE}" ]; then
    echo "claude-desktop: ${CURRENT_VERSION}-${CURRENT_RELEASE} — already up to date"
    exit 0
fi

echo "claude-desktop: ${CURRENT_VERSION}-${CURRENT_RELEASE} → ${VERSION}-${RELEASE}"

APPIMAGE_URL=$(echo "$RELEASE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    name = asset['name']
    if 'unofficial' in name and name.endswith('.AppImage') and 'amd64' in name:
        print(asset['browser_download_url'])
        break
else:
    sys.exit('ERROR: Could not find unofficial amd64 AppImage')
")

echo "URL: ${APPIMAGE_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${APPIMAGE_URL}" | sha256sum | cut -d' ' -f1)

# Обновляем шаблон
sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s/^_release=.*/_release=${RELEASE}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${APPIMAGE_URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION}-${RELEASE} (${CHECKSUM:0:16}...)"