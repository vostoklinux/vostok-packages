#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/ynqa/jnv/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

if [ "${CURRENT}" = "${LATEST_TAG#v}" ]; then
    echo "jnv: ${CURRENT} — already up to date"
    exit 0
fi

echo "jnv: ${CURRENT} → ${LATEST_TAG#v}"

DIST_URL="https://github.com/ynqa/jnv/releases/download/${LATEST_TAG}/jnv-x86_64-unknown-linux-gnu.tar.xz"
echo "URL: ${DIST_URL}"

if ! curl --head --silent --fail "${DIST_URL}" > /dev/null; then
    echo "ERROR: Archive not found at ${DIST_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${DIST_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_TAG#v}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_TAG#v} (${CHECKSUM:0:16}...)"