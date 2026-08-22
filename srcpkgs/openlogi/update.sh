#!/bin/bash
# Auto-updater for openlogi (skip if no .deb asset)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest OpenLogi release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest") || {
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

ASSET_NAME="openlogi-${TAG#v}-linux-amd64.deb"
HAS_ASSET=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assets = d.get('assets', [])
print('yes' if any(a['name'] == '${ASSET_NAME}' for a in assets) else 'no')
" 2>/dev/null)

if [ "$HAS_ASSET" != "yes" ]; then
    echo "No ${ASSET_NAME} asset found in this release. Skipping update."
    exit 0
fi

VERSION="${TAG#v}"
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not extract version from tag: $TAG" >&2
    exit 1
fi

echo "Extracted version: $VERSION"

if [ "$CURRENT" = "$VERSION" ]; then
    echo "openlogi: $CURRENT — already up to date"
    exit 0
fi

echo "openlogi: $CURRENT → $VERSION"

DOWNLOAD_URL=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d['assets']:
    if a['name'] == '${ASSET_NAME}':
        print(a['browser_download_url'])
        break
")
if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not get download URL" >&2
    exit 1
fi

echo "URL: $DOWNLOAD_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "$DOWNLOAD_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${VERSION}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $VERSION (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."