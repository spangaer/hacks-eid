# Plan: Belgian e-ID in the devcontainer

## Goal

A smartcard reader on the host, with a Belgian e-ID card in it, fully usable from Chromium in
the devcontainer: authentication, e.g. a CSAM / MyGov.be login, and signing through
BeIDConnect. Nothing gets installed or built on the host; what has no package gets built in the
devcontainer, into `.local/eid/`.

## Host

Debian, rootless Podman. Seen from the devcontainer: `keep-id` user namespace, cgroup v2 with
only `cpu memory pids`, so no device cgroup; what the container can open is decided by the host
user's own permissions on the device node.

## The stack

```
Chromium ─┬─ NSS ── PKCS#11 libbeidpkcs11 ─┬─ libpcsclite ── pcscd ── libccid ── /dev/bus/usb
          └─ BeIDConnect extension ── beidconnect (native messaging host) ─┘
                                    all in the devcontainer
```

- eid-mw isn't in Debian; the official repo, `files.eid.belgium.be/debian`, has trixie, set up
  through its `eid-archive` package, which adds the source and signing key; it has 5.1.25 of
  `eid-mw`, `libbeidpkcs11-0`, `libbeidpkcs11-bin`, which has `beid-update-nssdb`, and
  `eid-viewer`, a GUI to test the card
- Debian has the rest: `pcscd`, `libccid`, `pcsc-tools` (`pcsc_scan`), `opensc`
  (`pkcs11-tool`), `chromium`
- BeIDConnect has no Linux binary anywhere: no GitHub releases, nothing in the eID deb or rpm
  repos, only a Windows MSI on the official site; its predecessor, `eidlink` 0.0.8, lingers in
  the repo's pool, orphaned. So it's built in the devcontainer, see below
- the BeIDConnect extension comes from the Chrome Web Store, into Chromium's profile

## Reader access: the reader's USB bus in the devcontainer

pcscd and libccid run in the devcontainer, with the reader's USB device passed in.

The reader: ACS `072f:90cc`, `CCID USB Reader`, the ACR38U-CCID, supported by `libccid`; on
bus 1, a laptop port's controller, next to the fingerprint sensor and the Bluetooth radio. Seen
from the devcontainer, which has the host's `/sys`, read-only.

### Chosen: the reader's bus dir, bind-mounted

`initializeCommand` finds the reader on the host, in `/sys/bus/usb/devices/` by interface class
`0b`, and links `.local/host/smartcard-bus` to its `/dev/bus/usb/BBB`; devcontainer.json
bind-mounts that link at `/run/smartcard-bus`, and `just start` links `/dev/bus/usb/BBB` to it,
as the mount's target can't vary. No reader found: a link to a bus that's still there stays, so
the reader can be plugged in after a rebuild, on its last bus; else the link points at an empty
dir, and the container starts without one.

- replugs into any port on the same controller work: the bind shows nodes as they come and go
- under rootless Podman, without a device cgroup, only nodes the host user can open on the host
  open in the container; the bus's other devices are claimed by kernel drivers or root daemons
- pcscd runs as `vscode`, the host user under `keep-id`; the container's root is a subordinate
  ID, without the host's ACL on the reader
- the bus is fixed at container creation: the reader must be plugged in then, or have been on
  that bus at the last creation, and moving it to a port on another bus, like the dock's bus 5,
  needs a rebuild
- verified: device nodes in the bind mount open, as it has no `nodev`, and the bind follows the
  link

### Rejected

- the reader's node, passed with `--device`, as k8s-testbed did `/dev/kvm`: its number changes
  on every replug, a symlink doesn't help, as `--device` resolves it at creation; each replug
  would need a rebuild
- all of `/dev/bus/usb`: survives any replug, but exposes every bus, while the reader has a
  home port

### Caveats

- the host user needs read-write on the reader's node. Debian's systemd grants it through
  `uaccess` to the seat's user, and does so for this reader as is: `getfacl` on its node shows
  `user:<you>:rw-`, nothing on the host needed. Another reader, or host, may lack it; then a
  udev rule in `/etc/udev/rules.d/` is the least, a host config file, not a package
- no udevd in the container: pcscd enumerates readers at start through sysfs, but may not see
  hot-plug events, and `pcscd --hotplug` only rescans serial and PCMCIA readers; so a recipe
  restarts pcscd. Card insertion is libccid's polling, unaffected
- the host's pcscd, if any, must let go of the reader; Debian hosts don't have it by default

