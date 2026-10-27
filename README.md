# hacks-eid

A devcontainer to use a Belgian e-ID card from inside it: a smartcard reader on the host, made
available to the e-ID middleware in the devcontainer, so Chromium there can authenticate with it.
Work in progress, see [PLAN.eid/](./PLAN.eid/README.md).

It started as a fork of [k8s-testbed](https://github.com/spangaer/k8s-testbed), for the way it
gets `/dev/kvm` into the devcontainer without giving it privileges; that pattern lives on in
[device-link.sh](./.devcontainer/device-link.sh).

The code itself has no ambition to be production grade.

Sources are thrown online with proper license notices, just in case anyone would want to put
them to use anyway.

## Usage

Open the repo in its devcontainer; creating it runs `just setup`. `just` lists all recipes.
