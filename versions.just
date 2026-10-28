# the eID repo's own package, which adds its apt source and signing key; checksum from the repo's
# trixie index, dists/trixie/main/binary-amd64/Packages
eid_archive_version := "2026.1"
eid_archive_url := "https://files.eid.belgium.be/debian/pool/main/e/eid-archive/eid-archive_" \
    + eid_archive_version + "_all.deb"
eid_archive_sha256 := "782bd92f70dd58e919900479d3094ddeaf18517d44725a1557b1ac6e10efdb8c"

# BeIDConnect, the native messaging host for the BeIDConnect extension, built from source; the
# commit guards against a moved tag
beidconnect_repo := "https://github.com/Fedict/fts-beidconnect.git"
beidconnect_tag := "2.12"
beidconnect_commit := "72c0aa243f2118a8f55c8ccaae16961ede9abcf6"
