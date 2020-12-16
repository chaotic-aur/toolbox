#!/usr/bin/env bash

function iterfere-sync() {
  set -euo pipefail

  pushd "${CAUR_INTERFERE}"
  git pull --ff-only || true
  popd #CAUR_INTERFERE

  return 0
}
