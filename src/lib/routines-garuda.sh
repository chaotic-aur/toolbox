#!/usr/bin/env bash

function routine-garuda() {
  set -euo pipefail
  clean-xdg
  interfere-sync
  push-routine-dir 'garuda'

  [[ -d "_repo" ]] && rm -rf --one-file-system '_repo'
  git clone 'https://gitlab.com/garuda-linux/pkgbuilds.git' '_repo'
  mv _repo/* .
  
  (makepwd) || true

  clean-logs
  popd #routine-dir
  return 0
}
