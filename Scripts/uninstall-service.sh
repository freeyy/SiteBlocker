#!/bin/bash
# Removes the SiteBlocker background service and clears any active blocks from /etc/hosts.
# Runs as root. The user's config file is left in place so re-enabling restores the schedule.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "uninstall-service.sh must run as root (use sudo or the app's Disable button)." >&2
    exit 1
fi

LABEL="com.siteblocker.helper"
SUPPORT="/Library/Application Support/SiteBlocker"
DEST_HELPER="$SUPPORT/site-blocker-helper"
DAEMON="/Library/LaunchDaemons/$LABEL.plist"

# Stop the daemon.
launchctl bootout "system/$LABEL" 2>/dev/null || true

# Remove the managed section from /etc/hosts so nothing stays blocked (and flush DNS).
if [ -x "$DEST_HELPER" ]; then
    "$DEST_HELPER" clear || true
fi

# Remove daemon + root-owned files (leave the user's config.json untouched).
rm -f "$DAEMON"
rm -rf "$SUPPORT"

echo "SiteBlocker service removed."
