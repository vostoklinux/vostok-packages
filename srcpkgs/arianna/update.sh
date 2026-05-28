#!/bin/bash
# Auto-updater for arianna (KDE release-service)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Arianna version from KDE release-service..."

LATEST=$(curl -fsSL "https://download.kde.org/stable/release-service/" \
    | grep -oP 'href="\K[\d]+\.[\d]+\.[\d]+(?=/)' \
    | sort -V \
    | tail -1)

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest KDE release-service version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "arianna: ${CURRENT} — already up to date"
    exit 0
fi

echo "arianna: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://download.kde.org/stable/release-service/${LATEST}/src/arianna-${LATEST}.tar.xz"

echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"