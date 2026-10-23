# Homebar

![Homebar over a YouTube video: favourites, HDMI inputs, Apps and System](docs/screenshots/home.jpg)

A minimal home screen for rooted LG webOS TVs, brought back as a bar at the
bottom of the screen instead of a full-screen menu that takes you out of what
you were watching. HOME opens it over whatever is on screen: up to seven
favourite apps, the HDMI inputs with the device the TV sees on each (HDMI-CEC
name), all installed apps, and a System page. The picture stays visible above
it.

- **Favourites are chosen on the TV**: hold OK on an app in *Apps* to add it,
  hold OK on a favourite to move or remove it.
- **RED hides** an app or an input you never use; nothing is uninstalled.
- **Launcher settings**, a menu over the picture: nine
  [languages](docs/using.md#languages), [eight colour themes](docs/themes.md),
  the text size, the Apps order, Live TV on the row, the clock bar and its
  format, the app name, a **backup** of it all, and **updates** straight
  from this repository's releases, with a dot on *System* when one is there.
- LG's promotional apps are hidden from the lists.
- **Any screen**: the panel scales to the TV's UI, HD (1280×720) as well as
  FHD and UHD, and shows the inputs the TV has, two or four, with the
  device on each.
- **webOS 10:** LG's own Home stays out of the way. A black stand-in takes
  its place, and the TV goes back to the last input (or a chosen HDMI) when
  an app exits or BACK is held. Only a HOME in the first 40 s after a cold
  boot, before the Homebrew Channel's hooks run, opens LG's Home once.

<img src="docs/screenshots/demo.gif" width="100%" alt="Demo: HOME opens the launcher, System, Launcher settings: languages, clock bar, app name">

## Compatibility

Tested on webOS 4.10 (LG C9, 2019) and webOS 10.3 (LG B4, 2024). On any other
webOS the installer picks the variant the TV has the makings for: the panel
inside LG's Home where Home is a QML app the patch fits (webOS 3 to 8 have
that kind of Home), the overlay app elsewhere (webOS 9 and 11 have webOS 10's
kind). `sh install.sh --probe` says which, and changes nothing. Details in
[Compatibility](docs/compatibility.md).

## Install

You need a rooted TV with the
[Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) and a
root shell (SSH or telnet), and for the overlay variant (webOS 10, or a Home
that cannot take the panel) the **Input Hook** app from the Homebrew Channel.
Log in to the TV as root, then:

```sh
cd /tmp
curl -fL -o rawin-launcher.tar.gz https://github.com/rawinek/webos-homebar/releases/latest/download/rawin-launcher.tar.gz
rm -rf rawin-launcher && tar xzf rawin-launcher.tar.gz
sh rawin-launcher/install.sh
```

Press HOME on the remote when it is done. Options, installing without internet
on the TV, updating and uninstalling: [Install, update, uninstall](docs/install.md).

Homebar was called **rawin-launcher** until 0.12.0. The release file and the
folders on the TV keep that name, so earlier installs update in place, and the
old GitHub address leads here.

**Update:** *System → Launcher settings → Updates* (from 0.10.0 on).
**Uninstall:** `sh /var/lib/webosbrew/rawin-launcher/uninstall.sh` (Home panel)
or `sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh` (overlay).

## Documentation

- [Install, update, uninstall](docs/install.md)
- [Using the launcher](docs/using.md): favourites, System, every setting, languages
- [Themes](docs/themes.md)
- [Compatibility](docs/compatibility.md)
- [How it works](docs/how-it-works.md): both variants, what is changed on the TV
- [Troubleshooting](docs/troubleshooting.md): `diagnose.sh`, getting LG's Home back
- [Development](docs/development.md): build from source, adding a language or a theme

Problems: run `diagnose.sh` (see [Troubleshooting](docs/troubleshooting.md#diagnose))
and attach its file to an [issue](https://github.com/rawinek/webos-homebar/issues).

## Credits

- [webOS Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
  for root, `elevate-service` and the boot hooks, and Input Hook for the HOME
  button.
- [Glasshouse](https://github.com/rorygallagher2024/glasshouse) showed how the
  app manager re-reads LG's Home on webOS 10 (block and release of one app).
- [Inter](https://github.com/rsms/inter) typeface, SIL Open Font License 1.1.
- Video in the screenshots: *Big Buck Bunny* © Blender Foundation,
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

## Disclaimer

Unofficial; not affiliated with or endorsed by LG Electronics. It runs as root
on your TV and replaces how its home screen works. Use at your own risk.

## License

MIT, see [LICENSE](LICENSE). The Inter font is under the SIL Open Font License
1.1 (`ui/fonts/OFL.txt`).
