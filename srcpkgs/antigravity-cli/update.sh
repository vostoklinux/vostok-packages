#!/bin/bash
# Auto-updater for antigravity-cli (fetches latest version from AUR and updates template)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

# Helper: read variable from template
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
current_upstream_version=$(read_assignment _upstream_version)
current_revision=$(read_assignment revision)

echo "Current version: ${current_version} (upstream ${current_upstream_version})"

# Fetch latest version from AUR RPC
echo "Fetching latest version from AUR..."
AUR_URL="https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=antigravity-cli"
AUR_JSON=$(curl -fsSL --retry 3 --retry-delay 2 "${AUR_URL}")

# Extract Version field using python3
raw_aur_version=$(echo "${AUR_JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('resultcount', 0) == 0:
    sys.exit('ERROR: package not found in AUR')
pkg = data['results'][0]
ver = pkg.get('Version', '')
# Remove -pkgrel if present (e.g. 1.1.27_5211191891591168-1 -> 1.1.27_5211191891591168)
if '-' in ver:
    ver = ver.rsplit('-', 1)[0]
print(ver)
")

[[ ${raw_aur_version} =~ ^[0-9]+\.[0-9]+\.[0-9]+_[0-9]+$ ]] || {
    echo "ERROR: invalid version from AUR: ${raw_aur_version}" >&2
    exit 1
}

latest_version=${raw_aur_version//_/.}

latest_upstream_version=${raw_aur_version//_/-}


echo "Latest version: ${latest_version} (upstream ${latest_upstream_version})"

if [[ ${latest_version} == "${current_version}" ]]; then
    echo "antigravity-cli is current: ${current_version}"
    exit 0
fi

echo "antigravity-cli: ${current_version} → ${latest_version}"

DOWNLOAD_URL="https://storage.googleapis.com/antigravity-public/antigravity-cli/${latest_upstream_version}/linux-x64/cli_linux_x64.tar.gz"
echo "URL: ${DOWNLOAD_URL}"

TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT
echo "Downloading..."
curl -fL --retry 3 --retry-delay 2 -o "${TMPFILE}" "${DOWNLOAD_URL}"
CHECKSUM=$(sha256sum "${TMPFILE}" | cut -d' ' -f1)
[[ ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: invalid checksum" >&2; exit 1; }

sed -i "s/^version=.*/version=${latest_version}/" "${TEMPLATE}"
sed -i "s/^_upstream_version=.*/_upstream_version=${latest_upstream_version}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${current_version} -> ${latest_version}"
echo "Checksum: ${CHECKSUM}"
echo "Remember to verify that the archive layout hasn't changed."