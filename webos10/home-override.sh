#!/bin/sh
# Experiment (overlay, webOS 10): the LG Home stand-in installed as a
# developer package with a higher version than the firmware's Home. If the
# app manager takes it the way it takes LG's own updates of built-in apps,
# the stand-in is LG's Home from the first second of a boot, with nothing to
# mount. Run on the TV as root with the IPK next to it (tools/build-home-override.py
# makes both, in dist/home-override/):
#   sh home-override.sh install   install the package; say what the app manager
#                                 took (an answer within a minute)
#   sh home-override.sh status    what the app manager reports for Home now
#   sh home-override.sh remove    remove the package; LG's Home as before
# Nothing of the launcher's install is changed. The bind-mount stand-in is
# left alone too; takeover.sh restore gives LG's Home back for a clean look,
# and a keep-lg-home file keeps the boot hook from mounting it again.
HOME_ID=com.webos.app.home
HERE=$(cd "$(dirname "$0")" && pwd)
DEVDIR=/media/developer/apps/usr/palm/applications/$HOME_ID
LOG=/tmp/rawin-home-override.log

say() { echo "home-override: $*"; }
fail() { echo "home-override: $*" >&2; exit 1; }
luna() { luna-send -n 1 "$1" "$2" </dev/null 2>&1; }

# What the app manager reports for Home: where it reads it from, its type
# and version; then the developer copy and the bind mount, if any.
status() {
    luna luna://com.webos.applicationManager/getAppInfo "{\"id\":\"$HOME_ID\"}" |
        tr -d '\n' | grep -o -E '"(folderPath|type|version|main|title)": *"[^"]*"' | tr '\n' ' '
    echo
    [ -d "$DEVDIR" ] && echo "developer copy: $DEVDIR ($(grep -o '"version": *"[^"]*"' "$DEVDIR/appinfo.json" 2>/dev/null))" ||
        echo "developer copy: none"
    grep -F " /usr/palm/applications/$HOME_ID " /proc/mounts >/dev/null && echo "bind mount: stand-in mounted" || echo "bind mount: none"
    if [ -d "$DEVDIR" ]; then
        if luna luna://com.webos.applicationManager/getAppInfo "{\"id\":\"$HOME_ID\"}" | grep -q "$DEVDIR"; then
            echo "verdict: the app manager reads Home from the developer copy"
        else
            echo "verdict: the app manager does not read Home from the developer copy"
        fi
    fi
}

# Runs one appInstallService call with a subscription until a state is
# reached; the call's output stays in $LOG.
install_call() {
    : >"$LOG"
    luna-send -i -a com.webos.appInstallService "luna://com.webos.appInstallService/dev/$1" "$2" </dev/null >"$LOG" 2>&1 &
    PID=$!
    n=0
    until tr -d ' ' <"$LOG" | grep -q "\"state\":\"$3\""; do
        if tr -d ' ' <"$LOG" | grep -q -E '"state":"(installfailed|removefailed|failed)"|errorText|"returnValue":false'; then
            kill $PID 2>/dev/null; cat "$LOG" >&2; return 1
        fi
        n=$((n + 1)); [ $n -lt 90 ] || { kill $PID 2>/dev/null; cat "$LOG" >&2; return 1; }
        sleep 1
    done
    kill $PID 2>/dev/null
    return 0
}

case "$1" in
    install)
        [ "$(id -u)" = 0 ] || fail "run this as root on the TV"
        IPK=$(ls "$HERE"/${HOME_ID}_*_all.ipk 2>/dev/null | head -n 1)
        [ -n "$IPK" ] || fail "no ${HOME_ID}_*_all.ipk next to this script"
        say "before:"; status
        cp "$IPK" /tmp/rawin-home-override.ipk
        say "installing $(basename "$IPK")"
        if install_call install "{\"id\":\"$HOME_ID\",\"ipkUrl\":\"/tmp/rawin-home-override.ipk\",\"subscribe\":true}" installed; then
            say "installed"
        else
            say "the install was refused or failed (output above); nothing to undo"
            rm -f /tmp/rawin-home-override.ipk
            exit 1
        fi
        rm -f /tmp/rawin-home-override.ipk
        sleep 2
        say "after:"; status
        ;;
    status)
        status
        ;;
    remove)
        [ "$(id -u)" = 0 ] || fail "run this as root on the TV"
        [ -d "$DEVDIR" ] || { say "no developer copy of Home; nothing to remove"; status; exit 0; }
        say "removing the developer copy"
        if install_call remove "{\"id\":\"$HOME_ID\",\"subscribe\":true}" removed; then
            say "removed"
        else
            say "the remove call failed (output above)"
        fi
        if [ -d "$DEVDIR" ]; then
            say "the developer copy is still there; removing its files"
            rm -rf "$DEVDIR" "/media/developer/apps/usr/palm/packages/$HOME_ID"
        fi
        sleep 2
        say "after:"; status
        ;;
    *)
        echo "usage: $0 install|status|remove" >&2
        exit 2
        ;;
esac
