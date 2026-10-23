#!/bin/sh
# Homebar: install the variant for this TV. Run on the TV as root from the
# unpacked release: sh install.sh [options]
#
# Two variants, and the TV gets the one it has the makings for, not the one
# its version number says (see docs/compatibility.md):
#   Home panel  the panel inside LG's own Home: where Home is a QML app and
#               the patch fits it (webOS 4 tested; webOS 3 to 8 have that Home)
#   overlay     an overlay app with a root helper: where Home cannot be
#               patched (webOS 10 tested; webOS 9 and 11 have that Home)
# Options:
#   --home-panel       the Home panel, or fail (no overlay instead)
#   --overlay          the overlay, or fail (needs Input Hook and node 8+)
#   --probe            only say which variant fits and why; change nothing
#   --keep-lg-home     overlay: leave LG's Home in place (no black stand-in)
#   --replace-lg-home  overlay on an untested webOS: put the black stand-in in
#                      LG Home's place anyway (on webOS 10 it always is)
#   --try-webos10      the same as --overlay (older instructions use it)
# HOMEBAR_WEBOS=<version> overrides the detected webOS version (testing).
HERE=$(cd "$(dirname "$0")" && pwd)
HOME_QML=/usr/palm/applications/com.webos.app.home/qml
APPS=/media/developer/apps/usr/palm/applications
HBC=$APPS/../services/org.webosbrew.hbchannel.service
PANEL_BASE=/var/lib/webosbrew/rawin-launcher

say() { echo "rawin-launcher: $*"; }
fail() { echo "rawin-launcher: $*" >&2; exit 1; }
# A check's reasons (one or more lines, some already prefixed), indented.
detail() { printf '%s\n' "$1" | sed 's/^rawin-launcher: //; s/^/rawin-launcher:   /'; }

version=${HOMEBAR_WEBOS:-${RAWIN_LAUNCHER_WEBOS:-$(sed -n 's/.*release \([0-9][0-9.]*\).*/\1/p' /etc/starfish-release 2>/dev/null | head -n 1)}}
major=${version%%.*}
force=
probe=
keep=
replace=
pass=
for a in "$@"; do
    case "$a" in
        --home-panel) force=panel ;;
        --overlay|--try-webos10) force=overlay ;;
        --probe) probe=1 ;;
        --keep-lg-home) keep=1 ;;
        --replace-lg-home) replace=1 ;;
        *) pass="$pass $a" ;;
    esac
done

# Whether LG's Home is a QML app the patch fits. The originals come from the
# firmware, or from the installed copy while its mounts hide them.
panel_why=
panel_fits() {
    [ -f "$HOME_QML/main.qml" ] && [ -f "$HOME_QML/Controllers/UIController.qml" ] ||
        { panel_why="LG Home is not a QML app (no $HOME_QML/main.qml)"; return 1; }
    command -v node >/dev/null || { panel_why="node is missing on this TV"; return 1; }
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
    panel_why=$(node "$HERE/webos4/patch-home.js" --check "$tmp" 2>&1)
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

case "$major" in
    4|10) tested="tested on webOS $major" ;;
    *) tested="untested; webOS 4 and 10 are the tested ones" ;;
esac
say "webOS ${version:-unknown} ($tested)"

if [ -n "$probe" ]; then
    if panel_fits; then say "Home panel: fits"; else say "Home panel: does not fit"; fi
    detail "$panel_why"
    if overlay_fits; then say "overlay: fits"; else say "overlay: does not fit"; fi
    detail "$overlay_why"
    say "probe only; nothing was changed"
    exit 0
fi

variant=$force
if [ -z "$variant" ]; then
    if panel_fits; then variant=panel
    elif overlay_fits; then variant=overlay
    else
        { say "no variant fits this TV"
          say "Home panel: does not fit"; detail "$panel_why"
          say "overlay: does not fit"; detail "$overlay_why"; } >&2
        fail "see docs/compatibility.md; sh install.sh --probe repeats this check"
    fi
fi

case "$variant" in
    panel)
        say "installing the Home panel (the panel inside LG's Home)"
        exec sh "$HERE/webos4/install.sh" $pass
        ;;
    overlay)
        # LG's Home is replaced by the black stand-in on webOS 10, where that is
        # tested; elsewhere it stays unless asked otherwise.
        if [ -n "$keep" ]; then pass="$pass --keep-lg-home"
        elif [ "$major" != 10 ] && [ -z "$replace" ]; then
            say "LG's Home stays in place on this webOS (--replace-lg-home puts the black stand-in there too)"
            pass="$pass --keep-lg-home"
        fi
        say "installing the overlay (an overlay app with a root helper)"
        exec sh "$HERE/webos10/install.sh" $pass
        ;;
esac
