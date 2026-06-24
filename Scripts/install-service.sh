#!/bin/bash
# Installs the SiteBlocker background enforcement service. Runs as root (invoked either via
# `sudo` from the CLI, or through the app's authenticated prompt). It:
#   1. copies the helper into a root-owned location,
#   2. ensures the user's config file exists,
#   3. installs a LaunchDaemon that runs the helper every minute (even when the app is closed),
#   4. loads it and applies the schedule immediately.
#
# The helper is told where to read config via SITEBLOCKER_CONFIG baked into the daemon plist,
# pointing at the *logged-in user's* home so the GUI can write it without privileges.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "install-service.sh must run as root (use sudo or the app's Enable button)." >&2
    exit 1
fi

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_SRC="$SELF_DIR/site-blocker-helper"

LABEL="com.siteblocker.helper"
SUPPORT="/Library/Application Support/SiteBlocker"
DEST_HELPER="$SUPPORT/site-blocker-helper"
DAEMON="/Library/LaunchDaemons/$LABEL.plist"
LOG="$SUPPORT/helper.log"

if [ ! -x "$HELPER_SRC" ] && [ ! -f "$HELPER_SRC" ]; then
    echo "Helper binary not found next to installer: $HELPER_SRC" >&2
    exit 1
fi

# Resolve the logged-in (console) user and their real home directory.
CONSOLE_USER="$(stat -f%Su /dev/console)"
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ]; then
    CONSOLE_USER="${SUDO_USER:-$CONSOLE_USER}"
fi
USER_HOME="$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
USER_HOME="${USER_HOME:-/Users/$CONSOLE_USER}"

USER_SUPPORT="$USER_HOME/Library/Application Support/SiteBlocker"
CONFIG="$USER_SUPPORT/config.json"

echo "Installing SiteBlocker service for user: $CONSOLE_USER"

# 1. Root-owned support dir + helper.
mkdir -p "$SUPPORT"
chown root:wheel "$SUPPORT"
chmod 755 "$SUPPORT"
install -m 755 -o root -g wheel "$HELPER_SRC" "$DEST_HELPER"

# 2. Ensure the user's config exists and is user-owned.
mkdir -p "$USER_SUPPORT"
chown "$CONSOLE_USER" "$USER_SUPPORT"
if [ ! -f "$CONFIG" ]; then
    printf '{\n  "sites" : [],\n  "version" : 1\n}\n' > "$CONFIG"
    chown "$CONSOLE_USER" "$CONFIG"
fi

# 3. Write the LaunchDaemon plist.
cat > "$DAEMON" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEST_HELPER</string>
        <string>reconcile</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SITEBLOCKER_CONFIG</key>
        <string>$CONFIG</string>
    </dict>
    <key>WatchPaths</key>
    <array>
        <string>$CONFIG</string>
        <string>$USER_SUPPORT</string>
    </array>
    <key>StartInterval</key>
    <integer>20</integer>
    <key>ThrottleInterval</key>
    <integer>1</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLIST
chown root:wheel "$DAEMON"
chmod 644 "$DAEMON"

# 4. (Re)load and apply immediately.
launchctl bootout "system/$LABEL" 2>/dev/null || true
launchctl bootstrap system "$DAEMON"
launchctl kickstart -k "system/$LABEL" 2>/dev/null || true

echo "SiteBlocker service installed and running (config: $CONFIG)."
