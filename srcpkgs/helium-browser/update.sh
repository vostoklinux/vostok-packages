#!/bin/bash
# Auto-updater for helium-browser
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Helium Browser version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/imputnet/helium-linux/releases/latest")

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
    echo "helium-browser: ${CURRENT} — already up to date"
    exit 0
fi

echo "helium-browser: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    if 'x86_64.AppImage' in a['name']:
        print(a['browser_download_url'])
        break
")

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "ERROR: Could not find x86_64 AppImage in assets" >&2
    exit 1
fi

echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"