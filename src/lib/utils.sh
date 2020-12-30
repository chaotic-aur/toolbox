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
  '0' | 'host' | 'n' | 'auto')
    CAUR_PARALLEL="$(nproc)"
    ;;
  [0-9]*)
    CAUR_PARALLEL="$_JOBN"
    ;;
  *)
    echo 'Wrong number of parallel jobs.'
    return 27
    ;;
  esac

  export CAUR_PARALLEL
  return 0
}

function reset-fakeroot-chown() {
  # https://podman.io/blogs/2018/10/03/podman-remove-content-homedir.html
  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
      singularity --silent exec --fakeroot \
        -B "${1}:/what-is-mine" \
        "${CAUR_DOCKER_ALPINE}" \
        chown -R 0:0 /what-is-mine  # give me back
  fi
}
