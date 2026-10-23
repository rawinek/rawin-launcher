#!/bin/sh
# Homebar: install the variant for this TV. Run on the TV as root from the
# unpacked release: sh install.sh [options]
#
# Two variants, and the TV gets the one it has the makings for, not the one
# its version number says (probe.sh decides; see docs/compatibility.md):
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
PROBE=$HERE/probe.sh

say() { echo "rawin-launcher: $*"; }
fail() { echo "rawin-launcher: $*" >&2; exit 1; }
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

case "$major" in
    4|10) tested="tested on webOS $major" ;;
    *) tested="untested; webOS 4 and 10 are the tested ones" ;;
esac
say "webOS ${version:-unknown} ($tested)"

if [ -n "$probe" ]; then
    sh "$PROBE"
    say "probe only; nothing was changed"
    exit 0
fi

variant=$force
if [ -z "$variant" ]; then
    if panel_why=$(sh "$PROBE" panel 2>&1); then variant=panel
    elif overlay_why=$(sh "$PROBE" overlay 2>&1); then variant=overlay
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
