---
name: bump-versions
description: 'Bump the pinned versions and checksums in versions.just: the eID repo''s
  eid-archive package, and BeIDConnect''s tag and commit. Use when asked to update, upgrade,
  bump or refresh pins, versions, checksums, eid-archive, the eID repo or BeIDConnect, or to
  check whether newer versions exist.'
---

# Bump the pinned versions

Every download or source that apt doesn't verify is pinned in
[versions.just](../../../versions.just), with its checksum or commit:

- `eid_archive_*`: the eID repo's own package, which brings its apt source and signing key;
  cached in `.local/eid/cache/` under a file name that carries the version
- `beidconnect_*`: the tag BeIDConnect is built from, and its commit, which guards against a
  moved tag; built into `.local/eid/debs/` as `beidconnect_<tag>_<arch>.deb`

A bump fetches or builds anew and leaves the old files. The eID repo's other packages, like
`eid-mw`, aren't pinned: apt verifies them with the key `eid-archive` brings, and `apt-get
upgrade` updates them.

## Rules

- checksums come from upstream's signed index, never from hashing a download: `eid-archive`'s
  from the trixie `Packages`, checked against `InRelease`, which must verify with the installed
  `eid-archive`'s key; [latest.sh](./scripts/latest.sh) handles it
- if `InRelease` doesn't verify, the repo may have moved to a new key: stop and report; a new
  key must be checked out of band, on `https://eid.belgium.be`, before pinning anything signed
  with it
- BeIDConnect follows its highest version tag; it has no GitHub releases. The tag becomes the
  `.deb`'s version, so it must start with a digit
- bump all pins together, as one change, unless the user picks some

## Procedure

1. Run `.agents/skills/bump-versions/scripts/latest.sh`. It changes nothing, and prints each
   pin, marked with `*` and followed by the new value where it differs. If no pin differs,
   report that and stop.
2. For a new BeIDConnect tag, skim what changed, at
   `https://github.com/Fedict/fts-beidconnect/compare/<old>...<new>`, and mention what matters:
   changes to `debian/`, like `Build-Depends` or the postinst, to the native messaging setup,
   or to the build.
3. Edit [versions.just](../../../versions.just): only the values, keep its comments and
   expressions. Check with `just --evaluate <name>`, and rerun `latest.sh`: it must report 0
   differing.
4. Apply with `just setup`, then validate by what changed, stopping at the first failure:
   - `eid-archive`: `dpkg-query -W eid-archive` shows the new version, and setup's
     `apt-get update` had no signature errors for `files.eid.belgium.be`
   - BeIDConnect: setup builds the `.deb` first, which takes minutes. If `dpkg-buildpackage`
     reports unmet build dependencies, add them to the Dockerfile's `apt-get install` line and
     install them by hand, per [project.md](../../project.md), then rerun setup.
     `beidconnect -version < /dev/null` prints the new tag, and
     `/etc/chromium/native-messaging-hosts/be.bosa.beidconnect.json` exists
   - always: `just card` lists the card's token, if a card is in the reader
5. BeIDConnect's final check needs the user, with the card and its PIN: ask them to sign a
   document from `just sign`. Don't type a PIN yourself.
6. Old files are only removed when asked: `.local/eid/cache/eid-archive_<old>_all.deb` and
   `.local/eid/debs/beidconnect_<old>_<arch>.deb`. Keeping the latter makes reverting the pins
   cheap, as setup then installs it without building.
7. Report old and new values and what ran. Write `commit-message.md`, following the commit
   rules in [AGENTS.md](../../../AGENTS.md), naming the versions, not the checksums. Don't
   commit.

## Sources

What [latest.sh](./scripts/latest.sh) reads, for when it breaks:

- `eid_archive_*`: `https://files.eid.belgium.be/debian/dists/trixie/InRelease`, verified with
  `/usr/share/eid-archive/keys/released.gpg`, its `SHA256` of
  `main/binary-<arch>/Packages`, and in that file, the newest `eid-archive` stanza's `Version`
  and `SHA256`; its `Filename` must be the pool path `eid_archive_url` builds
- `beidconnect_*`: `git ls-remote --tags` on `beidconnect_repo`, the highest tag of the form
  `[v]N.N…`, sorted without the `v`, and its commit: the tag's `^{}` if annotated
