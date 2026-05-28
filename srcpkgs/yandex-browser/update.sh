#!/bin/bash
# Auto-updater for yandex-browser
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Yandex Browser version..."

PACKAGES=$(curl -fsSL \
    "https://repo.yandex.ru/yandex-browser/deb/dists/stable/main/binary-amd64/Packages.gz" \
    | gunzip -c)

LATEST=$(echo "${PACKAGES}" | grep '^Version:' | head -1 | grep -oP '[\d\.]+(?=-1)')

FILEPATH=$(echo "${PACKAGES}" | grep '^Filename:' | head -1 | awk '{print $2}')
FILENAME=$(basename "${FILEPATH}")
CHANNEL=$(echo "${FILENAME}" | grep -oP 'yandex-browser-\K[^_]+(?=_)')
DOWNLOAD_URL="https://repo.yandex.ru/yandex-browser/deb/${FILEPATH}"

if [ -z "${LATEST}" ] || [ -z "${FILEPATH}" ] || [ -z "${CHANNEL}" ]; then
    echo "ERROR: Could not parse Packages.gz" >&2
    echo "LATEST=${LATEST} FILEPATH=${FILEPATH} CHANNEL=${CHANNEL}" >&2
    exit 1
fi

echo "Latest : ${LATEST}"
echo "Channel: ${CHANNEL}"
echo "File   : ${FILENAME}"

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "yandex-browser: ${CURRENT} — already up to date"
    exit 0
fi

echo "yandex-browser: ${CURRENT} → ${LATEST}"
echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"
sed -i "s/^_channel=.*/_channel=${CHANNEL}/" "${TEMPLATE}"

DISTFILES_LINE="distfiles=\"https://repo.yandex.ru/yandex-browser/deb/pool/main/y/yandex-browser-\${_channel}/yandex-browser-\${_channel}_\${version}-1_amd64.deb\""
sed -i "s|^distfiles=.*|${DISTFILES_LINE}|" "${TEMPLATE}"

echo "Done: ${LATEST} channel=${CHANNEL} (${CHECKSUM:0:16}...)"