#!/bin/sh
# Homebar: which variant fits this TV, and why. Changes nothing. Run on the
# TV as root:
#   sh probe.sh            the report for both variants (what install.sh --probe shows)
#   sh probe.sh panel      exit 0 when the Home panel fits; the reasons on stdout
#   sh probe.sh overlay    the same for the overlay
# The release holds it next to install.sh, which uses it; the installers put
# it next to diagnose.sh, with patch-home.js, so an installed TV can run it.
HERE=$(cd "$(dirname "$0")" && pwd)
HOME_QML=/usr/palm/applications/com.webos.app.home/qml
APPS=/media/developer/apps/usr/palm/applications
HBC=/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service
PANEL_BASE=/var/lib/webosbrew/rawin-launcher
# patch-home.js: in webos4/ in the release, next to this script once installed.
PATCH=$HERE/webos4/patch-home.js
[ -f "$PATCH" ] || PATCH=$HERE/patch-home.js

say() { echo "rawin-launcher: $*"; }
# A check's reasons (one or more lines, some already prefixed), indented.
detail() { printf '%s\n' "$1" | sed 's/^rawin-launcher: //; s/^/rawin-launcher:   /'; }

# Whether LG's Home is a QML app the patch fits. The originals come from the
# firmware, or from the installed copy while its mounts hide them;
# SystemProperties.qml (where Home declares isAppForeground) is only read.
panel_why=
panel_fits() {
    [ -f "$HOME_QML/main.qml" ] && [ -f "$HOME_QML/Controllers/UIController.qml" ] ||
        { panel_why="LG Home is not a QML app (no $HOME_QML/main.qml)"; return 1; }
    command -v node >/dev/null || { panel_why="node is missing on this TV"; return 1; }
    [ -f "$PATCH" ] || { panel_why="patch-home.js is missing next to this script"; return 1; }
    tmp=$(mktemp -d)
    if grep -qF " $HOME_QML/main.qml " /proc/mounts || grep -qF " $HOME_QML/Controllers/UIController.qml " /proc/mounts; then
        if [ -f "$PANEL_BASE/main.original.qml" ] && [ -f "$PANEL_BASE/UIController.original.qml" ]; then
            cp "$PANEL_BASE/main.original.qml" "$PANEL_BASE/UIController.original.qml" "$tmp/"
        else
            rm -rf "$tmp"; panel_why="LG Home is already replaced by something else; restore it first"; return 1
        fi
    else
        cp "$HOME_QML/main.qml" "$tmp/main.original.qml"
        cp "$HOME_QML/Controllers/UIController.qml" "$tmp/UIController.original.qml"
    fi
    [ -f "$HOME_QML/AppInitializer/SystemProperties.qml" ] && cp "$HOME_QML/AppInitializer/SystemProperties.qml" "$tmp/SystemProperties.original.qml"
    panel_why=$(node "$PATCH" --check "$tmp" 2>&1)
    r=$?
    rm -rf "$tmp"
    return $r
}
# Whether the overlay and its helper have what they need.
overlay_why=
overlay_fits() {
    [ -x "$HBC/elevate-service" ] || { overlay_why="the Homebrew Channel (root) is not set up on this TV"; return 1; }
    [ -d "$APPS/org.webosbrew.inputhook" ] ||
        { overlay_why="the Input Hook app is not installed (Homebrew Channel); it sends the HOME button to the launcher"; return 1; }
    command -v node >/dev/null || { overlay_why="node is missing on this TV"; return 1; }
    node -e 'process.exit(parseInt(process.versions.node, 10) >= 8 ? 0 : 1)' 2>/dev/null ||
        { overlay_why="the helper needs node 8 or newer; this TV has node $(node -v 2>/dev/null)"; return 1; }
    overlay_why="the Homebrew Channel, Input Hook and node $(node -v 2>/dev/null) are there"
    return 0
}

case "$1" in
    panel) panel_fits; r=$?; printf '%s\n' "$panel_why"; exit $r ;;
    overlay) overlay_fits; r=$?; printf '%s\n' "$overlay_why"; exit $r ;;
    "")
        if panel_fits; then say "Home panel: fits"; else say "Home panel: does not fit"; fi
        detail "$panel_why"
        if overlay_fits; then say "overlay: fits"; else say "overlay: does not fit"; fi
        detail "$overlay_why"
        ;;
    *) echo "usage: $0 [panel|overlay]" >&2; exit 2 ;;
esac
