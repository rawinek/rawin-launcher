# Troubleshooting

- [Diagnose](#diagnose)
- [HOME does nothing (overlay)](#home-does-nothing-overlay)
- [HOME right after a boot opens LG's Home (overlay)](#home-right-after-a-boot-opens-lgs-home-overlay)
- [An update fails](#an-update-fails)
- [An untested webOS](#an-untested-webos)
- [Getting LG's Home back](#getting-lgs-home-back)

## Diagnose

`diagnose.sh` collects what is needed to look into a problem into one file:

```sh
sh /var/lib/webosbrew/rawin-launcher/diagnose.sh        # Home panel
sh /var/lib/webosbrew/rawin-launcher-home/diagnose.sh   # overlay
sh rawin-launcher/diagnose.sh                           # from the unpacked release
```

It writes `/tmp/rawin-launcher-diagnose.txt`: the TV model, webOS and firmware
versions, whether the screen is UHD, which variant fits (`probe.sh`, next to
`diagnose.sh` in the release and in the installed copy), what is installed
and whether the patched Home QML is in place, what the launcher sees (apps,
inputs with their device names, the app on screen), the HOME button binding,
the boot log (`/tmp/rawin-launcher-boot.log`: what the boot hook did, with the
seconds since boot) and the launcher's lines from the system log. No IP addresses, serial numbers or
accounts. Copy it to a computer with
`ssh root@<tv-ip> cat /tmp/rawin-launcher-diagnose.txt > diagnose.txt`
and attach it to an [issue](https://github.com/rawinek/webos-homebar/issues).

`probe.sh` on its own says which variant fits and why, and changes nothing:
`sh /var/lib/webosbrew/rawin-launcher/probe.sh` (or `…/rawin-launcher-home/probe.sh`,
or `sh rawin-launcher/probe.sh` from the release).

## HOME does nothing (overlay)

Run from a terminal, the installer asks for a press of HOME and binds the
key Input Hook logs for it; without a press, or from the panel's updater, it
binds `773`, the HOME button of the tested Magic Remote. If HOME does
nothing, run the installer again from a terminal with
`sh install.sh --overlay --home-key=ask` and press HOME when asked, or read
the code from Input Hook's log (`/tmp/lginput-hook-*.log`) after a press and
give it with `--home-key=CODE`.

## HOME right after a boot opens LG's Home (overlay)

The Homebrew Channel runs its boot hooks some 35 s into a boot, and
nothing of the launcher's runs before them. The launcher's hook is named to
run among the first and starts Input Hook as its first step, so HOME
reaches the panel a few seconds after the hooks begin: on the tested B4
the TV shows its input from about 20 s, the hooks begin at 35 to 37 s and
the first HOME that reached the panel came at 42 s. A HOME before that
opens LG's Home once; it is stopped when the stand-in takes its place a
moment later, and the TV goes back to the input. A TV woken from standby
does not boot, so this is only seen after a power cut, a `reboot` or a
firmware update. The boot log in `diagnose.sh` shows when each step ran.

## An update fails

The panel says which step failed (check, download or install) and OK tries
again. The installer's output is in `/tmp/rawin-launcher-update/install.log`.
The [manual update](install.md#by-hand-any-version-and-once-from-before-0100)
works for any version.

## An untested webOS

`sh install.sh --probe` (or `probe.sh`, see [Diagnose](#diagnose)) says
which variant fits the TV and why, before anything is changed;
`--home-panel` and `--overlay` force one. What can happen on a webOS that
was never tested:

- **The installer finds no variant.** It says what is missing for each: a
  Home that is not a QML app, or whose files differ too much for the patch;
  for the overlay the Homebrew Channel, Input Hook or a node older than 8.
- **Home panel: LG's ribbon shows instead of the panel**, with a *BLUE · back
  to Homebar* badge in the corner. The panel failed to load; LG's Home is
  still usable. `diagnose.sh` has the error lines; the overlay may work
  instead (`sh install.sh --overlay`, after `uninstall.sh`).
- **Home panel: the panel shows but something of LG's stays in the way**
  (a voice prompt, LG's ribbon on a hidden-mode change). The patch reported
  those pieces as skipped at install time; an issue with the install output
  and `diagnose.sh` helps.
- **Overlay: HOME does nothing.** See [above](#home-does-nothing-overlay).
- **Overlay: the panel is empty or says the helper is not answering.**
  `luna-send -n 1 luna://org.rawin.launcher.service/ping '{}'` and
  `wget -q -O - http://127.0.0.1:8899/ping` show whether the helper runs;
  `diagnose.sh` has its answers and its event list, and the boot log says
  whether the boot hook found it.
- **Overlay with `--replace-lg-home`: the app manager does not take the
  stand-in.** The script unmounts it and leaves LG's Home; nothing is lost.

Whatever happens, `uninstall.sh` gives LG's Home and the HOME button back.

## Getting LG's Home back

- The [uninstaller](install.md#uninstall) gives LG's Home and the HOME button
  back at once.
- Home panel: deleting `/var/lib/webosbrew/init.d/76-rawin-launcher` and
  rebooting gives LG's Home back, since the bind mounts end with a reboot.
- Overlay: `sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh restore`
  gives LG's Home back until the next boot; `takeover.sh status` shows which
  Home the TV has. If the app manager does not accept the stand-in, the script
  unmounts it and leaves LG's Home.
- If a boot hook ever crashes the start-up, the Homebrew Channel's failsafe mode
  skips all hooks on the next boot.
