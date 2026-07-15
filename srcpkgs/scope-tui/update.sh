#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/alemidev/scope-tui/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "scope-tui: ${CURRENT} — already up to date"
    exit 0
fi

echo "scope-tui: ${CURRENT} → ${LATEST_VER}"

BIN_URL="https://github.com/alemidev/scope-tui/releases/download/${LATEST_TAG}/scope-tui-${LATEST_TAG}-linux-x64-gnu"
echo "URL: ${BIN_URL}"

if ! curl --head --silent --fail "${BIN_URL}" > /dev/null; then
    echo "ERROR: Binary not found at ${BIN_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${BIN_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER} (${CHECKSUM:0:16}...)"