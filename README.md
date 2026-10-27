# hacks-eid

A devcontainer to use a Belgian e-ID card from inside it: a smartcard reader on the host, made
available to the e-ID middleware in the devcontainer, so Chromium there can log in and sign with
it. How it works: [docs/udd/](./docs/udd/README.md).

It started as a fork of [k8s-testbed](https://github.com/spangaer/k8s-testbed), for the way it
gets `/dev/kvm` into the devcontainer without giving it privileges; that pattern lives on in
[usb-bus-link.sh](./.devcontainer/usb-bus-link.sh).

The code itself has no ambition to be production grade.

Sources are thrown online with proper license notices, just in case anyone would want to put
them to use anyway.

## Usage

Check the [host prerequisites](./docs/udd/README.md#host-prerequisites) first.

1. plug in the reader, then open the repo in its devcontainer; creating it runs `just setup`,
   which takes a while the first time, as it builds BeIDConnect
2. insert the card, and check each layer, from the reader up:
   - `just scan`: the reader and the card, Ctrl+C to stop
   - `just card`: the card's token, through the PKCS#11 module
   - `just viewer`: the card's data, and a PIN test
3. `just login`: log in with the card at the government's test login, through CSAM
4. `just sign`: sign at `https://sign.belgium.be`; put documents in `signing/uploads/`, and
   pick them with the file dialog's Open button, as a double-click or Enter cancels it. Signed
   copies land in `signing/downloads/`

`just chromium [url]` opens Chromium, with the card, for any other site. `just` lists all
recipes.

- replugged the reader: `just restart`, as pcscd doesn't notice in the container
- moved it to a port on another USB bus, like a dock's: rebuild the container
- newer eID packages or BeIDConnect: bump the pins in [versions.just](./versions.just), with the
  [bump skill](./.agents/skills/bump-versions/SKILL.md), then `just setup`
