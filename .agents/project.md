# Project structure & building instructions

## Layout

The repo is a devcontainer for a single purpose, the Belgian e-ID, so it's flat: one `justfile`,
its scripts and docs in the root.

```
.devcontainer/    the devcontainer: package installs, host device pass-through, environment
justfile          all recipes; just lists them
versions.just     pinned versions and checksums, imported by the justfile
env/              the scripts behind the recipes, like setup and start
docs/udd/         how it fits together; read it before changing anything
.agents/          agent instructions and skills, see the index below
.local/           runtime state and caches, gitignored, survives a rebuild: eid/ for the e-ID,
                  host/ for the links usb-bus-link.sh makes on the host
signing/          documents to sign and signed ones, gitignored; visible for Chromium's dialog
PLAN.<ticket>/    the plan for the ticket in the branch name, if any
```

The agent index is [README.md](./README.md). The design: [docs/udd/](../docs/udd/README.md).

## Conventions

- devcontainer changes must apply to the running container too: install packages by hand with
  the Dockerfile's `apt-get install` line, and put setup logic in the idempotent `setup` recipe,
  never only in the Dockerfile
- giving the devcontainer privileges is off limits; a host device only goes in when the host
  already grants it to the user, through a link checked on the host, like
  [usb-bus-link.sh](../.devcontainer/usb-bus-link.sh)'s: rootless, the host's permissions are
  the boundary, and a USB bus dir is the widest a pass-through goes
- state goes in `.local/eid/`, never the home dir or `/etc` alone: both are lost on rebuild,
  so what has to live there, setup writes anew
- no license or copyright headers: everything is under the root's MIT-0 [LICENSE](../LICENSE)
- the why of a detail goes in a comment next to it; what spans files goes in `docs/udd/`
