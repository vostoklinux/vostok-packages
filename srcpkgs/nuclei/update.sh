#!/bin/bash
# Auto-updater for nuclei
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/projectdiscovery/nuclei/releases/latest"
LATEST_TAG=$(curl -fsSL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "nuclei: ${CURRENT} — already up to date"
    exit 0
fi

echo "nuclei: ${CURRENT} → ${LATEST_VER}"

ZIP_URL="https://github.com/projectdiscovery/nuclei/releases/download/${LATEST_TAG}/nuclei_${LATEST_VER}_linux_amd64.zip"
echo "URL: ${ZIP_URL}"

if ! curl --head --silent --fail "${ZIP_URL}" > /dev/null; then
    echo "ERROR: Archive not found at ${ZIP_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -fsSL "${ZIP_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER} (${CHECKSUM:0:16}...)"