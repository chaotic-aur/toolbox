#!/usr/bin/env bash

function routine-tkg-wine() {
  set -euo pipefail
  clean-xdg
  iterfere-sync
  push-routine-dir 'tkg.wine'

  [[ -d "_repo" ]] && rm -rf --one-file-system '_repo'
  git clone 'https://github.com/Frogging-Family/wine-tkg-git.git' '_repo'

  local _VARIATIONS _VARIATION _i _DEST _PROFILES _VARIATION_WITHOUT_EXT

  _PROFILES='_repo/wine-tkg-git/wine-tkg-profiles'

  pushd "${_PROFILES}"
  _VARIATIONS=(./chaotic-*.cfg)
  popd
  echo "Building: ${_VARIATIONS[*]}"

  [[ "${_VARIATIONS[*]}" == './chaotic-*.cfg' ]] && return 0

  _i=0
  for _VARIATION in "${_VARIATIONS[@]}"; do
    _i=$((_i + 1))
    _DEST="wine-tkg-git.$(printf '%04d' $_i)"
    _VARIATION_WITHOUT_EXT="${_VARIATION%.cfg}"

    mkdir "$_DEST"
    cp -r '_repo/wine-tkg-git'/* "$_DEST/"
    echo 'wine-tkg' >"$_DEST/PKGBASE"
    echo "${_VARIATION_WITHOUT_EXT##./chaotic-}" >"$_DEST/PKGVAR"

    pushd "$_DEST"
    echo '' >'wine-tkg-profiles/advanced-customization.cfg'
    cat 'wine-tkg-profiles/sample-external-config.cfg' >./customization.cfg
    cat "wine-tkg-profiles/$_VARIATION" >>./customization.cfg
    popd
  done

  rm -rf --one-file-system '_repo' || true

  (makepwd) || true
  clean-logs
  popd #routine-dir
  return 0
}
