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
  - `beidconnect`, built here, see below; its build dependencies, `libboost-dev` and
    `libpcsclite-dev`, are in the Dockerfile

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
- `just eid::chromium https://iamapps.belgium.be/tma`: the government's test login, with the
  card, through CSAM
- `just eid::sign`: Chromium at the federal signing service, `https://sign.belgium.be`, which
  signs through BeIDConnect

## Chromium

```
Chromium ── NSS ── ~/.pki/nssdb/pkcs11.txt: library=libbeidpkcs11.so.0
                └─ libbeidpkcs11 ── pcscd ── the card: certificates, keys, PIN
```

- PKCS#11 is the standard C API to crypto devices, like smartcards; a module is a vendor's
  library that implements it for its device, here `libbeidpkcs11.so.0`, from eid-mw
- on Linux, Chromium handles certificates through NSS, which knows no cards nor pcscd; it loads
  the modules listed in its DB, `~/.pki/nssdb`, and shows what they offer. Without the entry,
  the card is invisible: no client certificate for a login like CSAM's
- the entry is just the library's name; the module reads the card through pcscd when asked, so
  certificates come and go with the card, and the PIN and signing stay on it
- the DB is in the home dir, not Chromium's profile, so it's lost on rebuild: `just setup`
  adds the entry if it's missing. With `modutil`, as `beid-update-nssdb`, meant for a desktop
  login, errors on a new DB; and Debian's Chromium ignores eid-mw's p11-kit config
- `just eid::chromium [args]`: its profile, in `.local/eid/chromium/`, survives a rebuild;
  args, like a URL, go to Chromium
- the sandbox works as is; `--disable-gpu`, as GPU compositing over the forwarded X display
  draws a see-through window; `--no-xshm`, as the X server, on the host, can't attach the
  container's shared memory, and the error kills Chromium, e.g. on a file dialog
- the D-Bus errors it logs are harmless: the container has no system bus. GTK's settings, like
  the file dialog's hidden files toggle, are kept in memory, `GSETTINGS_BACKEND=memory`, as
  dconf needs a session bus; so they last until Chromium closes
- `signing/`, in the repo root, gitignored, has `uploads/`, for documents to sign, and
  `downloads/`, Chromium's download folder by a recommended policy; both are bookmarked in its
  file dialog, which shows dot dirs badly. Setup makes them, and the policy and bookmarks, as
  `/etc` and the home dir are lost on rebuild

## Signing: BeIDConnect

```
signing page ── BeIDConnect extension ── native messaging
                                              └─ beidconnect ── pcscd ── the card
```

- the signing page asks the extension, which runs `beidconnect`, by its manifest in
  `/etc/chromium/native-messaging-hosts/`, over stdin and stdout; it reads the card through
  pcscd itself, not through eid-mw
- the PIN is typed on the page, which sends it along with the request, unless the reader has a
  pinpad; the ACR38U has none. So type it only on a trusted signing page, like
  `https://sign.belgium.be`. A login is different: there, eid-mw's own dialog asks for it
- no Linux package anywhere, so `just eid::beidconnect` builds one, with the repo's own
  `debian/`, from the tag pinned in [versions.just](../../versions.just), checked against its
  commit, into `.local/eid/debs/`; `just setup` builds it if it's missing, and installs it.
  Its postinst writes the manifests, so a reinstall after a rebuild restores them
- the extension, from the Chrome Web Store, whose ID the manifests allow, is force-installed by
  a managed policy from setup, as its store page hangs here; so it can't be removed from
  Chromium

## State

`.local/eid/`, made by `just setup`; it survives a rebuild.

- `cache/`: downloads, named after their version
- `debs/`: packages built here, like `polkitd-stub`
- `chromium/`: Chromium's profile
- `src/`: sources built here, like BeIDConnect's
