# e-ID

A Belgian e-ID card in a reader on the host, used from Chromium in the devcontainer, for
authentication and signing, without giving the devcontainer privileges.

Work in progress: the target and the steps to it are in [PLAN.eid/](../../../PLAN.eid/README.md),
until they're built and described here.

The why of a single detail is in a comment next to it. These pages cover what spans files.

Paths are relative to `eid/`, except `.devcontainer/` and `.local/` in the repo root. Run
recipes with `just` in `eid/`, or as `just eid::<recipe>` from the root.

## State

`.local/eid/`, made by `just setup`; it survives a rebuild.
