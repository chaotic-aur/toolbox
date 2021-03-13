#!/usr/bin/env bash

function cleanup() {
  set -euo pipefail

  local _INPUTDIR _LOCK_FN _LOCK_FD

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"

  _LOCK_FN="${_INPUTDIR}.lock"
  touch "${_LOCK_FN}"
  exec {_LOCK_FD}<>"${_LOCK_FN}" # Lock

  if ! flock -x -n "$_LOCK_FD"; then
    if [[ -e "${_INPUTDIR}/building.pid" ]]; then
      echo "Package is still building in PID: $(cat "${_INPUTDIR}/building.pid")."
    else
      echo 'Package is still in use by another chaotic script.'
    fi

    return 11
  fi

  pushd "${_INPUTDIR}"

  if [[ ! -e 'PKGTAG' ]] && [[ ! -e 'PKGBUILD' ]]; then
    echo 'Invalid package directory.'
    popd               # _INPUTDIR
    exec {_LOCK_FD}>&- # Unlock
    return 12
  fi

  if [[ -d 'machine/root' ]]; then
    if ! (umount -Rv 'machine/root' || rmdir 'machine/root'); then
      echo 'Package rootfs is still busy.'
      popd               # _INPUTDIR
      exec {_LOCK_FD}>&- # Unlock
      return 11
    fi
  fi

  if [[ "$CAUR_CLEAN_ONLY_DEPLOYED" == '1' ]] \
    && { [[ ! -f 'building.result' ]] \
      || [[ "$(cat building.result)" != 'deployed' ]]; }; then
    popd               # _INPUTDIR
    exec {_LOCK_FD}>&- # Unlock
    return 0
  fi

  popd # _INPUTDIR

  reset-fakeroot-chown "${_INPUTDIR}"
  rm --one-file-system -rf "${_INPUTDIR}"

  exec {_LOCK_FD}>&- # Unlock

  return 0
}

function clean-srccache() {
  set -euo pipefail

  local _PKG_CACHE_DIR

  if [[ -z "${1:-}" ]]; then
    echo 'Invalid parameters'
    return 34
  fi

  _PKG_CACHE_DIR="${CAUR_CACHE_SRC}/${1}"

  if [[ ! -d "$_PKG_CACHE_DIR" ]]; then
    echo 'Invalid parameters or empty cache directory.'
    echo "$_PKG_CACHE_DIR"
    return 0
  fi

  _PKG_CACHE_DIR="$(
    cd "${_PKG_CACHE_DIR}"
    pwd -P
  )"

  if [[ "$_PKG_CACHE_DIR" != "$CAUR_CACHE_SRC/"* ]]; then
    echo 'Stop trying to destroy my machine!'
    return 35
  fi

  for entry in "$_PKG_CACHE_DIR"/*; do
    if [[ ! -e "$entry" ]]; then
      echo 'Empty cache directory.'
      return 0
    fi
    rm -rf --one-file-system "$entry"
  done

  return 0
}
