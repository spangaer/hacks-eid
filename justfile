# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

import 'versions.just'

set shell := ["bash", "-euo", "pipefail", "-c"]

# runtime state, gitignored; it survives a rebuild
local := justfile_directory() / ".local" / "eid"

# list recipes
default:
    @just --list

# the eID repo, a polkitd stub, pcscd, the middleware, BeIDConnect, and Chromium's config
# devcontainer setup, run on create; safe to rerun
setup:
    env/setup.sh {{ quote(local) }} {{ eid_archive_version }} {{ quote(eid_archive_url) }} \
        {{ eid_archive_sha256 }} {{ quote(beidconnect_repo) }} {{ beidconnect_tag }} \
        {{ beidconnect_commit }}

# pcscd, with the reader's bus linked
# devcontainer services, run on start; safe to rerun
start:
    env/start.sh

# restart pcscd, to see a replugged reader, as nothing tells it in the container
restart:
    env/start.sh restart

# setup does it too, and installs it
# build BeIDConnect's .deb from the pinned tag into .local/eid/debs/, if it isn't there
beidconnect:
    env/beidconnect.sh {{ quote(local) }} {{ quote(beidconnect_repo) }} {{ beidconnect_tag }} \
        {{ beidconnect_commit }}

# watch readers and cards come and go, through pcscd; Ctrl+C to stop
scan:
    pcsc_scan

# list the card's token through the PKCS#11 module, as browsers see it
card:
    pkcs11-tool --module libbeidpkcs11.so.0 -L

# the eID viewer: the card's data, its certificates, and a PIN test
viewer:
    eid-viewer

# --disable-gpu, as over the forwarded X display, GPU compositing draws a see-through window;
# --no-xshm, as the X server, on the host, can't attach the container's shared memory, and the
# BadShmSeg that follows kills Chromium, e.g. on opening a file dialog. GTK's settings, like the
# file dialog's, in memory, as dconf needs a D-Bus session bus, and floods the log without one.
#
# Chromium, with its profile in .local/, so it survives a rebuild; args go to Chromium, like a URL
[positional-arguments]
chromium *args:
    mkdir -p {{ quote(local / "chromium") }}
    GSETTINGS_BACKEND=memory chromium --user-data-dir={{ quote(local / "chromium") }} \
        --disable-gpu --no-xshm "$@"

# Chromium at the government's test login, which logs in with the card through CSAM
login: (chromium "https://iamapps.belgium.be/tma")

# Chromium at the federal signing service, which signs through BeIDConnect
sign: (chromium "https://sign.belgium.be")

# git's file list and reuse skip what .gitignore excludes, like .local/
# lint licensing and all shell scripts
lint:
    reuse lint
    git ls-files -z --cached --others --exclude-standard '*.sh' | xargs -0 shellcheck -x

# use this, not reuse annotate --recursive
# add an SPDX header to files without one, skipping those REUSE.toml covers
annotate license="MIT" holder="Jean-Luc Deprez <https://github.com/spangaer>":
    .reuse/annotate.sh {{ quote(license) }} {{ quote(holder) }}
