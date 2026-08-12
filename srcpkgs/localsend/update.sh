#!/bin/bash
# Auto-updater for localsend
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest LocalSend release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

RELEASE_JSON=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/localsend/localsend/releases/latest")

read LATEST DEB_URL <<< $(echo "${RELEASE_JSON}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ver = d['tag_name'].lstrip('v')
# ищем ассет с именем, оканчивающимся на linux-x86-64.deb
deb = next((a['browser_download_url'] for a in d['assets'] if a['name'].endswith('linux-x86-64.deb')), '')
print(ver, deb)
")

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ -z "${DEB_URL}" ]; then
    echo "No .deb asset found in release v${LATEST}, skipping update." >&2
    exit 0
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "localsend: ${CURRENT} — already up to date"
    exit 0
fi

echo "localsend: ${CURRENT} → ${LATEST}"
echo "URL: ${DEB_URL}"

echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${DEB_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."