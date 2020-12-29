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
  local _INPUTDIR _PARAMS _PKGTAG _INTERFERE \
    _LOWER _HOME _CCACHE _SRCCACHE _PKGDEST \
    _CAUR_WIZARD _MECHA_NAME _BUILD_FAILED \
    _CONTAINER_ARGS

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"
  _PARAMS=("${@:2}")

  if [[ ! -f "${_INPUTDIR}/PKGTAG" ]]; then
    echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
    return 14
  elif [[ -f "${_INPUTDIR}/PKGBUILD" ]]; then
    echo "\"${_INPUTDIR}\" was not prepared yet."
    return 15
  elif [[ -f "${_INPUTDIR}/building.pid" ]]; then
    echo 'This package is already building.'
    return 16
  fi

  echo -n $$ >"${_INPUTDIR}/building.pid"

  if [[ ! -e "${CAUR_LOWER_DIR}/latest" ]]; then
    (lowerstrap) || return $?
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

  _HOME="machine/root/home/main-builder"
  _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
  _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
  _PKGDEST="${_HOME}/pkgdest"
  _CAUR_WIZARD="machine/root/home/main-builder/${CAUR_BASH_WIZARD}"

  mkdir -p machine/{up,work,root} dest{,.work} "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" "${CAUR_DEST_PKG}"
  mount-overlayfs -olowerdir="${_LOWER}",upperdir='machine/up',workdir='machine/work' 'machine/root'

  mount --bind 'pkgwork' "${_HOME}/pkgwork"
  mount --bind "${_CCACHE}" "${_HOME}/.ccache"
  mount --bind "${_SRCCACHE}" "${_HOME}/pkgsrc"
  mount --bind "${CAUR_CACHE_PKG}" 'machine/root/var/cache/pacman/pkg'
  mount-overlayfs \
    -olowerdir="${CAUR_DEST_PKG}",upperdir='./dest',workdir='./dest.work' \
    "${_PKGDEST}"

  cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
  chmod 755 "${_CAUR_WIZARD}"

  _CONTAINER_ARGS=()
  [[ -f 'CONTAINER_ARGS' ]] && mapfile -t _CONTAINER_ARGS <CONTAINER_ARGS

  _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
  _BUILD_FAILED=''
  systemd-nspawn -M "${_MECHA_NAME}" \
    -u "root" \
    --capability=CAP_IPC_LOCK,CAP_SYS_NICE \
    -D machine/root "${_CONTAINER_ARGS[@]}" \
    "/home/main-builder/wizard.sh" "${_PARAMS[@]+"${_PARAMS[@]}"}" || local _BUILD_FAILED="$?"

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
  popd # "${_INPUTDIR}"
  [[ -n "${_BUILD_FAILED}" ]] \
    && return ${_BUILD_FAILED}
  return 0
}

function makepkg-singularity() {
  local _INPUTDIR _PARAMS _PKGTAG _INTERFERE \
    _LOWER _HOME _CCACHE _SRCCACHE _CAUR_WIZARD \
    _BUILD_FAILED _MECHA_NAME _SANDBOX

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"
  _PARAMS=("${@:2}")

  if [[ ! -f "${_INPUTDIR}/PKGTAG" ]]; then
    echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
    return 14
  elif [[ -f "${_INPUTDIR}/PKGBUILD" ]]; then
    echo "\"${_INPUTDIR}\" was not prepared yet."
    return 15
  elif [[ -f "${_INPUTDIR}/building.pid" ]]; then
    echo 'This package is already building.'
    return 16
  fi

  echo -n $$ >"${_INPUTDIR}/building.pid"

  if [[ ! -e "${CAUR_LOWER_DIR}/latest" ]]; then
    (lowerstrap) || return $?
  fi

  pushd "${_INPUTDIR}"
  [[ -e 'building.result' ]] && rm 'building.result'
  _PKGTAG=$(cat PKGTAG)
  _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"
  _LOWER="$(
    cd "${CAUR_LOWER_DIR}"
    readlink -f latest
  )"

  _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
  _SANDBOX="${CAUR_SANDBOX}/${_MECHA_NAME}"
  mkdir -p "${CAUR_SANDBOX}"
  # we need to remove files inside an user namespace, otherwise we won't have permission to remove files owned by non-root
  # shellcheck disable=SC2064
  trap "singularity --silent exec -B '${CAUR_SANDBOX}':/sandbox --fakeroot docker://alpine rm -rf /sandbox/'${_MECHA_NAME}'" EXIT HUP INT TERM ERR
  singularity build --sandbox "${_SANDBOX}" "${_LOWER}"

  _HOME="/home/main-builder"
  _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
  _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
  _CAUR_WIZARD="${_SANDBOX}/home/main-builder/${CAUR_BASH_WIZARD}"

  mkdir -p "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" "./dest"

  cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
  chmod 755 "${_CAUR_WIZARD}"

  _BUILD_FAILED=''
  singularity exec --writable --fakeroot --no-home --containall \
    -B "./pkgwork:${_HOME}/pkgwork" \
    -B "./dest:${_HOME}/pkgdest" \
    -B "${_CCACHE}:${_HOME}/.ccache" \
    -B "${_SRCCACHE}:${_HOME}/pkgsrc" \
    -B "${CAUR_CACHE_PKG}:/var/cache/pacman/pkg" \
    "${_SANDBOX}" \
    "/home/main-builder/wizard.sh" "${_PARAMS[@]+"${_PARAMS[@]}"}" || local _BUILD_FAILED="$?"

  if [[ -z "${_BUILD_FAILED}" ]]; then
    echo 'success' >'building.result'
  elif [[ -f "${_INTERFERE}/on-failure.sh" ]]; then
    echo "${_BUILD_FAILED}" >'building.result'
    # shellcheck source=/dev/null
    source "${_INTERFERE}/on-failure.sh"
  fi

  rm 'building.pid'
  popd # "${_INPUTDIR}"
  [[ -n "${_BUILD_FAILED}" ]] \
    && return ${_BUILD_FAILED}
  return 0
}
