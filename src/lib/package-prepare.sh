#!/usr/bin/env bash

function prepare() {
  set -euo pipefail

  local _PKGDIR _PKGTAG _INTERFERE _LS

  _PKGDIR="$(
    cd "${1:-}"
    pwd -P
  )"
  # Note: there is usage of "${@:2}" below.

  if [[ -e "${_PKGDIR}/PKGTAG" ]]; then
    echo "Package already was prepared."
    return 0
  elif [[ ! -e "${_PKGDIR}/PKGBUILD" ]]; then
    echo "Invalid parameter, \"${_PKGDIR}\" does not contain a PKGBUILD."
    return 10
  fi

  pushd "${_PKGDIR}"
  if [[ -f 'PKGBASE' ]]; then
    _PKGTAG="$(<PKGBASE)"
  else
    _PKGTAG="$(basename "$PWD")"
  fi
  _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"

  mapfile -t _LS < <(find . -maxdepth 1 -mindepth 1)
  install -o"$(whoami)" -dm755 'pkgwork'
  mv "${_LS[@]}" 'pkgwork/'

  [[ -f 'pkgwork/PKGBASE' ]] && mv 'pkgwork/PKGBASE' ./
  [[ -f 'pkgwork/PKGVAR' ]] && mv 'pkgwork/PKGVAR' ./
  echo -n "${_PKGTAG}" >'PKGTAG'

  makepkg-gen-bash-init "${_PKGDIR}"

  pushd 'pkgwork'
  interference-apply "${_INTERFERE}"
  popd # pkgwork

  interference-makepkg "${@:2}"
  interference-finish

  popd #_PKGDIR
  makepkg-gen-bash-finish

  echo "Finished preparing ${_PKGTAG}."

  return 0
}

function makepkg-gen-bash-init() {
  set -euo pipefail

  local _DEST="${1:-}"

  export CAUR_WIZARD="${_DEST}/${CAUR_BASH_WIZARD}"
  stee "${CAUR_WIZARD}" <<EOF
#!/usr/bin/bash
source /etc/profile

EOF
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
