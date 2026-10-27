# e-ID

A Belgian e-ID card in a reader on the host, used from Chromium in the devcontainer, for
authentication and signing, without giving the devcontainer privileges.

Work in progress: the target and the steps to it are in [PLAN.eid/](../../../PLAN.eid/README.md),
until they're built and described here.

The why of a single detail is in a comment next to it. These pages cover what spans files.

Paths are relative to `eid/`, except `.devcontainer/` and `.local/` in the repo root. Run
recipes with `just` in `eid/`, or as `just eid::<recipe>` from the root.

## Packages

- Debian's own, in the Dockerfile: `libccid`, the reader's driver, `pcsc-tools`, `opensc`,
  `chromium`, and `equivs` for the stub below
- the rest, in `just setup`, by [env/setup.sh](../../env/setup.sh), as they need more than apt:
  - the eID repo, through its `eid-archive` package, pinned in [versions.just](../../versions.just)
    with its checksum; its postinst writes `/etc/apt/sources.list.d/eid.sources` and the key
  - `polkitd-stub`, which provides `polkitd`: Debian's `pcscd` depends on it, and polkitd on a
    D-Bus system bus and systemd, which the Dockerfile pins out. pcscd runs with
    `--disable-polkit` instead, which allows all clients; this container has one user
  - `pcscd`, `eid-mw`, with the PKCS#11 module `libbeidpkcs11.so.0`, and `eid-viewer`

## Reader

```
host                                    devcontainer
/dev/bus/usb/001/  ── bind mount ──►    /run/smartcard-bus/  ◄── link ──  /dev/bus/usb/001
                                        pcscd, as vscode ── libccid ── /dev/bus/usb/001/012
```

- before the container is created, [usb-bus-link.sh](../../../.devcontainer/usb-bus-link.sh)
  finds the reader by its interface class, `0b`, and links `.local/host/smartcard-bus` to its
  bus dir, if the user can open the reader, else to an empty dir; devcontainer.json mounts the
  link at `/run/smartcard-bus`. The bus, not the node, as the node's number changes on replug
- the mount's target can't vary with the bus, but libusb opens `/dev/bus/usb/BBB/DDD`; so
  [start.sh](../../env/start.sh) links `/dev/bus/usb/BBB` to the mount, on each start, as
  `/dev` is a fresh tmpfs. The bus comes from the minor of a node in the mount
- pcscd runs as `vscode`, not root: under rootless Podman with `keep-id`, `vscode` is the host
  user, who has the host's ACL on the reader, and root is a subordinate ID, who hasn't
- nothing starts services in the container: `postStartCommand` runs `just start`
- no udevd in the container, so pcscd doesn't hear of a replugged reader: `just eid::restart`.
  A card going in or out is libccid's business, that just works
- the reader moved to another bus: the mount stays on the old one until a rebuild; `just start`
  warns

## Checks

From the reader up, each layer on the one before:

- `just eid::scan`: pcscd sees the reader, and the card as it goes in or out
- `just eid::card`: the PKCS#11 module, `libbeidpkcs11.so.0`, lists the card's token
- `just eid::viewer`: eid-viewer reads the card; its PIN test checks the PIN dialog, on the
  forwarded X display

## State

`.local/eid/`, made by `just setup`; it survives a rebuild.

- `cache/`: downloads, named after their version
- `debs/`: packages built here, like `polkitd-stub`
