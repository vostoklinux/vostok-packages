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

# Обновляем version
sed -i "s/^[[:space:]]*version=.*/version=${LATEST_VER}/" "${TEMPLATE}"

# Обновляем checksum (ОДНА строка с двумя хешами)
sed -i "s|^checksum=.*|checksum=\"${CHK_COD} ${CHK_TUI}\"|" "${TEMPLATE}"

# Сбрасываем revision
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_VER}"