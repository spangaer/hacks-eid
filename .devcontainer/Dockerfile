# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

FROM mcr.microsoft.com/devcontainers/base:2.2-trixie

# keep systemd and friends out, they misbehave in containers
# priority -1 makes apt skip them as recommends and fail loudly on hard dependencies
RUN printf '%s\n' \
      'Package: systemd systemd-sysv init dbus dbus-user-session libpam-systemd' \
      'Pin: release *' \
      'Pin-Priority: -1' \
    > /etc/apt/preferences.d/no-systemd

# ripgrep: used by copilot for code search
# just: simpler more portable make
# tk: Tcl/Tk runtime (wish) for the bundled git gui and gitk
# shellcheck: lint for shell scripts
# iputils-ping: ping, for basic network reachability checks
# dnsutils: dig and nslookup, for debugging DNS resolution
# reuse: license and copyright header lint, see https://reuse.software/
RUN apt-get update && apt-get install -y time ripgrep just tk shellcheck iputils-ping \
      dnsutils reuse

# e-ID tooling, see docs/udd/; pcscd, eid-mw and eid-viewer aren't here: they need the eID repo
# and a polkitd stub first, which just setup provides
# libccid: driver for USB CCID smartcard readers, like the ACS ACR38U
# pcsc-tools: pcsc_scan, to see readers and cards
# opensc: pkcs11-tool, to test the PKCS#11 module
# chromium: the browser that's to use the card
# equivs: builds the polkitd stub package
# libboost-dev, libpcsclite-dev: BeIDConnect's build dependencies, it's built in setup
RUN apt-get update && apt-get install -y --no-install-recommends \
      libccid pcsc-tools opensc chromium equivs libboost-dev libpcsclite-dev
