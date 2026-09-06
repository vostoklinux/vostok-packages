#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="${SCRIPT_DIR}/template"
LANDING_URL="https://download.nomachine.com/personal-edition/"
DOWNLOAD_BASE="https://download.nomachine.com/download"

[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

for command in awk chmod curl mktemp mv sha256sum; do
	command -v "${command}" >/dev/null 2>&1 || {
		echo "ERROR: required command not found: ${command}" >&2
		exit 1
	}
done

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

extract_detail_url() {
	local html=$1 distro=${2:-} line pattern

	if [[ -n ${distro} ]]; then
		pattern='href="(https://download\.nomachine\.com/download/\?id=[0-9]+&platform=linux&distro='"${distro}"')"'
	else
		pattern='href="(https://download\.nomachine\.com/download/\?id=[0-9]+&platform=linux)"'
	fi

	while IFS= read -r line; do
		if [[ ${line} =~ ${pattern} ]]; then
			printf '%s\n' "${BASH_REMATCH[1]}"
			return 0
		fi
	done <<< "${html}"

	return 1
}

extract_tarball_url() {
	local html=$1 directory=$2 architecture=$3 line pattern
	pattern='(https://[^"[:space:]]+/download/[0-9]+\.[0-9]+/'"${directory}"'/[a-z0-9-]+_[0-9]+\.[0-9]+\.[0-9]+_[0-9]+_'"${architecture}"'\.tar\.gz)'

	while IFS= read -r line; do
		if [[ ${line} =~ ${pattern} ]]; then
			printf '%s\n' "${BASH_REMATCH[1]}"
			return 0
		fi
	done <<< "${html}"

	return 1
}

version_is_newer() {
	local candidate=$1 current=$2 candidate_parts current_parts index
	IFS=. read -r -a candidate_parts <<< "${candidate}"
	IFS=. read -r -a current_parts <<< "${current}"

	for index in 0 1 2; do
		if (( 10#${candidate_parts[index]} > 10#${current_parts[index]} )); then
			return 0
		fi
		if (( 10#${candidate_parts[index]} < 10#${current_parts[index]} )); then
			return 1
		fi
	done

	return 1
}

current_version=$(read_assignment version)
current_pkgrel=$(read_assignment _pkgrel)
current_revision=$(read_assignment revision)
current_artifact=$(read_assignment _artifact)

[[ ${current_version} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	echo "ERROR: invalid version in template: ${current_version}" >&2
	exit 1
}
[[ ${current_pkgrel} =~ ^[0-9]+$ ]] || {
	echo "ERROR: invalid _pkgrel in template: ${current_pkgrel}" >&2
	exit 1
}
[[ ${current_revision} =~ ^[0-9]+$ ]] || {
	echo "ERROR: invalid revision in template: ${current_revision}" >&2
	exit 1
}
[[ ${current_artifact} =~ ^[a-z0-9-]+$ ]] || {
	echo "ERROR: invalid _artifact in template: ${current_artifact}" >&2
	exit 1
}

# NoMachine does not publish a public release API. Its official Personal
# Edition catalog is the authoritative source for the current artifacts.
landing_html=$(curl -fsSL --retry 3 --retry-delay 2 "${LANDING_URL}")
x86_detail_url=$(extract_detail_url "${landing_html}") || {
	echo "ERROR: Linux download page not found in ${LANDING_URL}" >&2
	exit 1
}
arm_detail_url=$(extract_detail_url "${landing_html}" arm) || {
	echo "ERROR: ARM download page not found in ${LANDING_URL}" >&2
	exit 1
}

x86_html=$(curl -fsSL --retry 3 --retry-delay 2 "${x86_detail_url}")
arm_html=$(curl -fsSL --retry 3 --retry-delay 2 "${arm_detail_url}")
x86_upstream_url=$(extract_tarball_url "${x86_html}" Linux x86_64) || {
	echo "ERROR: x86_64 TAR.GZ artifact not found" >&2
	exit 1
}
arm_upstream_url=$(extract_tarball_url "${arm_html}" Arm aarch64) || {
	echo "ERROR: aarch64 TAR.GZ artifact not found" >&2
	exit 1
}

url_pattern='^https://[^/]+/download/([0-9]+\.[0-9]+)/(Linux|Arm)/([a-z0-9-]+)_([0-9]+\.[0-9]+\.[0-9]+)_([0-9]+)_(x86_64|aarch64)\.tar\.gz$'
[[ ${x86_upstream_url} =~ ${url_pattern} ]] || {
	echo "ERROR: unexpected x86_64 artifact URL: ${x86_upstream_url}" >&2
	exit 1
}
x86_series=${BASH_REMATCH[1]}
x86_artifact=${BASH_REMATCH[3]}
x86_version=${BASH_REMATCH[4]}
x86_pkgrel=${BASH_REMATCH[5]}

[[ ${arm_upstream_url} =~ ${url_pattern} ]] || {
	echo "ERROR: unexpected aarch64 artifact URL: ${arm_upstream_url}" >&2
	exit 1
}
arm_series=${BASH_REMATCH[1]}
arm_artifact=${BASH_REMATCH[3]}
arm_version=${BASH_REMATCH[4]}
arm_pkgrel=${BASH_REMATCH[5]}

[[ ${x86_series} == "${x86_version%.*}" ]] || {
	echo "ERROR: x86_64 URL series does not match its version" >&2
	exit 1
}
[[ ${arm_series} == "${arm_version%.*}" ]] || {
	echo "ERROR: aarch64 URL series does not match its version" >&2
	exit 1
}
[[ ${x86_artifact} == "${arm_artifact}" &&
	${x86_version} == "${arm_version}" &&
	${x86_pkgrel} == "${arm_pkgrel}" ]] || {
	echo "ERROR: x86_64 and aarch64 releases do not match" >&2
	exit 1
}

latest_artifact=${x86_artifact}
latest_version=${x86_version}
latest_pkgrel=${x86_pkgrel}

if [[ ${latest_version} == "${current_version}" ]]; then
	if (( 10#${latest_pkgrel} == 10#${current_pkgrel} )); then
		echo "nomachine-player is current: ${current_version}_${current_pkgrel}"
		exit 0
	fi
	if (( 10#${latest_pkgrel} < 10#${current_pkgrel} )); then
		echo "ERROR: upstream package release ${latest_pkgrel} is older than ${current_pkgrel}" >&2
		exit 1
	fi
	new_revision=$((current_revision + 1))
elif version_is_newer "${latest_version}" "${current_version}"; then
	new_revision=1
else
	echo "ERROR: upstream version ${latest_version} is older than ${current_version}" >&2
	exit 1
fi

x86_filename="${latest_artifact}_${latest_version}_${latest_pkgrel}_x86_64.tar.gz"
arm_filename="${latest_artifact}_${latest_version}_${latest_pkgrel}_aarch64.tar.gz"
x86_url="${DOWNLOAD_BASE}/${latest_version%.*}/Linux/${x86_filename}"
arm_url="${DOWNLOAD_BASE}/${latest_version%.*}/Arm/${arm_filename}"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/nomachine-player-update.XXXXXXXX")
trap 'rm -rf -- "${tmpdir}"' EXIT

echo "Downloading ${x86_filename}..."
curl -fL --retry 3 --retry-delay 2 -o "${tmpdir}/${x86_filename}" "${x86_url}"
echo "Downloading ${arm_filename}..."
curl -fL --retry 3 --retry-delay 2 -o "${tmpdir}/${arm_filename}" "${arm_url}"

x86_checksum=$(sha256sum "${tmpdir}/${x86_filename}")
x86_checksum=${x86_checksum%% *}
arm_checksum=$(sha256sum "${tmpdir}/${arm_filename}")
arm_checksum=${arm_checksum%% *}

[[ ${x86_checksum} =~ ^[0-9a-f]{64}$ ]] || {
	echo "ERROR: invalid x86_64 SHA-256" >&2
	exit 1
}
[[ ${arm_checksum} =~ ^[0-9a-f]{64}$ ]] || {
	echo "ERROR: invalid aarch64 SHA-256" >&2
	exit 1
}

updated_template="${tmpdir}/template"
awk -v version="${latest_version}" \
	-v revision="${new_revision}" \
	-v pkgrel="${latest_pkgrel}" \
	-v artifact="${latest_artifact}" \
	-v x86_checksum="${x86_checksum}" \
	-v arm_checksum="${arm_checksum}" '
	BEGIN { checksum_count = 0 }
	/^version=/ { print "version=" version; version_seen = 1; next }
	/^revision=/ { print "revision=" revision; revision_seen = 1; next }
	/^_pkgrel=/ { print "_pkgrel=" pkgrel; pkgrel_seen = 1; next }
	/^_artifact=/ { print "_artifact=" artifact; artifact_seen = 1; next }
	/^checksum=/ {
		checksum_count++
		print "checksum=" x86_checksum
		next
	}
	/^[[:space:]]+checksum=/ {
		checksum_count++
		match($0, /^[[:space:]]*/)
		print substr($0, RSTART, RLENGTH) "checksum=" arm_checksum
		next
	}
	{ print }
	END {
		if (!version_seen || !revision_seen || !pkgrel_seen || !artifact_seen || checksum_count != 2)
			exit 42
	}
' "${TEMPLATE}" > "${updated_template}"

chmod --reference="${TEMPLATE}" "${updated_template}"
mv -f -- "${updated_template}" "${TEMPLATE}"

echo "Updated nomachine-player: ${current_version}_${current_pkgrel} -> ${latest_version}_${latest_pkgrel}"
echo "  x86_64: ${x86_checksum}"
echo "  aarch64: ${arm_checksum}"
