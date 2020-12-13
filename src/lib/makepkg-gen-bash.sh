#!/usr/bin/env bash

function prepare() {
  set -euo pipefail

  local _PKGDIR _PARAMS _PKGTAG _INTERFERE _LS

  _PKGDIR="$(
    cd "$1"
    pwd -P
  )"
  _PARAMS=("${@:2}")

  if [[ -e "${_PKGDIR}/PKGTAG" ]]; then
    echo "Package already was prepared."
    return 0
  elif [[ ! -e "${_PKGDIR}/PKGBUILD" ]]; then
    echo "Invalid parameter, \"${_PKGDIR}\" does not contains a PKGBUILD."
    return 10
  fi

  pushd "${_PKGDIR}"
  _PKGTAG="$(basename "$PWD")"
  _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"

  _LS=(*)
  mkdir 'pkgwork'
  mv "${_LS[@]}" 'pkgwork/'

  echo -n "${_PKGTAG}" >'PKGTAG'
  makepkg-gen-bash-init "${_PKGDIR}"

  pushd 'pkgwork'
  interference-apply "${_INTERFERE}"
  popd # pkgwork

  interference-makepkg "${_PARAMS[@]}"

  popd #_PKGDIR
  makepkg-gen-bash-finish

  return 0
}

function makepkg-gen-bash-init() {
  set -euo pipefail

  local _DEST="$1"

  export CAUR_WIZARD="${_DEST}/${CAUR_BASH_WIZARD}"
  echo '#!/usr/bin/env bash' | tee "${CAUR_WIZARD}" >/dev/null
  export CAUR_PUSH="makepkg-gen-bash-append"

  return 0
}

function makepkg-gen-bash-append() {
  set -euo pipefail

  echo "${@}" | tee -a "${CAUR_WIZARD}" >/dev/null

  return 0
}

function makepkg-gen-bash-finish() {
  set -euo pipefail

  unset CAUR_PUSH
  unset CAUR_WIZARD

  return 0
}
