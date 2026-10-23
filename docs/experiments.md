# Experiments

Things tried on the test TVs that are not part of the release. Each has its
own script; none is run by the installer.

## The LG Home stand-in as a package (overlay)

The overlay puts the black stand-in in LG Home's place with a bind mount at
every boot. The Homebrew Channel runs the boot hooks some 35 s after
power-on, and a HOME before that opens LG's own Home once
([Troubleshooting](troubleshooting.md#home-right-after-a-boot-opens-lgs-home-overlay)).

LG updates its built-in apps by installing a higher version of the same id
outside the firmware, and the app manager takes that copy over the one in
the firmware. If it does the same for `com.webos.app.home` from a developer
install, the stand-in as a package with version `99.0.0` is LG's Home from
the first second of a boot, with nothing to mount.

```sh
python3 tools/build-home-override.py          # dist/home-override/: the IPK and the script
scp dist/home-override/* root@<tv-ip>:/tmp/ovr/
ssh root@<tv-ip> sh /tmp/ovr/home-override.sh install   # or status, remove
```

`install` prints what the app manager reports for Home before and after
(where it reads it from, its type and version) and a verdict. `remove` takes
the package away; LG's Home is as before. The launcher's own install is not
touched; `takeover.sh restore` and a `keep-lg-home` file in
`/var/lib/webosbrew/rawin-launcher-home/` keep the bind mount out of the
way for a clean look.

What a HOME before the hooks would then show is the black page, until the
helper comes up and switches to the input: black for up to 15 s instead of
LG's Home for as long.

Result: not tried yet.
