#!/usr/bin/env bash

# Start pcscd, after linking the reader's bus where libusb looks for it; safe to rerun.
# usage: start.sh [restart], restart to pick up a replugged reader: without udevd in the
# container, pcscd sees readers only when it starts
set -euo pipefail

# devcontainer.json mounts the reader's bus here, see .devcontainer/usb-bus-link.sh
mount=/run/smartcard-bus
pid=/run/pcscd/pcscd.pid

# libusb opens /dev/bus/usb/BBB/DDD, but the mount target can't vary with the bus, so link it;
# the bus comes from a node's minor, (bus - 1) * 128 + dev - 1, the root hub's at least
node=$(find "$mount" -mindepth 1 -maxdepth 1 -type c -print -quit 2> /dev/null || true)
if [[ $node ]]; then
    bus=$((0x$(stat -c %T "$node") / 128 + 1))
    sudo mkdir -p /dev/bus/usb
    sudo ln -sfn "$mount" "$(printf '/dev/bus/usb/%03d' "$bus")"
    for f in /sys/bus/usb/devices/*/bInterfaceClass; do
        [[ $(< "$f") == 0b ]] || continue
        now=$(< "${f%/*}/../busnum")
        if ((now != bus)); then
            echo "start: the reader moved to bus $now, but bus $bus is mounted; rebuild" >&2
        fi
    done
else
    echo "start: no reader bus mounted, see .devcontainer/usb-bus-link.sh" >&2
fi

# pcscd ends its pid file with a NUL
running=$(tr -d '\0' 2> /dev/null < "$pid" || true)
if [[ $running ]] && kill -0 "$running" 2> /dev/null; then
    [[ ${1:-} == restart ]] || exit 0
    kill "$running"
    while kill -0 "$running" 2> /dev/null; do sleep 0.1; done
fi
# As this user, not root: rootless, the container's root is another host user, without the
# host's ACL on the reader. --disable-polkit, as there's no polkitd, see setup.sh.
sudo install -d -o "$(id -u)" -g "$(id -g)" /run/pcscd
pcscd --disable-polkit
