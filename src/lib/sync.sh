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

  pushd "${CAUR_PACKAGES}"
  git pull --ff-only || true
  popd #CAUR_PACKAGES

  return 0
}
