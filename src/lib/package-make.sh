#!/usr/bin/env bash

function makepkg() {
  set -euo pipefail

  if [[ "${CAUR_ENGINE}" = "systemd-nspawn" ]]; then
    makepkg-systemd-nspawn "$@"
  elif [[ "${CAUR_ENGINE}" = "singularity" ]]; then
    makepkg-singularity "$@"
  else
    echo "Unsupported engine '${CAUR_ENGINE}'"
    return 25
  fi
}

function makepkg-systemd-nspawn() {
  set -euo pipefail

  local _INPUTDIR _PKGTAG _INTERFERE _ROOTDIR \
    _LOWER _HOME _CCACHE _SRCCACHE _PKGDEST \
    _CAUR_WIZARD _MECHA_NAME _BUILD_FAILED \
    _CONTAINER_ARGS _LOCK_FD _LOCK_FN _FAILURE

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"
  # Note: there is usage of "${@:2}" below.

  _LOCK_FN="${_INPUTDIR}.lock"
  touch "${_LOCK_FN}"
  exec {_LOCK_FD}<>"${_LOCK_FN}" # Lock

  if ! flock -x -n "$_LOCK_FD"; then
    echo 'This package is already building.'
    exec {_LOCK_FD}>&- # Unlock
    return 16
  elif [[ ! -f "${_INPUTDIR}/PKGTAG" ]]; then
    echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
    exec {_LOCK_FD}>&- # Unlock
    return 14
  elif [[ -f "${_INPUTDIR}/PKGBUILD" ]]; then
    echo "\"${_INPUTDIR}\" was not prepared yet."
    exec {_LOCK_FD}>&- # Unlock
    return 15
  fi

  echo -n $$ >"${_INPUTDIR}/building.pid"

  if [[ ! -e "${CAUR_LOWER_DIR}/latest" ]] && ! lowerstrap; then
    _FAILURE=$?
    exec {_LOCK_FD}>&- # Unlock
    return ${_FAILURE}
  fi

  pushd "${_INPUTDIR}"
  [[ -e 'building.result' ]] && rm 'building.result'
  _PKGTAG=$(cat PKGTAG)
  _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"
  _LOWER="$(
    cd "${CAUR_LOWER_DIR}"
    cd "$(readlink latest)"
    pwd -P
  )"

  echo "Building package \"${_PKGTAG}\""

  _ROOTDIR='machine/root'
  _HOME="${_ROOTDIR}/home/main-builder"
  _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
  _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
  _PKGDEST="${_ROOTDIR}/var/pkgdest"
  _CAUR_WIZARD="machine/root/home/main-builder/${CAUR_BASH_WIZARD}"

  install -o"$(whoami)" -dDm755 machine/{up,work,root} dest "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}"
  mount-overlayfs -olowerdir="${_LOWER}",upperdir='machine/up',workdir='machine/work' 'machine/root'
  chown 1000:1000 'dest'

  mount --bind 'pkgwork' "${_HOME}/pkgwork"
  mount --bind "${_CCACHE}" "${_HOME}/.ccache"
  mount --bind "${_SRCCACHE}" "${_HOME}/pkgsrc"
  mount --bind "${CAUR_CACHE_PKG}" 'machine/root/var/cache/pacman/pkg'
  mount --bind 'dest' "${_PKGDEST}"

  (fill-dest)

  cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
  chmod 755 "${_CAUR_WIZARD}"

  [[ -f 'CONTAINER_ARGS' ]] && _CONTAINER_ARGS="$(<CONTAINER_ARGS)"

  _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
  _BUILD_FAILED=''
  #shellcheck disable=SC2086
  systemd-nspawn -M "${_MECHA_NAME}" \
    -u "root" \
    --capability=CAP_IPC_LOCK,CAP_SYS_NICE \
    -D machine/root ${_CONTAINER_ARGS:-} \
    "/home/main-builder/wizard.sh" "${@:2}" || local _BUILD_FAILED="$?"

  if [[ -z "${_BUILD_FAILED}" ]]; then
    echo 'success' >'building.result'
  elif [[ -f "${_INTERFERE}/on-failure.sh" ]]; then
    echo "${_BUILD_FAILED}" >'building.result'
    # shellcheck source=/dev/null
    source "${_INTERFERE}/on-failure.sh"
  fi

  umount -Rv machine/root \
    && rm --one-file-system -rf machine

  rm 'building.pid'
  exec {_LOCK_FD}>&- # Unlock

  popd # "${_INPUTDIR}"
  [[ -n "${_BUILD_FAILED}" ]] \
    && return ${_BUILD_FAILED}
  return 0
}

