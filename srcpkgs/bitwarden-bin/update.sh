#!/bin/bash
# Auto-updater for bitwarden-bin
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Bitwarden version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/bitwarden/clients/releases?per_page=20")

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
for r in releases:
    tag = r.get('tag_name', '')
    if tag.startswith('desktop-v') and not r.get('prerelease'):
        print(tag.replace('desktop-v', ''))
        break
")

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "bitwarden-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "bitwarden-bin: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
for r in releases:
    tag = r.get('tag_name', '')
    if tag.startswith('desktop-v') and not r.get('prerelease'):
        for a in r.get('assets', []):
            if a['name'].endswith('amd64.deb'):
                print(a['browser_download_url'])
                break
        break
")

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "ERROR: Could not find amd64.deb in assets" >&2
    exit 1
fi

echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"