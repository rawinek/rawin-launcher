#!/bin/sh
# Homebar installer, the overlay variant (an overlay app with a root helper;
# webOS 10 tested). Run on the TV as root, from the unpacked release:
# sh webos10/install.sh, or sh install.sh, which picks the variant.
#   --keep-lg-home     leave LG's Home in place (no black stand-in); without the
#                      stand-in LG Home may show briefly when an app exits
#   --replace-lg-home  the stand-in in LG Home's place (the default here)
#   --home-key=CODE    bind this key code as HOME (Input Hook's number for it)
#   --home-key=ask     ask for a press of HOME, also when a key is already bound
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
UI=$HERE/../ui
APP=org.rawin.launcher
SERVICE=$APP.service
APPDIR=/media/developer/apps/usr/palm/applications/$APP
HBC=/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service
BASE=/var/lib/webosbrew/rawin-launcher-home
HOOK=/var/lib/webosbrew/init.d/10-rawin-launcher   # before Glasshouse's 20-/50-tvweb hooks
KEYS=/home/root/.config/lginputhook/keybinds.json
HOME_KEY=773   # the remote's HOME button as Input Hook reports it

KEEP_LG_HOME=
HOME_KEY_OPT=
for a in "$@"; do
    case "$a" in
        --keep-lg-home) KEEP_LG_HOME=1 ;;
        --replace-lg-home) KEEP_LG_HOME= ;;
        --home-key=*) HOME_KEY_OPT=${a#--home-key=} ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

say() { echo "rawin-launcher: $*"; }
fail() { echo "rawin-launcher: $*" >&2; exit 1; }
luna() { luna-send -n 1 "$1" "$2" </dev/null 2>/dev/null; }

[ "$(id -u)" = 0 ] || fail "run this as root on the TV"
[ -x "$HBC/elevate-service" ] || fail "the Homebrew Channel (root) is not set up on this TV"
[ -d /media/developer/apps/usr/palm/applications/org.webosbrew.inputhook ] ||
    fail "install 'Input Hook' from the Homebrew Channel first: it sends the HOME button to the launcher"
command -v node >/dev/null || fail "node is missing on this TV"
node -e 'process.exit(parseInt(process.versions.node, 10) >= 8 ? 0 : 1)' 2>/dev/null ||
    fail "the helper needs node 8 or newer; this TV has node $(node -v 2>/dev/null) (the Home panel may fit instead: sh install.sh --home-panel)"
IPK=$(ls "$HERE"/org.rawin.launcher_*_all.ipk 2>/dev/null | head -n 1)
[ -n "$IPK" ] || fail "no org.rawin.launcher IPK next to this script"

say "installing $(basename "$IPK")"
cp "$IPK" /tmp/rawin-launcher.ipk
LOG=/tmp/rawin-launcher-install.log
: >"$LOG"   # before the loop below reads it
luna-send -i -a com.webos.appInstallService luna://com.webos.appInstallService/dev/install \
    '{"id":"org.rawin.launcher","ipkUrl":"/tmp/rawin-launcher.ipk","subscribe":true}' </dev/null >"$LOG" 2>&1 &
PID=$!
n=0
until tr -d ' ' <"$LOG" | grep -q '"state":"installed"'; do
    tr -d ' ' <"$LOG" | grep -q -E '"state":"(installfailed|failed)"|errorText' && { kill $PID 2>/dev/null; cat "$LOG" >&2; fail "install failed"; }
    n=$((n + 1)); [ $n -lt 120 ] || { kill $PID 2>/dev/null; fail "install timed out"; }
    sleep 1
done
kill $PID 2>/dev/null || true
rm -f /tmp/rawin-launcher.ipk "$LOG"
# The TV's webOS version, shown in the panel's corner with the variant.
webos=$(sed -n 's/.*release \([0-9][0-9.]*\).*/\1/p' /etc/starfish-release 2>/dev/null | head -n 1)
[ -f "$APPDIR/Config.js" ] && sed -i "s/^var webos = .*/var webos = \"$webos\";/" "$APPDIR/Config.js"

say "giving the helper root (Homebrew elevate-service)"
"$HBC/elevate-service" "$SERVICE" >/dev/null 2>&1 || fail "elevate-service failed"

say "staging the LG Home stand-in in $BASE"
mkdir -p "$BASE/app"
cp "$HERE"/home-stub/* "$BASE/app/"
cp "$UI/icon.png" "$BASE/app/icon.png"
cp "$HERE/home-takeover.sh" "$BASE/takeover.sh"
cp "$HERE/uninstall.sh" "$BASE/uninstall.sh"
cp "$HERE/../update.sh" "$HERE/../diagnose.sh" "$HERE/../VERSION" "$BASE/"
# The probe (which variant fits) next to diagnose.sh, with the patch it checks with.
cp "$HERE/../probe.sh" "$HERE/../webos4/patch-home.js" "$BASE/"
chmod 755 "$BASE/takeover.sh" "$BASE/uninstall.sh" "$BASE/update.sh" "$BASE/probe.sh"
if [ -n "$KEEP_LG_HOME" ]; then
    touch "$BASE/keep-lg-home"
    sh "$BASE/takeover.sh" restore >/dev/null 2>&1 || true
else
    rm -f "$BASE/keep-lg-home"
    # Here and not only from the boot hook, which runs it in the background:
    # over SSH that could end with the session, before LG's Home is stopped.
    say "LG Home -> black stand-in"
    sh "$BASE/takeover.sh" apply >/dev/null 2>&1 || say "LG Home kept: the app manager did not take the stand-in"
fi

say "HOME button -> rawin-launcher (Input Hook)"
mkdir -p "$(dirname "$KEYS")"
[ -f "$KEYS" ] || echo '{}' > "$KEYS"
[ -f "$KEYS.before-rawin-launcher" ] || cp -p "$KEYS" "$KEYS.before-rawin-launcher"
# The HOME button's code: the one given (--home-key=CODE), else the one
# already bound to the launcher (an earlier install, an update from the
# panel), else the one pressed now, when someone is at a terminal (or
# --home-key=ask), else 773, the tested Magic Remote's. Input Hook logs each
# key it sees; the first code logged after the prompt is taken.
bound=$(node -e '
var k = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
Object.keys(k).forEach(function (code) { if (k[code] && k[code].id === "org.rawin.launcher") console.log(code); });' "$KEYS" 2>/dev/null | head -n 1)
case "$HOME_KEY_OPT" in
    ask) bound= ;;
    "") ;;
    *) bound=$HOME_KEY_OPT ;;
esac
if [ -n "$bound" ]; then
    HOME_KEY=$bound
    say "HOME is key $HOME_KEY"
elif [ -t 0 ] && log=$(ls -t /tmp/lginput-hook-*.log 2>/dev/null | head -n 1) && [ -n "$log" ]; then
    before=$(wc -l <"$log")
    say "press HOME on the remote now to bind it (15 s; otherwise key $HOME_KEY, the tested Magic Remote's, is used)"
    n=0
    while [ $n -lt 15 ]; do
        sleep 1; n=$((n + 1))
        code=$(tail -n +$((before + 1)) "$log" | grep -v 'Keybinds reloaded' | grep -o -E '[0-9]{3,4}' | head -n 1)
        [ -n "$code" ] && { HOME_KEY=$code; break; }
    done
    say "HOME is key $HOME_KEY"
fi
node -e '
var fs = require("fs"), f = process.argv[1], k = JSON.parse(fs.readFileSync(f, "utf8"));
Object.keys(k).forEach(function (code) { if (k[code] && k[code].id === "org.rawin.launcher") delete k[code]; });
k[process.argv[2]] = {action: "launch", id: "org.rawin.launcher"};
fs.writeFileSync(f, JSON.stringify(k));' "$KEYS" "$HOME_KEY"

mkdir -p /var/lib/webosbrew/init.d
rm -f /var/lib/webosbrew/init.d/77-rawin-launcher   # the hook's name up to 0.14.0
cp "$HERE/boot-hook.sh" "$HOOK"
chmod 755 "$HOOK"
sh "$HOOK"
n=0
until wget -q -O - http://127.0.0.1:8899/ping >/dev/null 2>&1; do
    n=$((n + 1)); [ $n -lt 30 ] || fail "the helper did not start (see: luna-send -n 1 luna://$SERVICE/ping '{}')"
    sleep 2
done
say "done. Press HOME on the remote."
say "uninstall: sh $BASE/uninstall.sh"
