#!/bin/bash
# Auto-updater for noctalia-shell (stable releases only)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest stable Noctalia release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/noctalia-dev/noctalia-shell/releases/latest") || {
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

echo "Latest tag: $TAG"

VERSION="${TAG#v}"
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not extract version from tag: $TAG" >&2
    exit 1
fi

IS_PRERELEASE=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(str(d.get('prerelease', False)).lower())
" 2>/dev/null)

if [ "$IS_PRERELEASE" = "true" ]; then
    echo "Latest release is a prerelease. Skipping update."
    exit 0
fi

if [ "$CURRENT" = "$VERSION" ]; then
    echo "noctalia-shell: $CURRENT — already up to date"
    exit 0
fi

echo "noctalia-shell: $CURRENT → $VERSION"

DIST_URL="https://github.com/noctalia-dev/noctalia-shell/archive/refs/tags/v${VERSION}.tar.gz"
echo "URL: $DIST_URL"

echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "$DIST_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi


sed -i "s/^version=.*/version=${VERSION}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $VERSION (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."