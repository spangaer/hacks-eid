#!/usr/bin/env bash

# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

# Devcontainer setup for the e-ID: the eID repo, a polkitd stub and the packages that need them;
# safe to rerun, it skips what's there. Debian's own packages are in the Dockerfile.
# usage: setup.sh <state dir> <eid-archive url> <eid-archive sha256>
set -euo pipefail

state=$1 archive_url=$2 archive_sha256=$3
cache=$state/cache debs=$state/debs

# no tty in postCreateCommand: noninteractive spares the debconf fallback chatter
apt() { sudo DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

# whether all the given packages are installed; dpkg-query fails if one is unknown
installed() {
    local status
    status=$(dpkg-query -W -f '${db:Status-Status}\n' "$@" 2> /dev/null) || return 1
    ! grep -qvx installed <<< "$status"
}

mkdir -p "$cache" "$debs"

# the repo's own package: its postinst writes the apt source for this release, its key too
if ! installed eid-archive; then
    deb=$cache/${archive_url##*/}
    if [[ ! -f $deb ]]; then
        curl -fsSL -o "$deb.tmp" "$archive_url"
        mv "$deb.tmp" "$deb"
    fi
    echo "$archive_sha256  $deb" | sha256sum -c --quiet
    apt install -y "$deb"
    apt update
fi

# pcscd depends on polkitd, which needs a D-Bus system bus, which needs the systemd the
# Dockerfile pins out; pcscd runs with --disable-polkit instead, so a stub stands in
stub=$debs/polkitd-stub_1.0_all.deb
if [[ ! -f $stub ]]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cat > "$tmp/control" << 'CTL'
Section: misc
Priority: optional
Standards-Version: 4.7.0
Package: polkitd-stub
Version: 1.0
Provides: polkitd
Description: stands in for polkitd, for pcscd without polkit
 pcscd runs with --disable-polkit in the devcontainer, where polkitd can't run, as it needs
 systemd.
CTL
    (cd "$tmp" && equivs-build control > /dev/null)
    mv "$tmp/${stub##*/}" "$stub"
fi
if ! installed polkitd-stub; then apt install -y "$stub"; fi

# eid-mw's recommends are readers' drivers; Debian's libccid covers the ACS reader
pkgs=(pcscd eid-mw eid-viewer)
if ! installed "${pkgs[@]}"; then
    apt install -y --no-install-recommends "${pkgs[@]}"
fi

# Chromium reads PKCS#11 modules from ~/.pki/nssdb, not its profile, so it's lost on rebuild.
# modutil, not beid-update-nssdb, which errors on a new DB, as it first deletes the module.
nssdb=$HOME/.pki/nssdb
if ! grep -qs libbeidpkcs11 "$nssdb/pkcs11.txt"; then
    mkdir -p "$nssdb"
    [[ -f $nssdb/cert9.db ]] || certutil -d "sql:$nssdb" -N --empty-password
    modutil -force -dbdir "sql:$nssdb" -add "Belgium eID" -libfile libbeidpkcs11.so.0
fi