## pcscd in a container without systemd

- the Dockerfile pins out systemd and dbus, and Debian's `pcscd` depends on `polkitd`, which
  needs a D-Bus system bus, which needs systemd: `pcscd`, and `eid-mw`, which depends on it,
  don't install
- fix: an `equivs` stub that provides `polkitd`, and run pcscd with `--disable-polkit`, which
  trixie's 2.3.3 has, per its man page: all accesses allowed, fine in a single-user container
- the stub is built by `equivs-build` in setup, into `.local/eid/debs/`, like BeIDConnect
- no init: start pcscd from `postStartCommand`, through an idempotent recipe that checks
  whether it runs; root in the container is the host user, so this is no privilege

## Chromium

- display: VS Code forwards X11, `DISPLAY=:0` on `/tmp/.X11-unix/X0`, like gitk uses; the PIN
  dialogs of libbeidpkcs11 use `pinentry-x11` over the same display
- verified: Chromium's sandbox works under rootless Podman, no `--no-sandbox`; `--disable-gpu`
  is needed, else GPU compositing over the forwarded display draws a see-through window
- the NSS DB, `~/.pki/nssdb`, and the home dir are lost on rebuild: setup registers the module
  with `modutil` each time; `beid-update-nssdb` errors on a new DB. The Chromium profile, with
  the extension, goes in `.local/eid/chromium/` through `--user-data-dir`, so it survives
- BeIDConnect's native messaging manifest goes in `/etc/chromium/native-messaging-hosts/`,
  from its package's postinst

## BeIDConnect, built in the devcontainer

- a `beidconnect` recipe clones
  [Fedict/fts-beidconnect](https://github.com/Fedict/fts-beidconnect) at a tag pinned in
  `versions.just`, with its commit, into `.local/eid/src/`, and builds a `.deb` in
  `.local/eid/debs/` with the repo's own `debian/`, named after the tag; so it survives a
  rebuild, and only a bumped pin builds anew
- done: `debian/`'s postinst runs `beidconnect -setup`, which writes the native messaging
  manifests, Chromium's in `/etc/chromium/native-messaging-hosts/`; reinstalling after a
  rebuild writes them anew
- setup installs that `.deb`, building it first if it's missing; a first setup takes longer
- its build dependencies, like boost, go in the Dockerfile's install line like any package;
  they stay, as removing them makes reruns slower and setup less idempotent
- packing a `.deb`, rather than `make install`, lets apt track and remove it, and setup can
  reinstall it after a rebuild without building again
- done: the extension's Web Store page hangs in this Chromium, so a managed policy
  force-installs it from the store's update server; signing needs `--no-xshm`, as the upload
  dialog crashed Chromium with a `BadShmSeg` otherwise

## Steps

Each step ends with a check that must pass before the next, and gets its own commit; a step is
checked once it's done and ready to commit.

1. [x] host check: `getfacl` on the reader's node shows the user's ACL
2. [x] new `eid/` component: `justfile`, idempotent `setup` called from the root's, state in
   `.local/eid/`, `docs/udd/`; flattened into the root in step 8
3. [x] packages: the eID repo, the `polkitd` stub, `pcscd`, `libccid`, `pcsc-tools`, `opensc`,
   `eid-mw`, `eid-viewer`; in the Dockerfile and by hand, per the conventions
4. [x] reader: the bus link and mount into devcontainer.json, and pcscd started; done when
   `pcsc_scan` sees the reader and the card, also after a replug and a pcscd restart
5. [x] middleware: done when `pkcs11-tool --module libbeidpkcs11.so.0 -L` lists the card and
   `eid-viewer` reads it
6. [x] authentication: Chromium, its launcher recipe and the NSS registration; done when a CSAM
   login with the card succeeds
7. [x] signing: the `beidconnect` recipe, setup installs the `.deb` and its manifest, and the
   extension goes into the profile; done when a document signs on a BeIDConnect signing page
8. [x] flatten `eid/` into the root, as the repo has no other purpose: one `justfile`, recipes
   without the `eid::` prefix, `versions.just`, `env/` and `docs/udd/` in the root; state stays
   in `.local/eid/`, next to `.local/host/`. Done when setup, start and the recipes work as
   before, and lint passes
9. [x] adapt the bump skill, `.agents/skills/testbed-bump-versions/`, to the pins in
   `versions.just`, like the BeIDConnect tag, and rename it
10. [x] document the host prerequisites in `docs/udd/` and the usage in the README

## Open questions

None for now.
