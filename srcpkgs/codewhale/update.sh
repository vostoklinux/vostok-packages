#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(sed -n 's/^[[:space:]]*version=//p' "${TEMPLATE}" | head -1)

API_URL="https://api.github.com/repos/Hmbown/CodeWhale/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST_VER="${LATEST_TAG#v}"

if [ "${CURRENT}" = "${LATEST_VER}" ]; then
    echo "codewhale: ${CURRENT} — already up to date"
    exit 0
fi

echo "codewhale: ${CURRENT} → ${LATEST_VER}"

URL_COD="https://github.com/Hmbown/CodeWhale/releases/download/${LATEST_TAG}/codewhale-linux-x64"
URL_TUI="https://github.com/Hmbown/CodeWhale/releases/download/${LATEST_TAG}/codewhale-tui-linux-x64"

CHK_COD=$(curl -L -# "${URL_COD}" | sha256sum | cut -d' ' -f1)
CHK_TUI=$(curl -L -# "${URL_TUI}" | sha256sum | cut -d' ' -f1)

sed -i "s/^[[:space:]]*version=.*/version=${LATEST_VER}/" "${TEMPLATE}"
sed -i "/^checksum=/,/^[^ ]/ s|^checksum=.*|checksum=\"\n ${CHK_COD}\n ${CHK_TUI}\n\"|" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER}"