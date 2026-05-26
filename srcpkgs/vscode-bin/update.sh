#!/bin/bash
# Auto-updater for vscode-bin
# Uses official Microsoft update API — no GitHub needed
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
API_URL="https://update.code.visualstudio.com/api/update/linux-x64/stable/latest"

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest VSCode version..."
INFO=$(curl -fsSL "${API_URL}")


LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['productVersion'])
")

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "vscode-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "vscode-bin: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['url'])
")

echo "Computing checksum (downloading ~100MB)..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"