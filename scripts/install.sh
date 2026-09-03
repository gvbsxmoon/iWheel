#!/bin/bash
# One-shot local install: builds iWheel, replaces the copy in /Applications,
# and handles the TCC permission dance so you never do it by hand.
# Run it from YOUR terminal: it may ask for sudo (signing cert, first time)
# and deletes the previously installed app.
#
# What it does:
#   1. ensures the stable "iWheel Local Dev" signing identity exists
#      (creates it via make-signing-cert.sh on first run)
#   2. builds build/iWheel.app (scripts/release.sh)
#   3. quits the running iWheel, replaces /Applications/iWheel.app
#   4. resets the app's TCC permissions ONLY if the code signature changed
#      (with the stable identity this happens once, then never again)
#   5. relaunches the app
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="dev.lucanatale.iWheel"
INSTALLED="/Applications/iWheel.app"
BUILT="build/iWheel.app"

# 1. Stable signing identity, so permissions survive future rebuilds.
if ! security find-identity -p codesigning -v 2>/dev/null | grep -q "iWheel Local Dev"; then
    echo "==> No stable signing identity yet - creating it (one time)"
    scripts/make-signing-cert.sh
fi

# 2. Build.
echo "==> Building"
scripts/release.sh >/dev/null
NEW_REQ=$(codesign -dr - "$BUILT" 2>&1 | grep "designated =>" || true)

# 3. Compare signatures BEFORE replacing, to decide on the TCC reset.
NEEDS_TCC_RESET=1
if [ -d "$INSTALLED" ]; then
    OLD_REQ=$(codesign -dr - "$INSTALLED" 2>&1 | grep "designated =>" || true)
    if [ -n "$OLD_REQ" ] && [ "$OLD_REQ" = "$NEW_REQ" ]; then
        NEEDS_TCC_RESET=0
    fi
fi

# 4. Swap the installed copy.
echo "==> Installing to /Applications"
killall iWheel 2>/dev/null || true
rm -rf "$INSTALLED"
ditto "$BUILT" "$INSTALLED"

# 5. Reset permissions only when the signature actually changed.
if [ "$NEEDS_TCC_RESET" = "1" ]; then
    echo "==> Code signature changed - resetting permissions (re-grant once at launch)"
    tccutil reset All "$BUNDLE_ID" >/dev/null 2>&1 || true
else
    echo "==> Same signature - permissions preserved, no re-grant needed"
fi

open "$INSTALLED"
echo "Done."
