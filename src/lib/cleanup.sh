#!/usr/bin/env bash

function cleanup() {
  set -euo pipefail

  local _INPUTDIR

  _INPUTDIR="$(
    cd "$1"
    pwd -P
  )"

  pushd "${_INPUTDIR}"

  if [[ -e 'building.pid' ]]; then
    echo "Package is still building in PID: $(cat building.pid)."
    return 11
  elif [[ ! -e 'PKGTAG' ]]; then
    echo 'Invalid package directory.'
    return 12
  fi

  if [[ -d 'machine/root' ]]; then
    umount -Rv 'machine/root'
  fi

  popd # _INPUTDIR

  rm --one-file-system -rf "${_INPUTDIR}"
  return 0
}
