#!/bin/sh

# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

# Runs on the host, from initializeCommand, before the devcontainer is created.
# usage: usb-bus-link.sh <interface class> <name>, e.g. usb-bus-link.sh 0b smartcard-bus
# Points .local/host/<name> at the /dev/bus/usb/BBB dir of the first USB device with an
# interface of that class, if the user can read and write its node, else at an empty dir, as a
# mount needs a source. devcontainer.json bind-mounts the link; mounting the bus, not the node,
# lets the device be replugged, as its node's number changes each time. Under rootless Podman,
# without a device cgroup, the container can open what the user can open on the host, and no
# more. The link is resolved when the container is created, so a device that moves to another
# bus needs a rebuild.
set -eu

class=$1 name=$2
dir=$(cd "$(dirname "$0")/.." && pwd)/.local/host
link=$dir/$name

mkdir -p "$dir/empty"
target=$dir/empty why=
for f in /sys/bus/usb/devices/*/bInterfaceClass; do
    [ "$(cat "$f" 2> /dev/null)" = "$class" ] || continue
    # an interface, like 1-2:1.0, belongs to the device 1-2
    iface=${f%/bInterfaceClass}
    dev=${iface%:*}
    node=$(printf '/dev/bus/usb/%03d/%03d' "$(cat "$dev/busnum")" "$(cat "$dev/devnum")")
    if [ -r "$node" ] && [ -w "$node" ]; then
        target=${node%/*}
        why="$(cat "$dev/product" 2> /dev/null || echo device) at $node"
        break
    fi
    why="no read-write on $node"
done
ln -sfn "$target" "$link"
echo "usb-bus-link: $link -> $target, ${why:-no USB device with interface class $class}"
