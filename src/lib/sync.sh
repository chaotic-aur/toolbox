#!/usr/bin/env bash

function iterfere-sync() {
  set -euo pipefail

  pushd "${CAUR_INTERFERE}"
  git pull --ff-only || true
  popd #CAUR_INTERFERE

  return 0
}

function packages-sync() {
  set -euo pipefail

  pushd "${CAUR_PACKAGE_LISTS}"
  git pull --ff-only || true
  popd #CAUR_PACKAGE_LISTS

  return 0
}
