#!/bin/sh
# rawin-launcher updater, started from the panel (System → Launcher settings →
# Updates): as root through the Homebrew Channel's exec for the Home panel,
# by the helper for the overlay. The installer puts it next to the installed
# launcher, with the VERSION file. Each step prints one line of JSON.
#   update.sh check [stable|test]  the newest release on GitHub (test: pre-releases too)
#   update.sh download             fetch the checked release, verify its SHA-256, unpack it
#   update.sh install              run its install.sh in the background
#   update.sh status               how that install is going: running, done or failed
REPO=rawinek/webos-homebar
ASSET=rawin-launcher.tar.gz
WORK=/tmp/rawin-launcher-update
HERE=$(cd "$(dirname "$0")" && pwd)

fail() { printf '{"ok":false,"error":"%s"}\n' "$1"; exit 0; }
get() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 120 "$1"
    else wget -q -T 120 -O - "$1"; fi
}

check() {
    current=$(cat "$HERE/VERSION" 2>/dev/null)
    url=https://api.github.com/repos/$REPO/releases/latest
    [ "$1" = test ] && url="https://api.github.com/repos/$REPO/releases?per_page=10"
    rm -rf "$WORK"
    mkdir -p "$WORK"
    get "$url" >"$WORK/release.json" 2>/dev/null || fail "GitHub cannot be reached"
    # Plain ES5: webOS 4 has node 0.12. Writes version, url and sha256 for download.
    node -e '
var fs = require("fs"), work = process.argv[1], current = process.argv[2], asset = process.argv[3];
function out(o) { console.log(JSON.stringify(o)); }
function parts(v) {
  var m = String(v).replace(/^v/, "").split("-");
  return {n: m[0].split(".").map(Number), pre: m.length > 1};
}
function newer(a, b) {
  var x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) { var d = (x.n[i] || 0) - (y.n[i] || 0); if (d) return d > 0; }
  return !x.pre && y.pre;
}
function main() {
var r;
try { r = JSON.parse(fs.readFileSync(work + "/release.json", "utf8")); } catch (e) { return out({ok: false, error: "unreadable answer from GitHub"}); }
if (Object.prototype.toString.call(r) === "[object Array]") r = r.filter(function (x) { return !x.draft; })[0];
if (!r || !r.tag_name) return out({ok: false, error: "no release found"});
var file = (r.assets || []).filter(function (a) { return a.name === asset; })[0];
if (!file) return out({ok: false, error: "the release has no " + asset});
var version = r.tag_name.replace(/^v/, "");
fs.writeFileSync(work + "/version", version);
fs.writeFileSync(work + "/url", file.browser_download_url);
fs.writeFileSync(work + "/sha256", String(file.digest || "").replace(/^sha256:/, ""));
out({ok: true, current: current, latest: version, newer: newer(version, current), prerelease: !!r.prerelease});
}
main();
' "$WORK" "$current" "$ASSET" || fail "node failed"
}

download() {
    [ -s "$WORK/url" ] || fail "check for updates first"
    version=$(cat "$WORK/version")
    sum=$(cat "$WORK/sha256")
    rm -rf "$WORK/pkg" "$WORK/$ASSET" "$WORK/state" "$WORK/install.log"
    get "$(cat "$WORK/url")" >"$WORK/$ASSET" 2>/dev/null || fail "download failed"
    if [ -n "$sum" ] && [ "$(sha256sum "$WORK/$ASSET" | cut -d ' ' -f 1)" != "$sum" ]; then
        rm -f "$WORK/$ASSET"
        fail "checksum mismatch"
    fi
    mkdir "$WORK/pkg"
    tar xzf "$WORK/$ASSET" -C "$WORK/pkg" 2>/dev/null || fail "the archive is damaged"
    [ "$(cat "$WORK/pkg/rawin-launcher/VERSION" 2>/dev/null)" = "$version" ] || fail "the archive holds another version"
    printf '{"ok":true,"version":"%s"}\n' "$version"
}

install() {
    pkg=$WORK/pkg/rawin-launcher
    [ -f "$pkg/install.sh" ] || fail "download the update first"
    # Keep the variant and its options: the overlay leaves a marker when LG's
    # Home was kept. Afterwards the launcher is opened again: for the Home
    # panel that is LG Home (restarted by the installer), for the overlay the
    # overlay app (closed by the package update).
    case "$HERE" in
        */rawin-launcher-home)
            opts=--overlay
            if [ -f "$HERE/keep-lg-home" ]; then opts="$opts --keep-lg-home"
            else opts="$opts --replace-lg-home"; fi
            app=org.rawin.launcher
            ;;
        *)
            opts=--home-panel
            app=com.webos.app.home
            ;;
    esac
    echo running >"$WORK/state"
    # Detached, in its own session: the installer replaces the launcher and, on
    # webOS 10, the helper that started this script. It first closes every file
    # descriptor it inherited: the caller's Luna bus socket among them would
    # keep the old helper's service name registered, so the new helper could
    # never start. The pause lets this answer reach the panel first.
    setsid sh -c '
        for fd in $(ls /proc/$$/fd); do [ "$fd" -gt 2 ] && eval "exec $fd>&-"; done
        sleep 2
        if sh "$1/install.sh" $2 >"$3/install.log" 2>&1; then
            echo done >"$3/state"
            sleep 2
            luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"$4\"}" </dev/null >/dev/null 2>&1
        else
            echo failed >"$3/state"
        fi
    ' rawin-launcher-update "$pkg" "$opts" "$WORK" "$app" </dev/null >/dev/null 2>&1 &
    echo '{"ok":true}'
}

status() {
    state=$(cat "$WORK/state" 2>/dev/null)
    last=$(tail -n 1 "$WORK/install.log" 2>/dev/null | tr -d '"\\' | tr -d '\000-\037')
    printf '{"ok":true,"state":"%s","last":"%s"}\n' "${state:-none}" "$last"
}

case "$1" in
    check) check "$2" ;;
    download) download ;;
    install) install ;;
    status) status ;;
    *) echo "usage: $0 check [stable|test] | download | install | status" >&2; exit 2 ;;
esac
