#!/usr/bin/env bash

function aur-download() {
  set -euo pipefail

  local _LIST _PACKAGES _PKGBASE _REPOCTL _GIT _OUT
  _REPOCTL=()
  declare -A _GIT
  _PACKAGES="$(find "${CAUR_PACKAGE_LISTS}" -name '*.txt' | while read -r _LIST; do parse-package-list "$_LIST"; done)"
  for _PKGBASE in "$@"; do
    _OUT="$(awk -F ':' -v pkgbase="${_PKGBASE}" '$1==pkgbase { OFS = FS; $1=""; print substr($0, 2); exit }' <<<"$_PACKAGES")"
    if [[ -z "${_OUT}" ]]; then
      _REPOCTL+=("${_PKGBASE}")
    else
      _GIT["${_PKGBASE}"]="${_OUT}"
    fi
  done

  if [ ${#_REPOCTL[@]} -ne 0 ]; then
    repoctl down "${_REPOCTL[@]}"
  fi
  for _PKGBASE in "${!_GIT[@]}"; do
    git clone --depth 1 "${_GIT[${_PKGBASE}]}" "${_PKGBASE}"
  done
}
