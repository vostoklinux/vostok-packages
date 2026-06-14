#!/bin/bash
# Auto-updater for losslesscut
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest LosslessCut version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/mifi/lossless-cut/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

LATEST=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
" 2>/dev/null) || {
    echo "ERROR: Could not parse version" >&2
    exit 1
}

if [ -z "$LATEST" ]; then
    echo "ERROR: No version found" >&2
    exit 1
fi

if [ "$CURRENT" = "$LATEST" ]; then
    echo "losslesscut: $CURRENT — already up to date"
    exit 0
fi

echo "losslesscut: $CURRENT → $LATEST"

ARCHIVE_URL="https://github.com/mifi/lossless-cut/releases/download/v${LATEST}/LosslessCut-linux-x64.tar.bz2"
echo "URL: $ARCHIVE_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$ARCHIVE_URL" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $LATEST (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal structure hasn't changed."