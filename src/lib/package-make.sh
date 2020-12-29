#!/usr/bin/env bash

function makepkg() {
  set -euo pipefail

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

  _HOME="machine/root/home/${CAUR_GUEST_USER}"
  _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
  _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
  _PKGDEST="${_HOME}/pkgdest"
  _CAUR_WIZARD="machine/root/home/${CAUR_GUEST_USER}/${CAUR_BASH_WIZARD}"

  mkdir -p machine/{up,work,root} dest{,.work} "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" "${CAUR_DEST_PKG}"
  fuse-overlayfs -olowerdir="${_LOWER}",upperdir='machine/up',workdir='machine/work' 'machine/root'
  chown "${CAUR_GUEST_UID}":"${CAUR_GUEST_GID}" "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" dest

  mount --bind 'pkgwork' "${_HOME}/pkgwork"
  mount --bind "${_CCACHE}" "${_HOME}/.ccache"
  mount --bind "${_SRCCACHE}" "${_HOME}/pkgsrc"
  mount --bind "${CAUR_CACHE_PKG}" 'machine/root/var/cache/pacman/pkg'
  fuse-overlayfs \
    -olowerdir="${CAUR_DEST_PKG}",upperdir='./dest',workdir='./dest.work' \
    "${_PKGDEST}"

  cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
  chown "${CAUR_GUEST_UID}":"${CAUR_GUEST_GID}" -R "${_CAUR_WIZARD}" pkgwork
  chmod 755 "${_CAUR_WIZARD}"

  _CONTAINER_ARGS=()
  [[ -f 'CONTAINER_ARGS' ]] && mapfile -t _CONTAINER_ARGS <CONTAINER_ARGS

  _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
  _BUILD_FAILED=''
  systemd-nspawn -M "${_MECHA_NAME}" \
    -u "root" \
    --capability=CAP_IPC_LOCK,CAP_SYS_NICE \
    -D machine/root "${_CONTAINER_ARGS[@]}" \
    "/home/${CAUR_GUEST_USER}/wizard.sh" "${_PARAMS[@]+"${_PARAMS[@]}"}" || local _BUILD_FAILED="$?"

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
