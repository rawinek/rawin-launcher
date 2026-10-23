#!/usr/bin/env python3
"""An experiment, not part of the release: the LG Home stand-in as its own
package, com.webos.app.home_99.0.0_all.ipk, for dist/home-override/.

The overlay puts the stand-in in LG Home's place with a bind mount at every
boot, which the boot hooks can only do some 35 s after power-on; a HOME before
that opens LG's own Home once. LG updates its built-in apps by installing a
higher version of the same id outside the firmware, and the app manager takes
that copy. If it does the same for com.webos.app.home from a developer
install, this package makes the stand-in LG's Home from the first second of a
boot, with nothing to mount. webos10/home-override.sh installs, places (a copy
by hand into the store apps area, where LG's own updates of built-in apps
go), checks and removes it on the TV; see docs/experiments.md.

Usage: tools/build-home-override.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import ROOT, ar, tgz  # noqa: E402

HOME = "com.webos.app.home"
VERSION = "99.0.0"


def main():
    appinfo = json.loads((ROOT / "webos10/home-stub/appinfo.json").read_text())
    appinfo["version"] = VERSION
    app_dir = "usr/palm/applications/%s/" % HOME
    files = [
        (app_dir + "appinfo.json", json.dumps(appinfo, indent=2).encode()),
        (app_dir + "index.html", (ROOT / "webos10/home-stub/index.html").read_bytes()),
        (app_dir + "icon.png", (ROOT / "ui/icon.png").read_bytes()),
        ("usr/palm/packages/%s/packageinfo.json" % HOME, json.dumps(
            {"id": HOME, "version": VERSION, "vendor": "rawin", "app": HOME,
             "loc_name": "Home", "package_format_version": 2}, indent=1).encode()),
    ]
    control = ("Package: %s\nVersion: %s\nSection: misc\nPriority: optional\nArchitecture: all\n"
               "Maintainer: rawinek\nDescription: Homebar's LG Home stand-in as a package (experiment)\n"
               % (HOME, VERSION)).encode()
    ipk = ar([("debian-binary", b"2.0\n"), ("control.tar.gz", tgz([("control", control)])), ("data.tar.gz", tgz(files))])
    out = ROOT / "dist/home-override"
    out.mkdir(parents=True, exist_ok=True)
    (out / ("%s_%s_all.ipk" % (HOME, VERSION))).write_bytes(ipk)
    (out / "home-override.sh").write_bytes((ROOT / "webos10/home-override.sh").read_bytes())
    # The same files laid out plainly, for home-override.sh place (a copy by
    # hand into the store apps area, no installer).
    for path, data in files:
        target = out / "files" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for p in sorted(out.rglob("*")):
        if p.is_file():
            print(p)


if __name__ == "__main__":
    main()
