#!/bin/sh
# rawin-launcher diagnostics. Run on the TV as root: sh diagnose.sh
# Collects what is needed to look into a problem into one text file,
# /tmp/rawin-launcher-diagnose.txt, to attach to a GitHub issue. It holds the
# TV model, webOS and firmware versions, which variant fits (probe.sh next to
# this script), what is installed and what the launcher sees (apps, HDMI
# inputs and the device names on them), the launcher's boot log and its lines
# from the system log; no IP addresses, serial numbers or accounts.
OUT=/tmp/rawin-launcher-diagnose.txt
HELPER=http://127.0.0.1:8899
APPS=/media/developer/apps/usr/palm/applications
HERE=$(cd "$(dirname "$0")" && pwd)
PANEL_BASE=/var/lib/webosbrew/rawin-launcher
OVERLAY_BASE=/var/lib/webosbrew/rawin-launcher-home
HOME_QML=/usr/palm/applications/com.webos.app.home/qml

section() { printf '\n== %s\n' "$1"; }
show() { [ -f "$1" ] && cat "$1" || echo "(no $1)"; }
luna() { luna-send -n 1 "$1" "$2" </dev/null 2>&1; echo; }
helper() { wget -q -T 10 -O - "$HELPER$1" 2>&1 || echo "(no answer from the helper)"; echo; }
version_of() { grep -o '"version": *"[^"]*"' "$1/appinfo.json" 2>/dev/null || echo "not installed"; }
# Prints the output of a command, or a note when there is none.
or_note() { out=$("$@" 2>/dev/null); if [ -n "$out" ]; then echo "$out"; else echo "$NOTE"; fi; }

{
    echo "rawin-launcher diagnostics, $(date -u '+%Y-%m-%d %H:%M UTC')"

    section "TV"
    show /etc/starfish-release
    luna luna://com.webos.service.tv.systemproperty/getSystemInfo '{"keys":["modelName","firmwareVersion","sdkVersion"]}'
    luna luna://com.webos.service.tv.systemproperty/getSystemInfo '{"keys":["UHD"]}'
    echo "framebuffer: $(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo unknown)"
    echo "node: $(node -v 2>&1)"
    echo "qml-runner: $(command -v qml-runner || echo missing)"
    echo "Homebrew Channel: $(version_of $APPS/org.webosbrew.hbchannel)"
    echo "Input Hook: $(version_of $APPS/org.webosbrew.inputhook)"

    # Which variant fits this TV: probe.sh is in the release next to install.sh
    # and installed next to this script, with patch-home.js.
    section "Variants (probe.sh)"
    if [ -f "$HERE/probe.sh" ]; then sh "$HERE/probe.sh" 2>&1
    else echo "(no probe.sh next to this script; a release from 0.13.0 on has it)"; fi

    section "rawin-launcher"
    for d in "$PANEL_BASE" "$OVERLAY_BASE"; do
        [ -d "$d" ] && { echo "$d: version $(cat "$d/VERSION" 2>/dev/null || echo '?')"; ls "$d"; }
    done
    echo "overlay app: $(version_of $APPS/org.rawin.launcher)"
    echo "boot hooks: $(ls /var/lib/webosbrew/init.d 2>/dev/null | tr '\n' ' ')"

    section "LG Home"
    luna luna://com.webos.applicationManager/getAppInfo '{"id":"com.webos.app.home"}' | grep -o -E '"(type|version|main)": *"[^"]*"'
    echo "Home QML: $(ls $HOME_QML/main.qml 2>/dev/null || echo none)"
    # The Home panel: LG reads our patched copies only while they are mounted
    # over the firmware files.
    if [ -f "$PANEL_BASE/main.qml" ]; then
        if cmp -s "$PANEL_BASE/main.qml" "$HOME_QML/main.qml" && cmp -s "$PANEL_BASE/UIController.qml" "$HOME_QML/Controllers/UIController.qml"; then
            echo "patched Home QML in place: yes"
        else
            echo "patched Home QML in place: no (the boot hook did not mount it, or LG Home changed)"
        fi
    fi
    [ -f "$OVERLAY_BASE/takeover.sh" ] && sh "$OVERLAY_BASE/takeover.sh" status
    grep -F com.webos.app.home /proc/mounts

    section "Helper (overlay)"
    if [ -d "$OVERLAY_BASE" ] || [ -d "$APPS/org.rawin.launcher" ]; then
        helper /ping
        helper /home
        helper /state
        echo "apps listed: $(wget -q -T 20 -O - "$HELPER/apps" 2>/dev/null | grep -o '"id":' | wc -l)"
        helper /foreground
        helper /inputs
    else
        echo "(Home panel: no helper; the panel talks to the TV from inside LG Home)"
    fi

    section "HOME button (Input Hook)"
    show /home/root/.config/lginputhook/keybinds.json
    echo
    for f in /tmp/lginput-hook-*.log; do [ -f "$f" ] && { echo "-- $f"; grep -v 'Keybinds reloaded' "$f" | tail -n 8; }; done

    # The boot hooks note each step with the seconds since boot; the file is
    # cleared with /tmp at every boot.
    section "Boot log ($(cut -d' ' -f1 /proc/uptime)s since boot)"
    show /tmp/rawin-launcher-boot.log

    section "Install and update logs"
    for f in /tmp/rawin-launcher-install.log /tmp/rawin-launcher-update/install.log; do
        [ -f "$f" ] && { echo "-- $f"; tail -n 30 "$f"; }
    done
    show /tmp/rawin-launcher-update/state

    # The overlay's qml-runner carries org.rawin.launcher in its arguments and
    # the helper runs from org.rawin.launcher.service; LG's own QML apps use
    # qml-runner too, so only "rawin" tells ours apart.
    section "Processes"
    NOTE="(none of the launcher's own; the Home panel runs inside LG Home's process)"
    or_note sh -c "ps -ef 2>/dev/null | grep -F rawin | grep -v -E 'grep|diagnose'"

    # The launcher's own messages and errors, not the list of launched apps.
    section "System log (rawin-launcher lines)"
    NOTE="(none in /var/log/messages; on webOS 10 logger lines do not reach it: see Boot log)"
    or_note sh -c "cat /var/log/messages* 2>/dev/null | grep -i -E 'rawin' | grep -v -E 'NL_(VSC|SOUND|APP_LAUNCH_BEGIN|APP_INSTALLED)' | tail -n 40"
} >"$OUT" 2>&1

echo "rawin-launcher: diagnostics written to $OUT"
echo "rawin-launcher: copy it to a computer with: ssh root@<tv-ip> cat $OUT > rawin-launcher-diagnose.txt"
