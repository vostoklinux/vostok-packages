#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/ChrisTitusTech/linutil/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

if [ "${CURRENT}" = "${LATEST_TAG}" ]; then
    echo "linutil: ${CURRENT} — already up to date"
    exit 0
fi

echo "linutil: ${CURRENT} → ${LATEST_TAG}"

DIST_URL="https://github.com/ChrisTitusTech/linutil/releases/download/${LATEST_TAG}/linutil"
CHECKSUM=$(curl -L -# "${DIST_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_TAG}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"
echo "Done: ${LATEST_TAG} (${CHECKSUM:0:16}...)"