#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/siddharthvaddem/openscreen/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

# Убираем ведущий 'v', если он есть
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "openscreen: ${CURRENT} — already up to date"
    exit 0
fi

echo "openscreen: ${CURRENT} → ${LATEST_VER}"

DEB_URL="https://github.com/siddharthvaddem/openscreen/releases/download/${LATEST_TAG}/Openscreen-Linux-${LATEST_VER}.deb"
echo "URL: ${DEB_URL}"

if ! curl --head --silent --fail "${DEB_URL}" > /dev/null; then
    echo "ERROR: Deb package not found at ${DEB_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${DEB_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER} (${CHECKSUM:0:16}...)"