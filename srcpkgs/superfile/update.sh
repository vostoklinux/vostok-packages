#!/bin/bash
# Auto-updater for superfile
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found at $TEMPLATE" >&2
    exit 1
fi

CURRENT=$(grep -m1 '^version=' "$TEMPLATE" | cut -d= -f2) || {
    echo "ERROR: Could not read version from template" >&2
    exit 1
}

echo "Current version: $CURRENT"
echo "Fetching latest superfile release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/yorukot/superfile/releases/latest") || {
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

LATEST="${TAG#v}"

if [ "$CURRENT" = "$LATEST" ]; then
    echo "superfile: $CURRENT — already up to date"
    exit 0
fi

echo "superfile: $CURRENT → $LATEST"

ARCHIVE_URL="https://github.com/yorukot/superfile/releases/download/v${LATEST}/superfile-linux-v${LATEST}-amd64.tar.gz"
echo "URL: $ARCHIVE_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$ARCHIVE_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $LATEST (${CHECKSUM:0:16}...)"
