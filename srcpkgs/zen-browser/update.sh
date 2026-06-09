#!/bin/bash
# Auto-updater for zen-browser
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Zen Browser version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/zen-browser/desktop/releases/latest")


TAG=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
")

if [ -z "${TAG}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi


if [[ "${TAG}" =~ ^([0-9.]+)b$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
else

    VERSION="${TAG}"
fi

if [ "${CURRENT}" = "${VERSION}" ]; then
    echo "zen-browser: ${CURRENT} — already up to date"
    exit 0
fi

echo "zen-browser: ${CURRENT} → ${VERSION} (tag: ${TAG})"

DOWNLOAD_URL="https://github.com/zen-browser/desktop/releases/download/${TAG}/zen.linux-x86_64.tar.xz"
echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the 'b' suffix is still present in the release tag."
echo "         If the tag changes to something like '1.21.0', edit distfiles manually."