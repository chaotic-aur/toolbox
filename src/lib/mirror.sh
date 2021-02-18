#!/usr/bin/env bash

function help-mirror() {
  set -euo pipefail

  local _MIRROR_TYPE="${1:-}"

  case "${_MIRROR_TYPE}" in
  'syncthing')
    echo "Sorry, I haven't automated this yet!"
    echo '1) Install syncthing'
    echo '2) Add my device: ZDHVMSP-EW4TMWX-DBH2W4P-HV5A6OY-BBEFABO-QTENANJ-RJ6GKNX-6KCG7QY'
    echo '3) Add folder "jhcrt-m2dra" as "Receive Only" with "Ignore Permissions" and "Pull Order" by "Oldest First".'
    echo '4) Wait for me to accept it!'
    ;;
  'rsync')
    echo "Sorry, I haven't automated this yet!"
    echo '1) Install rsync'
    echo '2) Run this script once: https://gist.github.com/BangL/86c2700e169994bc147ebf076fcb1888'
    echo '3) Schedule it to run each 15 minutes'
    ;;
  *)
    echo 'Unsupported protocol.'
    ;;
  esac

  return 0
}
