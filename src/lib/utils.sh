#!/usr/bin/env bash

function mount-overlayfs() {
  set -euo pipefail

  if [[ "$CAUR_OVERLAY_TYPE" == 'fuse' ]]; then
    fuse-overlayfs "$@"
  else
    mount overlay -t overlay "$@"
  fi

  return 0
}

function optional-parallel() {
  set -euo pipefail

  local _JOBN

  _JOBN="${1:-}"

  case "$_JOBN" in
  [0-9]*)
    export CAUR_PARALLEL="$2"
    ;;
  *)
    echo 'Wrong number of parallel jobs.'
    return 27
    ;;
  esac

  return 0
}
