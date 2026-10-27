# Project structure & building instructions

## Layout

The repo is a devcontainer with self-contained components next to each other. Each component
has its own folder with a `justfile` and its own docs; new code goes in a new folder beside
them, rather than into an existing one.

```
.devcontainer/    the devcontainer: package installs, host device pass-through, environment
justfile          mounts each component as a just module, plus repo-wide recipes
eid/              Belgian e-ID in the devcontainer, see its docs/udd/
.agents/          agent instructions and skills, see the index below
.local/           runtime state and caches, a dir per component; gitignored, survives a rebuild
PLAN.<ticket>/    the plan for the ticket in the branch name, if any
```

The agent index is [README.md](./README.md).

Components:

- [eid/](../eid/): a Belgian e-ID reader on the host, used from Chromium in the devcontainer;
  read [docs/udd/](../eid/docs/udd/README.md) before changing it

## Recipes

`just` lists the recipes where it runs: in the root, the repo-wide ones and the modules; in a
component's folder, that component's. From the root, a module's recipes run as
`just <module>::<recipe>`, but its variables can only be set in its folder, e.g.
`cd <module> && just var=value <recipe>`.

## Conventions

- devcontainer changes must apply to the running container too: install packages by hand with
  the Dockerfile's `apt-get install` line, and put setup logic in an idempotent `setup` recipe,
  which the root's `setup` calls, never only in the Dockerfile
- giving the devcontainer privileges is off limits; a host device only goes in when the host
  already grants it to the user, through the probe and link of
  [device-link.sh](../.devcontainer/device-link.sh)
- a component keeps its state in `.local/<component>/`
- every new file gets an SPDX header, MIT: run `just annotate`, never
  `reuse annotate --recursive`, which can't skip what `REUSE.toml` covers: Markdown and
  `.gitignore` under MIT-0, and JSON other than VS Code's JSONC under MIT; `just lint` checks
  it all
- the why of a detail goes in a comment next to it; what spans files goes in the component's
  `docs/udd/`
