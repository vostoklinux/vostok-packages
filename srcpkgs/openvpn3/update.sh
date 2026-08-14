#!/bin/bash
# Auto-updater for openvpn3
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "${TEMPLATE}" ]; then
    echo "ERROR: Template file not found at ${TEMPLATE}" >&2
    exit 1
fi

CURRENT=$(grep -m1 '^version=' "${TEMPLATE}" | cut -d= -f2) || {
    echo "ERROR: Could not read version from template" >&2
    exit 1
}

echo "Fetching latest OpenVPN 3 Linux version from Codeberg..."

INFO=$(curl -fsSL -H "Accept: application/json" \
    "https://codeberg.org/api/v1/repos/OpenVPN/openvpn3-linux/tags?limit=50") || {
    echo "ERROR: Failed to query Codeberg tags API" >&2
    exit 1
}

LATEST=$(echo "${INFO}" | python3 -c '
import json
import re
import sys

tags = json.load(sys.stdin)
versions = []
for tag in tags:
    match = re.fullmatch(r"v([0-9]+(?:\.[0-9]+)*)", tag.get("name", ""))
    if match:
        version = match.group(1)
        versions.append((tuple(map(int, version.split("."))), version))

if versions:
    print(max(versions)[1])
' 2>/dev/null) || {
    echo "ERROR: Could not parse Codeberg tags response" >&2
    exit 1
}

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest stable version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "openvpn3: ${CURRENT} — already up to date"
    exit 0
fi

echo "openvpn3: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://swupdate.openvpn.net/community/releases/openvpn3-linux-${LATEST}.tar.xz"

echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fL -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! "${CHECKSUM}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
