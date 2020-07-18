#!/usr/bin/env bash

function package-sync() {
    set -o errexit

    pushd "$CAUR_PACKAGES"
    git pull --ff-only
    git submodule update
    popd
}
