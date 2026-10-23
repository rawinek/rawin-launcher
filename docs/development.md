# Development

- [Build from source](#build-from-source)
- [Another webOS version, on purpose](#another-webos-version-on-purpose)
- [Configuration](#configuration)
- [Layout](#layout)
- [Checking the layout](#checking-the-layout)
- [Adding a language](#adding-a-language)
- [Adding a theme](#adding-a-theme)
- [Theme pictures](#theme-pictures)

## Build from source

Python 3 on any computer:

```sh
python3 tools/build.py                   # dist/rawin-launcher.tar.gz
python3 tools/build.py --config my.json  # with your own favourites
python3 tools/deploy.py --host <tv-ip>   # build, copy over SSH and run install.sh
```

`deploy.py` needs key-based root SSH to the TV; `--identity <key>` picks the
key, `--keep-lg-home` and `--uninstall` do what they say, `--backup file`
and `--restore file` copy the TV's `backup.json` either way, and anything
after `--` goes to `install.sh` on the TV (`-- --probe` only says which
variant fits; `-- --overlay --replace-lg-home` forces one). The archive
holds both variants; on the TV `install.sh` picks the one the TV has the
makings for.

## Another webOS version, on purpose

`HOMEBAR_WEBOS=<version>` makes `install.sh` and `probe.sh` take the TV for
that webOS version (`HOMEBAR_WEBOS=9.1 sh install.sh --probe` shows what the
installer would do on a webOS 9 TV with this TV's makings). The variant is
still chosen by what the TV has; the version only decides what counts as
tested and whether the overlay replaces LG's Home by default.

## Configuration

`config/launcher.json` holds the defaults baked into a build:

- `favourites`: up to seven app ids, empty by default. Apps that are not
  installed are skipped. Preset favourites only fill a fresh install: once
  favourites are edited on the TV, that list stays, also through updates.
- `styles`: the glow colour per app id (`{"accent": "#e50914"}`).
- `excluded`: launch points never listed (LG's promotional apps).

## Layout

| Path | What |
| :--- | :--- |
| `ui/` | The panel shared by both variants: `Launcher.qml`, texts in `Strings.js`, colours in `Themes.js`, LocalStorage in `FavouriteStore.qml`, fonts |
| `webos4/` | The Home panel: the LG Home patch, boot hook and scripts |
| `webos10/` | The overlay: the overlay app, helper, HTTP bridge, Home stand-in and scripts |
| `tools/` | Build, deploy, the app icon (`make-icon.py`), the theme pictures (`render-themes.py`) and the panel at any size (`render-panel.py`) |
| `config/` | Build defaults, see [Configuration](#configuration) |

For the overlay, `tools/build.py` turns `ui/Launcher.qml` into the app's
`Panel.qml`, swapping its Luna Service elements for
`webos10/panel-bridge.qml` (HTTP to the helper). The top-level `install.sh`
picks the variant by what the TV has (`probe.sh`, which the installers also
put next to `diagnose.sh` on the TV), see
[Compatibility](compatibility.md#which-variant-a-tv-gets).

## Checking the layout

The panel is drawn for 1920×1080 and scaled to the size it gets: `u` in
`Launcher.qml` is that scale and every length goes through `px()`, so a new
element is placed in 1080p numbers (`shell.px(24)`) and follows the screen.
Positions hang from the bottom and the right edge (`shell.height - px(…)`,
`anchors.right`), never from the top left, so a wider screen gets more rail
and more columns. Text goes through `pt()`, which also takes the text size
setting. `tools/render-panel.py` draws a set of scenes (Home with seven
favourites and long HDMI-CEC names, Live TV, hidden inputs and apps, Apps
in each order, System with an update waiting, the settings menu on a
setting, on its values and on an action, the larger text size, no
favourites, two inputs) at a size:

```sh
python3 -m pip install PySide6
python3 tools/render-panel.py                     # dist/render/1920x1080-*.png
python3 tools/render-panel.py --size 1280x720     # an HD TV
python3 tools/render-panel.py --size 2560x1080    # a wider screen
```

Check at least 1920×1080 and 1280×720 after a change to the panel.

## Adding a language

Copy the `en` table in `ui/Strings.js`, translate it and add the code to
`languages` and `names`. The Inter font covers Latin, Greek and Cyrillic
scripts; others would need a font with their glyphs. Corrections to the
translations are welcome.

## Adding a theme

1. Add `{id: "<id>", accent: "#RRGGBB", base: "#RRGGBB"}` to `themes` in
   `ui/Themes.js`. The order there is the order OK goes through on the TV.
2. Add `theme_<id>` with the theme's name to every language in
   `ui/Strings.js` (English is used where one is missing).
3. Run `tools/render-themes.py` and add the theme to [Themes](themes.md).

`palette()` in `Themes.js` makes every colour from the two: a base with a
relative luminance over 0.4 counts as light (light tiles, dark text), the
shade is always a near-black of the base, and the text on the accent is white
unless the accent's luminance is over 0.3. Pick an accent that stands out from
the base; nothing checks the contrast for you.

## Theme pictures

`tools/render-themes.py` draws `docs/themes/<id>.png` and
`docs/themes/<id>-colors.svg` for every theme from the real `Launcher.qml`, on
a computer:

```sh
python3 -m pip install PySide6
python3 tools/render-themes.py
```

It stubs the webOS-only parts (Luna services, webOS keys), gives the apps plain
coloured icons and puts a gradient where the picture would be.
