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
    popd # _INPUTDIR
    return 11
  elif [[ ! -e 'PKGTAG' ]] && [[ ! -e 'PKGBUILD' ]]; then
    echo 'Invalid package directory.'
    popd # _INPUTDIR
    return 12
  fi

  if [[ -d 'machine/root' ]]; then
    umount -Rv 'machine/root'
  fi

  if [[ "$CAUR_CLEAN_ONLY_DEPLOYED" == '1' ]] \
    && { [[ ! -f 'building.result' ]] \
      || [[ "$(cat building.result)" != 'deployed' ]]; }; then
    popd # _INPUTDIR
    return 0
  fi

  popd # _INPUTDIR

  reset-fakeroot-chown "${_INPUTDIR}"
  rm --one-file-system -rf "${_INPUTDIR}"

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

  if [[ ! -e "$_PKG_CACHE_DIR"/* ]]; then
    echo 'Empty cache directory.'
    return 0
  fi

  rm -rf --one-file-system "$_PKG_CACHE_DIR"/*
}
