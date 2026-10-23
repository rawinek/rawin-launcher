#!/usr/bin/env python3
"""Draw the panel (ui/Launcher.qml) at any screen size, on a computer.

The panel lays itself out for the size it gets: 1920x1080 on FHD and UHD
TVs, 1280x720 on HD ones. This renders a set of scenes at a size, so a
change can be checked at every size without a TV: Home with seven
favourites and long HDMI-CEC names, a favourite focused, Apps, System,
the settings, no favourites, and a set with two inputs.

Usage: tools/render-panel.py [--size 1920x1080] [--out dist/render] [--theme default]
Needs Python 3 with PySide6 (pip install PySide6) and a display (or Xvfb);
not the TV. The webOS-only parts of the panel are stubbed out, as in
render-themes.py.
"""
import argparse
import json
import sys
import tempfile
from pathlib import Path

from PySide6.QtCore import QEventLoop, Qt, QTimer, QUrl
from PySide6.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter
from PySide6.QtQuick import QQuickView

ROOT = Path(__file__).resolve().parent.parent
FONTS = "file:///var/lib/webosbrew/rawin-launcher/current/fonts/"
APPS = [("netflix", "Netflix", "#e50914"), ("youtube.leanback.v4", "YouTube", "#ff0033"),
        ("amazon", "Prime Video", "#1a98ff"), ("org.jellyfin.webos", "Jellyfin", "#aa5cc3"),
        ("com.immich.webos", "Immich", "#4250af"), ("cdp-30", "Plex", "#e5a00d"),
        ("com.webos.app.browser", "Web Browser", "#3a7bd5"), ("spotify", "Spotify", "#1db954"),
        ("disney", "Disney+", "#0f3fa0"), ("hbomax", "Max", "#5b2ea6"), ("twitch", "Twitch", "#9146ff"),
        ("kodi", "Kodi", "#17b2e7"), ("steamlink", "Steam Link", "#1b2838"), ("moonlight", "Moonlight", "#1f1f1f"),
        ("emby", "Emby", "#52b54b"), ("vlc", "VLC", "#ff8800"), ("tidal", "TIDAL", "#000000"),
        ("deezer", "Deezer", "#a238ff"), ("weather", "Weather", "#2b8ae6"), ("photos", "Photos", "#e8734a"),
        ("music", "Music", "#fc3c44"), ("gallery", "Gallery", "#8e44ad"), ("news", "News", "#c0392b"),
        ("sport", "Sport", "#27ae60"), ("kids", "Kids", "#f39c12"), ("radio", "Radio", "#16a085"),
        ("podcasts", "Podcasts", "#9b59b6"), ("games", "Games", "#2c3e50"), ("files", "File Manager", "#7f8c8d"),
        ("screensaver", "Screensaver", "#34495e")]
INPUTS = [("PlayStation 5", True), ("Apple TV 4K", True), ("Nintendo Switch", True), ("Chromecast with Google TV", False)]
INPUTS_SMALL = [("Blu-ray Player", True), ("", False)]

MAIN = '''import QtQuick
Item {
    width: %d; height: %d
    Rectangle { anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#5b7fa3" }
            GradientStop { position: 0.6; color: "#9b8a6e" }
            GradientStop { position: 1.0; color: "#2f3a2c" } } }
    Launcher { id: shell; anchors.fill: parent; foreground: true; nowTitle: "YouTube" }
    function scene(page, selected, favs, inputs, theme) {
        shell.settings = {lang: "en", theme: theme, exitTo: "last", clock: true, title: true, beta: false};
        shell.favouriteIds = favs; shell.inputs = inputs;
        shell.page = page; shell.selected = selected;
    }
}
'''


def inputs(spec):
    return [{"id": "com.webos.app.hdmi%d" % (i + 1), "title": "HDMI %d" % (i + 1), "detail": d, "present": p}
            for i, (d, p) in enumerate(spec)]


