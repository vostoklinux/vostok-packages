#!/bin/bash
# Auto-updater for akira-noctalia (Noctalia v5 beta)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

read_assignment() {
    local key=$1
    awk -F= -v key="${key}" '
        $1 == key {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]"\047]+|[[:space:]"\047]+$/, "", value)
            print value
            exit
        }
    ' "${TEMPLATE}"
}

current_version=$(read_assignment version)
current_tag=$(read_assignment _tag)
current_revision=$(read_assignment revision)

echo "Current version: ${current_version} (_tag=${current_tag})"
echo "Fetching latest Noctalia release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/noctalia-dev/noctalia/releases?per_page=10") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "$INFO" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
# Первый не-draft релиз (GitHub сортирует по дате по убыванию)
for r in releases:
    if not r.get('draft', False):
        print(r['tag_name'])
        break
" 2>/dev/null) || {
    echo "ERROR: Could not parse tag" >&2
    exit 1
}

if [ -z "${TAG}" ]; then
    echo "ERROR: No suitable release found" >&2
    exit 1
fi

echo "Latest tag: ${TAG}"

TAG_CLEAN="${TAG#v}"
NEW_TAG="${TAG_CLEAN}"
NEW_VERSION="${TAG_CLEAN//-/.}"

if [ -z "${NEW_VERSION}" ]; then
    echo "ERROR: Could not extract version from tag: ${TAG}" >&2
    exit 1
fi

echo "Extracted version: ${NEW_VERSION} (_tag=${NEW_TAG})"

if [ "${current_version}" = "${NEW_VERSION}" ] && [ "${current_tag}" = "${NEW_TAG}" ]; then
    echo "akira-noctalia: ${current_version} — already up to date"
    exit 0
fi

echo "akira-noctalia: ${current_version} → ${NEW_VERSION}"

DIST_URL="https://github.com/noctalia-dev/noctalia/archive/refs/tags/v${NEW_TAG}.tar.gz"
echo "URL: ${DIST_URL}"

echo "Computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "$DIST_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${NEW_VERSION}/" "${TEMPLATE}"
sed -i "s/^_tag=.*/_tag=${NEW_TAG}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"
echo "Done: ${NEW_VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify build dependencies haven't changed."