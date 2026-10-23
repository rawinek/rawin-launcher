#!/usr/bin/env python3
"""Build a release and install it on a rooted TV over SSH, from a computer.

Usage: tools/deploy.py --host <tv-ip> [--config file.json] [--keep-lg-home] [--uninstall]
                       [--backup file.json | --restore file.json] [-- <install.sh options>]
Needs key-based root SSH to the TV (the Homebrew Channel's SSH server).
The TV runs the same install.sh a user would run by hand; anything after
"--" goes to it, e.g. "-- --probe" only says which variant fits the TV and
"-- --overlay --replace-lg-home" forces the overlay with the stand-in.
--backup copies the TV's backup (Launcher settings → Back up) to a file;
--restore copies a file there, for Launcher settings → Restore.
"""
import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

BASES = ["/var/lib/webosbrew/rawin-launcher", "/var/lib/webosbrew/rawin-launcher-home"]

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", required=True, help="the TV's address")
    parser.add_argument("--config", help="launcher config (default: config/launcher.json)")
    parser.add_argument("--keep-lg-home", action="store_true", help="webOS 10: leave LG's Home in place")
    parser.add_argument("--uninstall", action="store_true", help="remove Homebar from the TV")
    parser.add_argument("--backup", metavar="FILE", help="copy the TV's backup.json (made in Launcher settings) to FILE")
    parser.add_argument("--restore", metavar="FILE", help="copy FILE to the TV as its backup.json, for Launcher settings → Restore")
    parser.add_argument("--identity", help="SSH private key (default: ssh's own choice)")
    parser.add_argument("install_options", nargs=argparse.REMAINDER, metavar="-- OPTION",
                        help="passed on to install.sh after --, e.g. -- --probe, -- --overlay --replace-lg-home")
    args = parser.parse_args()
    install_options = [o for o in args.install_options if o != "--"]

    ssh = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
    if args.identity:
        ssh += ["-i", args.identity, "-o", "IdentitiesOnly=yes"]
    target = "root@" + args.host

    if args.uninstall:
        script = ("for u in /var/lib/webosbrew/rawin-launcher/uninstall.sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh; "
                  "do [ -f $u ] && sh $u; done; true")
        sys.exit(subprocess.run(ssh + ["-tt", target, script]).returncode)
    if args.backup:
        script = "for b in %s; do [ -f $b/backup.json ] && cat $b/backup.json && exit 0; done; exit 1" % " ".join(BASES)
        r = subprocess.run(ssh + [target, script], capture_output=True)
        if r.returncode:
            sys.exit("no backup on the TV: make one in System → Launcher settings → Back up first")
        Path(args.backup).write_bytes(r.stdout)
        print("backup saved to " + args.backup)
        return
    if args.restore:
        data = Path(args.restore).read_bytes()
        if not json.loads(data).get("saved"):
            sys.exit(args.restore + " is not a Homebar backup")
        script = "d=; for b in %s; do [ -d $b ] && d=$b; done; [ -n \"$d\" ] || exit 1; cat > $d/backup.json" % " ".join(BASES)
        if subprocess.run(ssh + [target, script], input=data).returncode:
            sys.exit("Homebar is not installed on the TV")
        print("copied; restore it on the TV in System → Launcher settings → Restore from the backup")
        return

    build = [sys.executable, str(ROOT / "tools/build.py")] + (["--config", args.config] if args.config else [])
    archive = Path(subprocess.run(build, check=True, capture_output=True, text=True).stdout.strip().splitlines()[-1])
    name = archive.name[:-len(".tar.gz")]
    print("built " + archive.name)
    remote = "/tmp/" + archive.name
    subprocess.run(ssh + [target, "cat > " + remote], input=archive.read_bytes(), check=True)
    options = "".join(" " + shlex.quote(o) for o in (["--keep-lg-home"] if args.keep_lg_home else []) + install_options)
    script = "cd /tmp && rm -rf {n} && tar xzf {a} && sh {n}/install.sh{o}; r=$?; rm -rf {n} {a}; exit $r".format(
        n=shlex.quote(name), a=shlex.quote(remote), o=options)
    sys.exit(subprocess.run(ssh + ["-tt", target, script]).returncode)


if __name__ == "__main__":
    main()
