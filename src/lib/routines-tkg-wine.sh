#!/usr/bin/env bash

function tkg-wine-variate() {
  set -euo pipefail

  local _use_staging _use_vkd3dlib

  _use_staging='false'
  _use_vkd3dlib='false'

  if [[ 'lol' == "${1:-}" ]]; then
    _use_staging='true'
  else
    [[ 'staging' == "${1:-}" ]] && _use_staging='true'
    [[ 'vkd3d-mainline' == "${2:-}" ]] && _use_vkd3dlib='true'
  fi

  sed "
  s/_NUKR=\"[^\"]*\"/_NUKR=\"false\"/g
  s/_NOINITIALPROMPT=\"[^\"]*\"/_NOINITIALPROMPT=\"true\"/g
  s/_use_staging=\"[^\"]*\"/_use_staging=\"${_use_staging}\"/g
  s/_use_vkd3dlib=\"[^\"]*\"/_use_vkd3dlib=\"${_use_vkd3dlib}\"/g
  s/_proton_fs_hack=\"[^\"]*\"/_proton_fs_hack=\"true\"/g
  s/_FS_bypass_compositor=\"[^\"]*\"/_FS_bypass_compositor=\"true\"/g
  s/_win10_default=\"[^\"]*\"/_win10_default=\"true\"/g
  s/_protonify=\"[^\"]*\"/_protonify=\"true\"/g
  s/_community_patches=\"[^\"]*\"/_community_patches=\"amdags.mypatch\"/g
  s/_user_patches_no_confirm=\"[^\"]*\"/_user_patches_no_confirm=\"true\"/g
  s/_hotfixes_no_confirm=\"[^\"]*\"/_hotfixes_no_confirm=\"true\"/g
  " wine-tkg-profiles/sample-external-config.cfg >customization.cfg

  echo '' >wine-tkg-profiles/advanced-customization.cfg

  if [ 'lol' == "$1" ]; then
    sed -i'' "
    s/_lol920_fix=\"[^\"]*\"/_lol920_fix=\"true\"/g
    s/_PKGNAME_OVERRIDE=\"[^\"]*\"/_PKGNAME_OVERRIDE=\"leagueoflegends\"/g
    " customization.cfg

    echo '_staging_version="80498dd4"' >>customization.cfg
  fi

  return 0
}

function tkg-wine-variations() {
  set -euo pipefail

  echo 'upstream'
  echo 'upstream vkd3d-mainline'
  echo 'staging'
  echo 'staging vkd3d-mainline'
  echo 'lol' # league of legends

  return 0
}

function routine-tkg-wine() {
  set -euo pipefail
  iterfere-sync
  push-routine-dir 'tkg.wine' || return 12

  git clone 'https://github.com/Frogging-Family/wine-tkg-git.git' '_repo'

  local _VARIATIONS _VARIATION _i _DEST

  mapfile -t _VARIATIONS < <(tkg-wine-variations)

  _i=0
  for _VARIATION in "${_VARIATIONS[@]}"; do
    _i=$((_i + 1))
    _DEST="wine-tkg-git.$(printf '%04d' $_i)"

    mkdir "$_DEST"
    cp -r '_repo/wine-tkg-git'/* "$_DEST/"
    echo 'wine-tkg' >"$_DEST/PKGBASE"

    pushd "$_DEST"
    # shellcheck disable=SC2086
    tkg-wine-variate $_VARIATION
    popd
  done

  rm -rf --one-file-system '_repo' || true

  (makepwd) || true
  clean-logs
  pop-routine-dir
  return 0
}
