#!/bin/bash
# Auto-updater for slack-desktop (via official release feed)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Slack Desktop version from release feed..."

FEED_URL="https://slack.com/release-notes/linux/rss"
FEED=$(curl -fsSL "$FEED_URL") || {
    echo "ERROR: Failed to fetch release feed" >&2
    exit 1
}

LATEST=$(echo "$FEED" | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read())
channel = root.find('channel')
if channel is None:
    raise SystemExit(1)
item = channel.find('item')
if item is None:
    raise SystemExit(1)
title = item.find('title').text
# Формат: 'Slack 4.49.89'
import re
m = re.search(r'(\d+\.\d+\.\d+)', title)
if m:
    print(m.group(1))
" 2>/dev/null) || {
    echo "ERROR: Could not parse release feed" >&2
    exit 1
}

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "slack-desktop: ${CURRENT} — already up to date"
    exit 0
fi

echo "slack-desktop: ${CURRENT} → ${LATEST}"

DEB_URL="https://downloads.slack-edge.com/desktop-releases/linux/x64/${LATEST}/slack-desktop-${LATEST}-amd64.deb"
echo "URL: ${DEB_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DEB_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal file layout hasn't changed."