#!/bin/bash
# Auto-updater for telegram-bin
# Uses GitHub releases API
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
API_URL="https://api.github.com/repos/telegramdesktop/tdesktop/releases/latest"

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Telegram Desktop version..."
INFO=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${API_URL}")

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
")

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "telegram-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "telegram-bin: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://github.com/telegramdesktop/tdesktop/releases/download/v${LATEST}/tsetup.${LATEST}.tar.xz"

echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"