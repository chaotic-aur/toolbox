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

  echo "Cleaning \"${1:-}\"..."
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
    rm -vrf --one-file-system "$entry"
  done

  return 0
}

function clean-duplicates() {
  set -euo pipefail

  if [[ "$CAUR_TYPE" != 'primary' ]]; then
    echo 'Only primary node needs to de-dup.'
    return 0
  fi

  pushd "${CAUR_DEPLOY_PKGS}"

  local _DUPLICATED _TO_MV _U_SURE

  _DUPLICATED=$(
    # shellcheck disable=SC2010
    ls \
      | grep -Po "^(.*)(?=(?:(?:-[^-]*){3}\.pkg\.tar(?>\.xz|\.zst)?)\.sig$)" \
      | uniq -d
  )

  if [[ -z "${_DUPLICATED}" ]]; then
    echo "No duplicate packages were found!"
  else
    _TO_MV=$(
      echo "${_DUPLICATED[@]}" \
        | awk '{print "find -name \""$1"*\" -printf \"%T@ %p\\n\" | sort -n | grep -Po \"\\.\\/"$1"(((-[^-]*){3}\\.pkg\\.tar(?>\\.xz|\\.zst)?))\\.sig$\" | head -n -1;"}' \
        | bash \
        | awk '{sub(/\.sig$/,"");print $1"\n"$1".sig"}'
    )

    echo "[!] Moving:"
    echo "${_TO_MV[*]}"

    echo "[!] Total: $(echo -n "${_TO_MV[*]}" | wc -l)"
    if [[ "${1:-}" == '-q' ]]; then
      _U_SURE='Y'
    else
      read -r -p "[?] Are you sure? [y/N] " _U_SURE
    fi

    case "${_U_SURE}" in
    [yY])
      # shellcheck disable=SC2086
      mv -v -f -t ../archive/ ${_TO_MV[*]}
      ;;
    esac
  fi

  popd # CAUR_DEPLOY_PKGS

  return 0
}

function clean-pkgcache() {
  set -euo pipefail

  pushd "${CAUR_CACHE_PKG}"

  local _DUPLICATED _TO_MV _U_SURE

  _DUPLICATED=$(
    # shellcheck disable=SC2010
    ls \
      | grep -Po "^(.*)(?=(?:(?:-[^-]*){3}\.pkg\.tar(?>\.xz|\.zst)?)$)" \
      | uniq -d
  )

  if [[ -z "${_DUPLICATED}" ]]; then
    echo "No duplicate packages were found!"
  else
    _TO_MV=$(
      echo "${_DUPLICATED[@]}" \
        | awk '{print "find -name \""$1"*\" -printf \"%T@ %p\\n\" | sort -n | grep -Po \"\\.\\/"$1"(((-[^-]*){3}\\.pkg\\.tar(?>\\.xz|\\.zst)?))$\" | head -n -1;"}' \
        | bash \
        | awk '{print $1"\n"$1".sig"}'
    )

    echo "[!] Deleting:"
    echo "${_TO_MV[*]}"

    echo "[!] Total: $(echo -n "${_TO_MV[*]}" | wc -l)"
    if [[ "${1:-}" == '-q' ]]; then
      _U_SURE='Y'
    else
      read -r -p "[?] Are you sure? [y/N] " _U_SURE
    fi

    case "${_U_SURE}" in
    [yY])
      # shellcheck disable=SC2086
      rm -vf ${_TO_MV[*]}
      ;;
    esac
  fi

  popd # CAUR_CACHE_PKG

  return 0
}
