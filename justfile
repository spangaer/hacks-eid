# SPDX-FileCopyrightText: Jean-Luc Deprez <https://github.com/spangaer>
# SPDX-License-Identifier: MIT

set shell := ["bash", "-euo", "pipefail", "-c"]

# the e-ID component's recipes, e.g. just eid::setup
mod eid

# list recipes
default:
    @just --list --list-submodules

# calls each component's setup as just <module>::setup
# devcontainer setup, run on create; safe to rerun
setup:
    just eid::setup

# calls each component's start as just <module>::start
# devcontainer services, run on start; safe to rerun
start:
    just eid::start

# git's file list and reuse skip what .gitignore excludes, like .local/
# lint licensing and all shell scripts
lint:
    reuse lint
    git ls-files -z --cached --others --exclude-standard '*.sh' | xargs -0 shellcheck -x

# use this, not reuse annotate --recursive
# add an SPDX header to files without one, skipping those REUSE.toml covers
annotate license="MIT" holder="Jean-Luc Deprez <https://github.com/spangaer>":
    .reuse/annotate.sh {{ quote(license) }} {{ quote(holder) }}
