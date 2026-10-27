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

## State

`.local/eid/`, made by `just setup`; it survives a rebuild.

- `cache/`: downloads, named after their version
- `debs/`: packages built here, like `polkitd-stub`
