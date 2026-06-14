#!/bin/bash
# Auto-updater for cryptomator
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest Cryptomator version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/cryptomator/cryptomator/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

LATEST=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
tag = d['tag_name']
# убираем 'v' если есть
if tag.startswith('v'):
    tag = tag[1:]
print(tag)
" 2>/dev/null) || {
    echo "ERROR: Could not parse version" >&2
    exit 1
}

if [ -z "$LATEST" ]; then
    echo "ERROR: No version found" >&2
    exit 1
fi

if [ "$CURRENT" = "$LATEST" ]; then
    echo "cryptomator: $CURRENT — already up to date"
    exit 0
fi

echo "cryptomator: $CURRENT → $LATEST"

DEB_URL="https://github.com/cryptomator/cryptomator/releases/download/${LATEST}/cryptomator_${LATEST}-0ppa1_amd64.deb"
echo "URL: $DEB_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$DEB_URL" | sha256sum | cut -d' ' -f1)

if [[ "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
    sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
    sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"
    echo "Done: $LATEST (${CHECKSUM:0:16}...)"
else
    echo "ERROR: Failed to download valid deb file (checksum not obtained)" >&2
    exit 1
fi