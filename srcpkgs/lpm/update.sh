#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

RELEASE_INFO=$(curl -fsSL "https://api.github.com/repos/lite-xl/lite-xl-plugin-manager/releases/tags/continuous")
RELEASE_DATE=$(echo "$RELEASE_INFO" | python3 -c "
import sys, json
from datetime import datetime
d = json.load(sys.stdin)
published = d['published_at']  # формат ISO 8601
dt = datetime.strptime(published, '%Y-%m-%dT%H:%M:%SZ')
print(dt.strftime('%Y%m%d'))
")

if [ "${CURRENT}" = "${RELEASE_DATE}" ]; then
    echo "lpm: ${CURRENT} — already up to date"
    exit 0
fi

echo "lpm: ${CURRENT} → ${RELEASE_DATE}"

DOWNLOAD_URL="https://github.com/lite-xl/lite-xl-plugin-manager/releases/download/continuous/lpm.x86_64-linux"
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${RELEASE_DATE}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${RELEASE_DATE} (${CHECKSUM:0:16}...)"