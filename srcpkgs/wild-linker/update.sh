#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/wild-linker/wild/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "wild-linker: ${CURRENT} — already up to date"
    exit 0
fi

echo "wild-linker: ${CURRENT} → ${LATEST_VER}"

TAR_URL="https://github.com/wild-linker/wild/releases/download/${LATEST_VER}/wild-linker-${LATEST_VER}-x86_64-unknown-linux-gnu.tar.gz"
echo "URL: ${TAR_URL}"

if ! curl --head --silent --fail "${TAR_URL}" > /dev/null; then
    echo "ERROR: Archive not found at ${TAR_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${TAR_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER} (${CHECKSUM:0:16}...)"