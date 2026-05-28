#!/bin/bash
# Auto-updater for opencode
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest OpenCode version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/anomalyco/opencode/releases/latest")

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
")

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "opencode: ${CURRENT} — already up to date"
    exit 0
fi

echo "opencode: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/v${LATEST}/opencode-linux-x64.tar.gz"
echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"