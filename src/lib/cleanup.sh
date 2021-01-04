#!/usr/bin/env bash

function cleanup() {
  set -euo pipefail

  local _INPUTDIR

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"

  pushd "${_INPUTDIR}"

  if [[ -e 'building.pid' ]]; then
    echo "Package is still building in PID: $(cat building.pid)."
    return 11
  elif [[ ! -e 'PKGTAG' ]] && [[ ! -e 'PKGBUILD' ]]; then
    echo 'Invalid package directory.'
    return 12
  fi

  if [[ -d 'machine/root' ]]; then
    umount -Rv 'machine/root'
  fi

  if [[ "$CAUR_CLEAN_ONLY_SUCCESS" == '1' ]]; then
    [[ -f 'building.result' ]] || return 0
    [[ "$(cat building.result)" == 'success' ]] || return 0
  fi

  popd # _INPUTDIR

  reset-fakeroot-chown "${_INPUTDIR}"
  rm --one-file-system -rf "${_INPUTDIR}"

  return 0
}
