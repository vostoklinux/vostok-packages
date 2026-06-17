#!/bin/bash
# Auto-updater for vfox
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest vfox release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/version-fox/vfox/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'])
" 2>/dev/null) || {
    echo "ERROR: Could not parse tag" >&2
    exit 1
}


ASSET_NAME=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    name = a['name']
    if name.startswith('vfox_') and name.endswith('_linux_x86_64.deb'):
        print(name)
        break
" 2>/dev/null)

if [ -z "$ASSET_NAME" ]; then
    echo "No deb asset found in this release. Skipping update."
    exit 0
fi


LATEST="${TAG#v}"

if [ "$CURRENT" = "$LATEST" ]; then
    echo "vfox: $CURRENT — already up to date"
    exit 0
fi

echo "vfox: $CURRENT → $LATEST"

DOWNLOAD_URL=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d['assets']:
    if a['name'] == '$ASSET_NAME':
        print(a['browser_download_url'])
        break
")

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not get download URL" >&2
    exit 1
fi

echo "URL: $DOWNLOAD_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$DOWNLOAD_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $LATEST (${CHECKSUM:0:16}...)"