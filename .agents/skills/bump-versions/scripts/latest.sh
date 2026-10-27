#!/usr/bin/env bash

# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

# Resolve the latest upstream value of each pin in versions.just: eid-archive from the eID repo's
# signed index, BeIDConnect's newest tag and its commit; print them next to the current ones.
# Changes nothing.
# usage: latest.sh
set -euo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

die() {
    echo "latest.sh: $*" >&2
    exit 1
}
# bounded; --retry covers timeouts
get() { curl -fsSL --retry 3 --max-time 60 "$@"; }
current() { just --justfile "$root/justfile" --evaluate "$1"; }

declare -A want
order=()
pin() {
    [[ $2 =~ ^[0-9a-zA-Z.+~-]+$ ]] || die "odd value for $1: '$2'"
    want[$1]=$2
    order+=("$1")
}

# --- eid-archive: the newest in the trixie index; the index is checked against InRelease, and
# that against the key the installed eid-archive brings, as apt does

repo=https://files.eid.belgium.be/debian
keyring=/usr/share/eid-archive/keys/released.gpg
index=main/binary-$(dpkg --print-architecture)/Packages
[[ -f $keyring ]] || die "no $keyring, run just setup first"
get -o "$tmp/InRelease" "$repo/dists/trixie/InRelease"
# only what the signature covers goes on, in Release
gpgv --keyring "$keyring" --output "$tmp/Release" "$tmp/InRelease" 2> "$tmp/gpgv.log" || {
    cat "$tmp/gpgv.log" >&2
    die "$repo/dists/trixie/InRelease doesn't verify with $keyring; if the repo moved to a" \
        "new key, check the new eid-archive by hand, see SKILL.md"
}
sum=$(awk -v f="$index" '/^[^ ]/ { s = /^SHA256:/; next } s && $3 == f { print $1; n++ }
    END { exit n != 1 }' "$tmp/Release") || die "no $index in $repo/dists/trixie/InRelease"
get -o "$tmp/Packages" "$repo/dists/trixie/$index"
echo "$sum  $tmp/Packages" | sha256sum -c --quiet - \
    || die "$repo/dists/trixie/$index doesn't match InRelease"

# all eid-archive stanzas, as `<version> <filename> <sha256>`; the newest by Debian's ordering
version='' file='' sum=''
while read -r v f s; do
    if [[ ! $version ]] || dpkg --compare-versions "$v" gt "$version"; then
        version=$v file=$f sum=$s
    fi
done < <(awk -v RS= -F '\n' '/(^|\n)Package: eid-archive(\n|$)/ {
        for (i = 1; i <= NF; i++) if (split($i, kv, ": ") == 2) f[kv[1]] = kv[2]
        print f["Version"], f["Filename"], f["SHA256"]
    }' "$tmp/Packages")
[[ $version ]] || die "no eid-archive in $repo/dists/trixie/$index"
# versions.just builds the URL from the version, so the pool path must follow suit
[[ $file == "pool/main/e/eid-archive/eid-archive_${version}_all.deb" ]] \
    || die "eid-archive $version is at $file, which eid_archive_url doesn't build"
pin eid_archive_version "$version"
pin eid_archive_sha256 "$sum"

# --- BeIDConnect: the highest version tag, and the commit it points to

bc_repo=$(current beidconnect_repo)
git ls-remote --tags "$bc_repo" > "$tmp/tags" || die "can't list the tags of $bc_repo"
# older tags have a v; sorted without it
tag=$(awk '{ t = $2; sub("^refs/tags/", "", t) } t ~ /^v?[0-9]+(\.[0-9]+)*$/ {
        v = t; sub("^v", "", v); print v, t
    }' "$tmp/tags" | sort -V -k 1,1 | awk 'END { print $2 }')
[[ $tag ]] || die "no version tags in $bc_repo"
# beidconnect.sh makes it the package's version, which must start with a digit
[[ $tag == [0-9]* ]] || die "newest tag $tag isn't a Debian version, see beidconnect.sh"
# an annotated tag also lists the commit it points to, as ^{}, which sorts last
commit=$(awk -v t="refs/tags/$tag" '$2 == t || $2 == t "^{}"' "$tmp/tags" | sort -k 2 \
    | awk 'END { print $1 }')
[[ $commit =~ ^[0-9a-f]{40}$ ]] || die "no commit for tag $tag in $bc_repo"
pin beidconnect_tag "$tag"
pin beidconnect_commit "$commit"

# --- report, changed pins marked with *

changed=0
for name in "${order[@]}"; do
    have=$(current "$name")
    if [[ $have == "${want[$name]}" ]]; then
        printf '  %-19s %s\n' "$name" "$have"
    else
        printf '* %-19s %s\n  %-19s -> %s\n' "$name" "$have" "" "${want[$name]}"
        changed=$((changed + 1))
    fi
done
echo "$changed of ${#order[@]} pins differ"
