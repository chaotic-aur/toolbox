#!/usr/bin/env bash

function cleanup() {
  set -euo pipefail

  local _INPUTDIR _LOCK_FN _LOCK_FD

  if [[ ! -d "${1:-}" ]]; then
    echo 'Request for cleaning something that is not a directory.'
    return 0
  fi

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
  rm-as-root "${_INPUTDIR}"

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
    echo 'Invalid parameters or non-exiting cache directory.'
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

  if [[ ! -d "$CAUR_DEPLOY_PKGS" ]]; then
    echo 'Deploying directory not found.'
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
        | sed 's/\+/\\+/g' \
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
      echo "${_TO_MV[@]}" | xargs mv -v -f -t ../archive/
      # Make sure we don't instantly delete them from archive if the package is too old
      echo "${_TO_MV[@]}" | xargs touch --no-create
      ;;
    esac
  fi

  popd # CAUR_DEPLOY_PKGS

  return 0
}

function clean-pkgcache() {
  set -euo pipefail

  if [[ ! -d "$CAUR_CACHE_PKG" ]]; then
    echo 'Non-exiting cache directory'
    return 0
  fi

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
      echo "${_TO_MV[@]}" | xargs rm -vf
      ;;
    esac
  fi

  popd # CAUR_CACHE_PKG

  return 0
}

function clean-archive() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  # Let's save time!
  (clean-duplicates -q) || true

  if [[ ! -d "${CAUR_DEPLOY_PKGS}/../archive" ]]; then
    echo 'Non-exiting archive directory'
    return 0
  fi

  pushd "${CAUR_DEPLOY_PKGS}/../archive"

  find . -type f -mtime +7 -name '*' -execdir rm -- '{}' \; || true

  popd
  return 0
}

function clean-sigs() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  local _TO_MV=()

  pushd "${CAUR_DEPLOY_PKGS}"

  readarray -d '' _TO_MV < <(find . -name "*.pkg.${CAUR_DB_EXT}" -mmin +59 -exec sh -c '[[ ! -f "${1}.sig" ]]' -- "{}" \; -print0)
  readarray -d '' -O "${#_TO_MV[@]}" _TO_MV < <(find . -name "*.pkg.${CAUR_DB_EXT}.sig" -mmin +59 -exec sh -c '[[ ! -f "${1%.*}" ]]' -- "{}" \; -print0)

  if [[ -z "${_TO_MV:-}" ]]; then
    if [[ "${1:-}" != '-q' ]]; then
      echo '[!] Nothing to do...'
    fi
    exit 0
  fi

  echo '[!] Missing sig or archive:'
  printf '%s\n' "${_TO_MV[@]}"

  echo "[!] Total: ${#_TO_MV[@]}"
  if [[ "${1:-}" == '-q' ]]; then
    _U_SURE='Y'
  else
    read -r -p "[?] Are you sure? [y/N] " _U_SURE
  fi

  case "${_U_SURE}" in
  [yY])
    # shellcheck disable=SC2086
    echo "${_TO_MV[@]}" | xargs mv -v -f -t ../archive/
    # Make sure we don't instantly delete them from archive if the package is too old
    echo "${_TO_MV[@]}" | xargs touch --no-create
    ;;
  esac

  popd

  return 0
}

function clean-post-routine() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  (clean-archive -q) || true
  (clean-sigs -q) || true

  return 0
}
