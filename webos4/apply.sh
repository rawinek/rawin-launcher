#!/bin/sh
# rawin-launcher (webOS 4) boot hook, also run by install.sh. Bind-mounts the
# patched LG Home QML (main.qml, Controllers/UIController.qml) from
# /var/lib/webosbrew/rawin-launcher over the firmware files and restarts only
# the Home process. The read-only rootfs is not changed; a reboot without this
# hook gives LG's Home back.
set -eu
base=/var/lib/webosbrew/rawin-launcher
# The system log and, with the seconds since boot, the launcher's boot log
# (cleared with /tmp at every boot; diagnose.sh shows it).
log() { logger -t rawin-launcher "$1"; echo "$(cut -d' ' -f1 /proc/uptime)s $1" >>/tmp/rawin-launcher-boot.log; }
root=/usr/palm/applications/com.webos.app.home/qml
main=$root/main.qml
ctrl=$root/Controllers/UIController.qml

# Mount each file unless it is already ours; refuse firmware files that are
# neither ours nor the originals the patch was made from (after an update).
mount_patched() {
    target=$1; ours=$2; original=$3
    cmp -s "$target" "$ours" && return 0
    if ! cmp -s "$target" "$original"; then
        log "LG Home changed ($target); original Home kept"
        return 1
    fi
    mount -o bind "$ours" "$target"
}
mount_patched "$main" "$base/main.qml" "$base/main.original.qml" || exit 0
if ! mount_patched "$ctrl" "$base/UIController.qml" "$base/UIController.original.qml"; then
    umount "$main"
    exit 0
fi

# LG Home starts from a CRIU snapshot that already holds the original QML in
# memory; hide Home's snapshot directories so it starts from the files.
mkdir -p "$base/no-checkpoint"
for target in /mnt/lg/cmn_data/checkpoint/com.webos.app.home /tmp/checkpoint/com.webos.app.home; do
    if [ -d "$target" ] && ! grep -qF " $target " /proc/mounts; then
        mount -o bind "$base/no-checkpoint" "$target"
        mount -o remount,bind,ro "$target"
    fi
done

# Stop Home only; the next HOME starts it with the patched QML.
for pid in $(pidof com.webos.app.home || true); do kill -KILL "$pid" || true; done
log 'panel applied to LG Home'
