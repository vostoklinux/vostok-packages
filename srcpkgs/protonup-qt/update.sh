#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="${SCRIPT_DIR}/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(awk -F= '$1 == "version" { print $2; exit }' "${TEMPLATE}")
[[ ${CURRENT} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	echo "ERROR: invalid current version: ${CURRENT}" >&2
	exit 1
}

for command in curl jq awk sha256sum mktemp chmod mv; do
	command -v "${command}" >/dev/null || {
		echo "ERROR: required command not found: ${command}" >&2
		exit 1
	}
done

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
if [[ -n ${GITHUB_TOKEN:-} ]]; then
	CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

INFO=$(curl "${CURL_ARGS[@]}" \
	"https://api.github.com/repos/DavidoTek/ProtonUp-Qt/releases/latest")

LATEST=$(jq -er '
	if (.draft == false and .prerelease == false) then
		.tag_name | capture("^v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version
	else
		error("latest GitHub release is not stable")
	end
' <<<"${INFO}")

ASSET_NAME="ProtonUp-Qt-${LATEST}-x86_64.AppImage"
DOWNLOAD_URL=$(jq -er --arg asset "${ASSET_NAME}" '
	[.assets[]?
	 | select((.name == $asset) and (.browser_download_url | type == "string"))
	 | .browser_download_url]
	| if length == 1 then .[0]
	  else error("release asset not found or duplicated: \($asset)")
	  end
' <<<"${INFO}")

IFS=. read -r -a current_parts <<<"${CURRENT}"
IFS=. read -r -a latest_parts <<<"${LATEST}"
comparison=0
for index in 0 1 2; do
	current_part=$((10#${current_parts[index]}))
	latest_part=$((10#${latest_parts[index]}))
	if ((latest_part < current_part)); then
		comparison=-1
		break
	elif ((latest_part > current_part)); then
		comparison=1
		break
	fi
done

if ((comparison < 0)); then
	echo "ERROR: latest release ${LATEST} is older than packaged ${CURRENT}" >&2
	exit 1
elif ((comparison == 0)); then
	echo "protonup-qt: ${CURRENT} is already up to date"
	exit 0
fi

LICENSE_URL="https://raw.githubusercontent.com/DavidoTek/ProtonUp-Qt/v${LATEST}/LICENSE"
DOWNLOAD_DIR=$(mktemp -d)
NEW_TEMPLATE=$(mktemp "${SCRIPT_DIR}/.template.XXXXXX")
cleanup() {
	rm -rf -- "${DOWNLOAD_DIR}"
	rm -f -- "${NEW_TEMPLATE}"
}
trap cleanup EXIT

curl -fL "${DOWNLOAD_URL}" -o "${DOWNLOAD_DIR}/protonup-qt.AppImage"
curl -fL "${LICENSE_URL}" -o "${DOWNLOAD_DIR}/LICENSE"
[[ -s ${DOWNLOAD_DIR}/protonup-qt.AppImage && -s ${DOWNLOAD_DIR}/LICENSE ]] || {
	echo "ERROR: downloaded artifact is empty" >&2
	exit 1
}

APPIMAGE_CHECKSUM=$(sha256sum "${DOWNLOAD_DIR}/protonup-qt.AppImage" | awk '{print $1}')
LICENSE_CHECKSUM=$(sha256sum "${DOWNLOAD_DIR}/LICENSE" | awk '{print $1}')
for value in "${APPIMAGE_CHECKSUM}" "${LICENSE_CHECKSUM}"; do
	[[ ${value} =~ ^[0-9a-f]{64}$ ]] || {
		echo "ERROR: invalid SHA-256: ${value}" >&2
		exit 1
	}
done

awk -v version="${LATEST}" \
	-v appimage_checksum="${APPIMAGE_CHECKSUM}" \
	-v license_checksum="${LICENSE_CHECKSUM}" '
	BEGIN { version_count = revision_count = checksum_count = 0 }
	/^version=/ {
		print "version=" version
		version_count++
		next
	}
	/^revision=/ {
		print "revision=1"
		revision_count++
		next
	}
	/^checksum=/ {
		print "checksum=\"" appimage_checksum
		print " " license_checksum "\""
		checksum_count++
		if ($0 !~ /"$/) {
			while (getline > 0 && $0 !~ /"$/) {}
		}
		next
	}
	{ print }
	END {
		if (version_count != 1 || revision_count != 1 || checksum_count != 1) {
			print "ERROR: template fields are missing or duplicated" > "/dev/stderr"
			exit 1
		}
	}
' "${TEMPLATE}" >"${NEW_TEMPLATE}"

chmod --reference="${TEMPLATE}" "${NEW_TEMPLATE}"
mv -- "${NEW_TEMPLATE}" "${TEMPLATE}"

echo "protonup-qt: ${CURRENT} -> ${LATEST}"
echo "AppImage SHA-256: ${APPIMAGE_CHECKSUM}"
echo "License SHA-256: ${LICENSE_CHECKSUM}"
