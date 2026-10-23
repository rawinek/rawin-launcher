#!/bin/sh
# rawin-launcher (webOS 10): give LG Home and the HOME button back and remove
# the launcher, its helper and its files.
BASE=/var/lib/webosbrew/rawin-launcher-home
KEYS=/home/root/.config/lginputhook/keybinds.json

[ -f "$BASE/takeover.sh" ] && sh "$BASE/takeover.sh" restore >/dev/null 2>&1
rm -f /var/lib/webosbrew/init.d/10-rawin-launcher /var/lib/webosbrew/init.d/77-rawin-launcher

# HOME back to LG: drop our key, keep any other bindings.
if [ -f "$KEYS" ]; then
    node -e '
var fs = require("fs"), f = process.argv[1], k = JSON.parse(fs.readFileSync(f, "utf8"));
Object.keys(k).forEach(function (code) { if (k[code] && k[code].id === "org.rawin.launcher") delete k[code]; });
fs.writeFileSync(f, JSON.stringify(k));' "$KEYS"
fi

luna-send -n 1 luna://com.webos.applicationManager/closeByAppId '{"id":"org.rawin.launcher"}' </dev/null >/dev/null 2>&1
for p in /proc/[0-9]*; do
    [ "$(cat "$p/comm" 2>/dev/null)" = "org.rawin.launc" ] && kill "${p#/proc/}" 2>/dev/null
done
luna-send -i -a com.webos.appInstallService luna://com.webos.appInstallService/dev/remove \
    '{"id":"org.rawin.launcher","subscribe":true}' </dev/null >/dev/null 2>&1 &
PID=$!
# Done when the package's own files are gone; the helper's icon cache (cache/,
# not part of the package) stays behind and is removed here.
APPDIR=/media/developer/apps/usr/palm/applications/org.rawin.launcher
n=0
while [ -f "$APPDIR/appinfo.json" ] && [ $n -lt 60 ]; do
    n=$((n + 1)); sleep 1
done
kill $PID 2>/dev/null
[ -f "$APPDIR/appinfo.json" ] || rm -rf "$APPDIR"
rm -rf "$BASE" /var/lib/webosbrew/rawin-launcher-last-input /var/lib/webosbrew/rawin-launcher-settings.json
# Favourites and settings (the app's LocalStorage).
rm -rf /home/root/.local/share/org.rawin.launcher
echo "rawin-launcher: removed; LG Home and the HOME button are back."
