#!/bin/sh
# rawin-launcher diagnostics. Run on the TV as root: sh diagnose.sh
# Collects what is needed to look into a problem into one text file,
# /tmp/rawin-launcher-diagnose.txt, to attach to a GitHub issue. It holds the
# TV model, webOS and firmware versions, what is installed and what the launcher
# sees (apps, HDMI inputs and the device names on them), and the launcher's
# lines from the system log; no IP addresses, serial numbers or accounts.
OUT=/tmp/rawin-launcher-diagnose.txt
HELPER=http://127.0.0.1:8899
APPS=/media/developer/apps/usr/palm/applications

section() { printf '\n== %s\n' "$1"; }
show() { [ -f "$1" ] && cat "$1" || echo "(no $1)"; }
luna() { luna-send -n 1 "$1" "$2" </dev/null 2>&1; echo; }
helper() { wget -q -T 10 -O - "$HELPER$1" 2>&1 || echo "(no answer from the helper)"; echo; }
version_of() { grep -o '"version": *"[^"]*"' "$1/appinfo.json" 2>/dev/null || echo "not installed"; }

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

    # Which variant fits this TV, from the release's installer (not installed
    # with the launcher; present when run from the unpacked release).
    section "Variants (install.sh --probe)"
    HERE=$(cd "$(dirname "$0")" && pwd)
    if [ -f "$HERE/install.sh" ] && [ -f "$HERE/webos4/patch-home.js" ]; then sh "$HERE/install.sh" --probe 2>&1
    else echo "(run from the unpacked release for this)"; fi

    section "rawin-launcher"
    for d in /var/lib/webosbrew/rawin-launcher /var/lib/webosbrew/rawin-launcher-home; do
        [ -d "$d" ] && { echo "$d: version $(cat "$d/VERSION" 2>/dev/null || echo '?')"; ls "$d"; }
    done
    echo "overlay app: $(version_of $APPS/org.rawin.launcher)"
    echo "boot hooks: $(ls /var/lib/webosbrew/init.d 2>/dev/null | tr '\n' ' ')"

    section "LG Home"
    luna luna://com.webos.applicationManager/getAppInfo '{"id":"com.webos.app.home"}' | grep -o -E '"(type|version|main)": *"[^"]*"'
    echo "Home QML: $(ls /usr/palm/applications/com.webos.app.home/qml/main.qml 2>/dev/null || echo none)"
    [ -f /var/lib/webosbrew/rawin-launcher-home/takeover.sh ] && sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh status
    grep -F com.webos.app.home /proc/mounts

    section "Helper (webOS 10 variant)"
    helper /ping
    helper /home
    helper /state
    echo "apps listed: $(wget -q -T 20 -O - "$HELPER/apps" 2>/dev/null | grep -o '"id":' | wc -l)"
    helper /foreground
    helper /inputs

    section "HOME button (Input Hook)"
    show /home/root/.config/lginputhook/keybinds.json
    echo
    for f in /tmp/lginput-hook-*.log; do [ -f "$f" ] && { echo "-- $f"; grep -v 'Keybinds reloaded' "$f" | tail -n 8; }; done

    section "Install and update logs"
    for f in /tmp/rawin-launcher-install.log /tmp/rawin-launcher-update/install.log; do
        [ -f "$f" ] && { echo "-- $f"; tail -n 30 "$f"; }
    done
    show /tmp/rawin-launcher-update/state

    section "Processes"
    ps -ef 2>/dev/null | grep -E 'rawin|qml-runner' | grep -v -E 'grep|diagnose'

    # The launcher's own messages and errors, not the list of launched apps.
    section "System log (rawin-launcher lines)"
    cat /var/log/messages* 2>/dev/null | grep -i -E 'rawin' |
        grep -v -E 'NL_(VSC|SOUND|APP_LAUNCH_BEGIN|APP_INSTALLED)' | tail -n 40
} >"$OUT" 2>&1

echo "rawin-launcher: diagnostics written to $OUT"
echo "rawin-launcher: copy it to a computer with: ssh root@<tv-ip> cat $OUT > rawin-launcher-diagnose.txt"
