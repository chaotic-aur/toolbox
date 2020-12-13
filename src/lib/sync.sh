#!/usr/bin/env bash

function sync() {
  set -euo pipefail

  pushd "${CAUR_INTERFERE}"
  git pull --ff-only
  git submodule update --init
  popd #CAUR_INTERFERE

  return 0
}
