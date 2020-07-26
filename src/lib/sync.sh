#!/usr/bin/env bash

function sync() {
    set -euo pipefail

    pushd "${CAUR_PACKAGES}"
    git pull --ff-only
    git submodule update
    popd

    return 0
}