def panel(app_dir):
    """The panel as a desktop Qt 6 can load it, plus Config.js and app icons."""
    q = (ROOT / "ui/Launcher.qml").read_text()
    q = q.replace("import QtGraphicalEffects 1.0\n", "import Qt5Compat.GraphicalEffects\n")
    q = q.replace("import WebOSServices 1.0\n", "").replace("import WebOS.Global 1.0\n", "")
    q = q.replace(FONTS, (ROOT / "ui/fonts").as_uri() + "/")
    start = q.index("    Service {\n        id: launchService")
    end = q.index("    Timer { id: launchTimeout;")
    stubs = "".join("    QtObject { id: %s; function callService(a) {} }\n" % name for name in
                    ("launchService", "catalog", "foregroundInfo", "localeService", "inputService", "updateService"))
    (app_dir / "Launcher.qml").write_text(q[:start] + stubs + q[end:])
    for name in ("FavouriteStore.qml", "Strings.js", "Themes.js"):
        (app_dir / name).write_bytes((ROOT / "ui" / name).read_bytes())
    apps = []
    for app_id, title, color in APPS:
        icon = QImage(240, 240, QImage.Format_RGB32)
        icon.fill(QColor(color))
        p = QPainter(icon)
        p.setPen(QColor("#ffffff"))
        p.setFont(QFont("Helvetica", 110, QFont.Bold))
        p.drawText(icon.rect(), Qt.AlignCenter, title[0])
        p.end()
        icon.save(str(app_dir / (app_id + ".png")))
        apps.append({"id": app_id, "title": title, "icon": (app_dir / (app_id + ".png")).as_uri()})
    styles = json.loads((ROOT / "config/launcher.json").read_text()).get("styles", {})
    config = {"version": (ROOT / "VERSION").read_text().strip(), "platform": "Home panel", "webos": "4.10.2",
              "apps": apps, "favourites": [a["id"] for a in apps[:7]], "styles": styles,
              "inputs": inputs(INPUTS), "excluded": []}
    (app_dir / "Config.js").write_text(".pragma library\n" + "".join(
        "var %s = %s;\n" % (k, json.dumps(v)) for k, v in config.items()))


def wait(ms):
    loop = QEventLoop()
    QTimer.singleShot(ms, loop.quit)
    loop.exec()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--size", default="1920x1080", help="the panel's size (default: 1920x1080; HD TVs: 1280x720)")
    parser.add_argument("--out", default=str(ROOT / "dist/render"), help="output directory (default: dist/render)")
    parser.add_argument("--theme", default="default", help="a theme id from ui/Themes.js")
    args = parser.parse_args()
    w, h = (int(v) for v in args.size.split("x"))
    app = QGuiApplication(sys.argv)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        app_dir = Path(tmp)
        panel(app_dir)
        (app_dir / "main.qml").write_text(MAIN % (w, h))
        view = QQuickView()
        view.setSource(QUrl.fromLocalFile(str(app_dir / "main.qml")))
        if view.status() != QQuickView.Ready:
            raise SystemExit("\n".join(e.toString() for e in view.errors()))
        view.show()
        wait(800)
        root = view.rootObject()
        favs = [a[0] for a in APPS[:7]]
        scenes = [
            ("home-hdmi2", "home", 8, favs, inputs(INPUTS)),
            ("home-fav0", "home", 0, favs, inputs(INPUTS)),
            ("home-system", "home", 12, favs, inputs(INPUTS)),
            ("apps", "apps", 14, favs, inputs(INPUTS)),
            ("system", "system", 1, favs, inputs(INPUTS)),
            ("settings", "settings", 1, favs, inputs(INPUTS)),
            ("home-nofavs", "home", 0, [], inputs(INPUTS)),
            ("home-2inputs", "home", 3, favs[:3], inputs(INPUTS_SMALL)),
        ]
        for name, page, selected, fav_ids, inp in scenes:
            root.scene(page, selected, fav_ids, inp, args.theme)
            wait(700)
            target = out / ("%s-%s.png" % (args.size, name))
            view.grabWindow().save(str(target))
            print(target)


if __name__ == "__main__":
    main()
