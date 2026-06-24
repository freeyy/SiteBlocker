#!/bin/bash
# End-to-end test of the helper's reconcile pipeline against temp files (no root needed).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

build_core

echo "▸ building helper"
swiftc "${COMMON_FLAGS[@]}" -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/$HELPER_NAME" \
    "$SOURCES/$HELPER_NAME"/*.swift

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CONFIG="$WORK/config.json"
HOSTS="$WORK/hosts"
HELPER="$BUILD/$HELPER_NAME"

export SITEBLOCKER_CONFIG="$CONFIG"
export SITEBLOCKER_HOSTS="$HOSTS"
export SITEBLOCKER_NO_FLUSH=1

fails=0
assert_contains() { # file needle desc
    if grep -qF "$2" "$1"; then echo "  ✓ $3"; else echo "  ✗ $3 (missing: $2)"; fails=$((fails+1)); fi
}
assert_absent() {
    if grep -qF "$2" "$1"; then echo "  ✗ $3 (unexpected: $2)"; fails=$((fails+1)); else echo "  ✓ $3"; fi
}

# Baseline hosts file the system would normally have.
printf '127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost\n' > "$HOSTS"

echo "▸ case 1: an always-on block is applied"
cat > "$CONFIG" <<'JSON'
{
  "version": 1,
  "sites": [
    { "id": "11111111-1111-1111-1111-111111111111", "domain": "example.com",
      "isEnabled": true, "days": [1,2,3,4,5,6,7], "ranges": [] }
  ]
}
JSON
"$HELPER" reconcile
assert_contains "$HOSTS" "$(printf '127.0.0.1\texample.com')" "blocks example.com"
assert_contains "$HOSTS" "$(printf '127.0.0.1\twww.example.com')" "blocks www.example.com"
assert_contains "$HOSTS" "::1" "adds IPv6 entry"
assert_contains "$HOSTS" "localhost" "preserves base content"

echo "▸ case 2: reconcile is idempotent"
BEFORE="$(cat "$HOSTS")"
"$HELPER" reconcile
AFTER="$(cat "$HOSTS")"
if [ "$BEFORE" = "$AFTER" ]; then echo "  ✓ second reconcile leaves hosts unchanged"; else echo "  ✗ hosts changed on idempotent reconcile"; fails=$((fails+1)); fi

echo "▸ case 3: status reports the active domain"
"$HELPER" status | grep -qF "example.com" && echo "  ✓ status lists example.com" || { echo "  ✗ status missing example.com"; fails=$((fails+1)); }

echo "▸ case 4: disabling the site removes the managed section"
cat > "$CONFIG" <<'JSON'
{
  "version": 1,
  "sites": [
    { "id": "11111111-1111-1111-1111-111111111111", "domain": "example.com",
      "isEnabled": false, "days": [1,2,3,4,5,6,7], "ranges": [] }
  ]
}
JSON
"$HELPER" reconcile
assert_absent "$HOSTS" "example.com" "removes example.com"
assert_contains "$HOSTS" "localhost" "still preserves base content"
assert_absent "$HOSTS" "SiteBlocker managed" "removes managed markers"

echo "▸ case 5: clear command is a no-op when nothing is managed"
"$HELPER" clear
assert_contains "$HOSTS" "localhost" "clear keeps base content"

echo "▸ case 6: a config with a leftover isBlockingEnabled key still blocks (backward compat)"
cat > "$CONFIG" <<'JSON'
{
  "version": 1, "isBlockingEnabled": false, "blockSecureDNS": false,
  "sites": [
    { "id": "11111111-1111-1111-1111-111111111111", "domain": "example.com",
      "isEnabled": true, "days": [1,2,3,4,5,6,7], "ranges": [] }
  ]
}
JSON
"$HELPER" reconcile
assert_contains "$HOSTS" "example.com" "removed isBlockingEnabled key is ignored; site still blocks"

echo "▸ case 7: Secure DNS option blocks DoH resolvers while a site is active"
cat > "$CONFIG" <<'JSON'
{
  "version": 1, "blockSecureDNS": true,
  "sites": [
    { "id": "11111111-1111-1111-1111-111111111111", "domain": "example.com",
      "isEnabled": true, "days": [1,2,3,4,5,6,7], "ranges": [] }
  ]
}
JSON
"$HELPER" reconcile
assert_contains "$HOSTS" "$(printf '127.0.0.1\texample.com')" "blocks the site"
assert_contains "$HOSTS" "dns.google" "blocks a DoH resolver (dns.google)"
assert_contains "$HOSTS" "cloudflare-dns.com" "blocks a DoH resolver (cloudflare)"

echo "▸ case 8: Secure DNS resolvers are NOT blocked when nothing is active"
cat > "$CONFIG" <<'JSON'
{
  "version": 1, "blockSecureDNS": true,
  "sites": [
    { "id": "11111111-1111-1111-1111-111111111111", "domain": "example.com",
      "isEnabled": false, "days": [1,2,3,4,5,6,7], "ranges": [] }
  ]
}
JSON
"$HELPER" reconcile
assert_absent "$HOSTS" "dns.google" "no DoH block when nothing active"

echo
if [ "$fails" -eq 0 ]; then
    echo "✓ integration tests passed"
else
    echo "✗ $fails integration assertion(s) failed"; exit 1
fi