function makepkg-singularity() {
  set -euo pipefail

  local _INPUTDIR _PKGTAG _INTERFERE _FAILURE \
    _LOWER _HOME _CCACHE _SRCCACHE _CAUR_WIZARD \
    _BUILD_FAILED _MECHA_NAME _SANDBOX _LOCK_FD _LOCK_FN

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"
  # Note: there is usage of "${@:2}" below.

  _LOCK_FN="${_INPUTDIR}.lock"
  touch "${_LOCK_FN}"
  exec {_LOCK_FD}<>"${_LOCK_FN}" # Lock

  if ! flock -x -n "$_LOCK_FD"; then
    echo 'This package is already building.'
    exec {_LOCK_FD}>&- # Unlock
    return 16
  elif [[ ! -f "${_INPUTDIR}/PKGTAG" ]]; then
    echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
    exec {_LOCK_FD}>&- # Unlock
    return 14
  elif [[ -f "${_INPUTDIR}/PKGBUILD" ]]; then
    echo "\"${_INPUTDIR}\" was not prepared yet."
    exec {_LOCK_FD}>&- # Unlock
    return 15
  fi

  echo -n $$ >"${_INPUTDIR}/building.pid"

  if [[ ! -e "${CAUR_LOWER_DIR}/latest" ]] && ! lowerstrap; then
    _FAILURE=$?
    exec {_LOCK_FD}>&- # Unlock
    return ${_FAILURE}
  fi

  pushd "${_INPUTDIR}"
  [[ -e 'building.result' ]] && rm 'building.result'
  _PKGTAG=$(cat PKGTAG)
  _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"
  _LOWER="$(
    cd "${CAUR_LOWER_DIR}"
    readlink -f latest
  )"

  echo "Building package \"${_PKGTAG}\""

  if ! install -o"$(whoami)" -dDm755 "${CAUR_SANDBOX}"; then
    exec {_LOCK_FD}>&- # Unlock
    return 32
  fi

  _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
  _SANDBOX="${CAUR_SANDBOX}/${_MECHA_NAME}"
  if [[ -e "${_SANDBOX}" ]]; then
    echo "Sandbox ${_SANDBOX} already exists. Trying to clean it up..."
    singularity --silent exec -B "${CAUR_SANDBOX}:/sandbox" --fakeroot "${CAUR_DOCKER_ALPINE}" rm -rf "/sandbox/${_MECHA_NAME}"

    if [[ -e "${_SANDBOX}" ]]; then
      echo "It was not possible to clean ${_SANDBOX}"
      exec {_LOCK_FD}>&- # Unlock
      return 30
    fi
  fi

  singularity build --sandbox "${_SANDBOX}" "${_LOWER}"

  _HOME="/home/main-builder"
  _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
  _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
  _CAUR_WIZARD="${_SANDBOX}/home/main-builder/${CAUR_BASH_WIZARD}"

  install -o"$(whoami)" -dDm755 "${CAUR_CACHE}" || return 32
  mkdir -p "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" "./dest"

  (fill-dest)

  cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
  chmod 755 "${_CAUR_WIZARD}"

  _BUILD_FAILED=''
  singularity exec --writable --fakeroot --no-home --containall --workdir /tmp \
    -B "./pkgwork:${_HOME}/pkgwork" \
    -B "./dest:/var/pkgdest" \
    -B "${_CCACHE}:${_HOME}/.ccache" \
    -B "${_SRCCACHE}:${_HOME}/pkgsrc" \
    -B "${CAUR_CACHE_PKG}:/var/cache/pacman/pkg" \
    "${_SANDBOX}" \
    "/home/main-builder/wizard.sh" "${@:2}" || local _BUILD_FAILED="$?"

  # we need to remove files inside an user namespace, otherwise we won't have permission to remove files owned by non-root
  singularity --silent exec -B "${CAUR_SANDBOX}:/sandbox" --fakeroot "${CAUR_DOCKER_ALPINE}" rm -rf "/sandbox/${_MECHA_NAME}"

  if [[ -z "${_BUILD_FAILED}" ]]; then
    echo 'success' >'building.result'
  elif [[ -f "${_INTERFERE}/on-failure.sh" ]]; then
    echo "${_BUILD_FAILED}" >'building.result'
    # shellcheck source=/dev/null
    source "${_INTERFERE}/on-failure.sh"
  fi

  rm 'building.pid'
  exec {_LOCK_FD}>&- # Unlock

  popd # "${_INPUTDIR}"
  [[ -n "${_BUILD_FAILED}" ]] \
    && return ${_BUILD_FAILED}
  return 0
}

function fill-dest() {
  set -euo pipefail

  pushd 'dest'

  curl -s "$CAUR_FILL_DEST" \
    | sed 's/\//.pkg.tar.zst/g' | xargs touch

  popd # dest

  return 0
}

function unfill-dest() {
  set -euo pipefail

  find . -type f -empty -delete || return 28

  return 0
}
