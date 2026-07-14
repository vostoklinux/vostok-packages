#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/esp-rs/espflash/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "espflash: ${CURRENT} — already up to date"
    exit 0
fi

echo "espflash: ${CURRENT} → ${LATEST_VER}"

ZIP_URL="https://github.com/esp-rs/espflash/releases/download/${LATEST_TAG}/espflash-x86_64-unknown-linux-gnu.zip"
echo "URL: ${ZIP_URL}"

if ! curl --head --silent --fail "${ZIP_URL}" > /dev/null; then
    echo "ERROR: Archive not found at ${ZIP_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${ZIP_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER} (${CHECKSUM:0:16}...)"