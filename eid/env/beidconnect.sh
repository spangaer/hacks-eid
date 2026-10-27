#!/usr/bin/env bash

# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

# Build BeIDConnect's .deb, with its own debian/, from a pinned tag, into <state>/debs/; skips it
# if it's there. Its postinst writes the browsers' native messaging manifests.
# usage: beidconnect.sh <state dir> <repo> <tag> <commit>
set -euo pipefail

state=$1 repo=$2 tag=$3 commit=$4
src=$state/src/fts-beidconnect
deb=$state/debs/beidconnect_${tag}_$(dpkg --print-architecture).deb

[[ -f $deb ]] && exit 0

if [[ ! -d $src/.git ]]; then
    mkdir -p "${src%/*}"
    git clone -q "$repo" "$src"
fi
git -C "$src" fetch -q --tags origin
got=$(git -C "$src" rev-parse "refs/tags/$tag^{commit}")
if [[ $got != "$commit" ]]; then
    echo "beidconnect: tag $tag is $got, not the pinned $commit" >&2
    exit 1
fi
git -C "$src" checkout -q --detach "$commit"
git -C "$src" clean -qfdx

# debian/changelog stops at 0.0.8, eidlink's; the package takes its version from the top entry
changelog=$src/debian/changelog
{
    printf 'beidconnect (%s) unstable; urgency=medium\n\n' "$tag"
    printf '  * Built from tag %s, commit %s\n\n' "$tag" "${commit:0:7}"
    printf ' -- hacks-eid <hacks-eid@localhost>  %s\n\n' "$(date -R)"
    cat "$changelog"
} > "$changelog.new"
mv "$changelog.new" "$changelog"

# dpkg-buildpackage puts its output next to the source dir
(cd "$src" && dpkg-buildpackage -us -uc -b)
mv "${src%/*}/${deb##*/}" "$deb"
rm -f "${src%/*}"/beidconnect*_"$tag"_*
git -C "$src" checkout -q -- debian/changelog
git -C "$src" clean -qfdx
