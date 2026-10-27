#!/usr/bin/env bash

# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

# Devcontainer setup for the e-ID: the eID repo, a polkitd stub and the packages that need them;
# safe to rerun, it skips what's there. Debian's own packages are in the Dockerfile.
# usage: setup.sh <state dir> <eid-archive version> <url> <sha256> <beidconnect repo> <tag>
#   <commit>
set -euo pipefail

state=$1 archive_version=$2 archive_url=$3 archive_sha256=$4
bc_repo=$5 bc_tag=$6 bc_commit=$7
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

# the repo's own package: its postinst writes the apt source for this release, its key too;
# installed again on a bumped pin, as a new one may bring a new key
if [[ $(dpkg-query -W -f '${Version}' eid-archive 2> /dev/null) != "$archive_version" ]]; then
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

# BeIDConnect has no Linux package anywhere, so it's built here, once per pinned tag; installing
# it again after a rebuild reruns its postinst, which writes the native messaging manifests
"$(dirname "$0")/beidconnect.sh" "$state" "$bc_repo" "$bc_tag" "$bc_commit"
if [[ $(dpkg-query -W -f '${Version}' beidconnect 2> /dev/null) != "$bc_tag" ]]; then
    apt install -y "$debs/beidconnect_${bc_tag}_$(dpkg --print-architecture).deb"
fi

# The BeIDConnect extension, force-installed by policy from the Web Store's update server, as its
# page hangs in this Chromium; the ID is the store's, which the manifests allow. /etc is lost on
# rebuild, so it's written each time.
sudo install -d /etc/chromium/policies/managed
sudo tee /etc/chromium/policies/managed/beidconnect.json > /dev/null << 'JSON'
{
    "ExtensionInstallForcelist": [
        "pencgnkbgaekikmiahiaakjdgaibiipp;https://clients2.google.com/service/update2/crx"
    ]
}
JSON

# signing/, in the repo root: uploads/, for documents to sign from Chromium, and downloads/, for
# what it saves, like signed documents; out of .local/, as Chromium's GTK file dialog shows dot
# dirs badly. Both are bookmarked in that dialog; the bookmarks are in the home dir.
signing=$(cd "$(dirname "$0")/.." && pwd)/signing
bookmarks=$HOME/.config/gtk-3.0/bookmarks
mkdir -p "$signing/uploads" "$signing/downloads" "${bookmarks%/*}"
for dir in uploads downloads; do
    line="file://$signing/$dir $dir"
    grep -qsxF "$line" "$bookmarks" || echo "$line" >> "$bookmarks"
done

# recommended, not managed, so it can be changed in Chromium's settings
sudo install -d /etc/chromium/policies/recommended
printf '{ "DownloadDirectory": "%s" }\n' "$signing/downloads" |
    sudo tee /etc/chromium/policies/recommended/downloads.json > /dev/null
