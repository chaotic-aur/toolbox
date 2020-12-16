#!/usr/bin/env bash

function routine() {
  set -euo pipefail

  local _CMD

  _CMD="${1:-}"

  case "${_CMD}" in
  'hourly')
    hourly
    ;;
  'morning')
    daily-morning
    ;;
  'afternoon')
    daily-afternoon
    ;;
  'nightly')
    daily-night
    ;;
  'midnight')
    daily-midnight
    ;;
  'tkg-kernels')
    routine-tkg-kernels
    ;;
  'clean-archive')
    clean-archive
    ;;
  *)
    echo 'Unrecognized routine'
    return 22
    ;;
  esac

  return 0
}

function hourly() {
  set -euo pipefail
  (iterfere-sync)
  push-routine-dir 'hourly' || return 12

  aur-download libpdfium-nojs | tee _repoctl_down.log || true
  aur-download -ru | tee -a _repoctl_down.log || true
  xargs rm -rf <"${CAUR_INTERFERE}/ignore-hourly.txt" || true

  repoctl list \
    | grep '\-\(git\|svn\|bzr\|hg\|nightly\)$' \
    | sort | comm -13 "${CAUR_INTERFERE}/ignore-hourly.txt" - \
    | xargs -L 200 repoctl down 2>&1 \
    | tee -a _repoctl_down.log \
    || true

  (makepwd) || true
  clean-logs
  pop-routine-dir
  return 0
}

function daily-morning() {
  set -euo pipefail
  (iterfere-sync)

  clean-archive

  push-routine-dir 'morning' || return 12

  repoctl down vlc-git rpcs3-git wireguard-dkms-git ffmpeg-full ffmpeg-amd-full-git \
    retdec-git ungoogled-chromium{,-git} {chromium,electron}-ozone brave \
    jellyfin-git godot-git zapcc-git visual-studio-code-insiders cling-git \
    blender-git nginx-zest-git onivim2-git \
    \
    firefox-wayland-hg waterfox-current-git firefox-kde-opensuse \
    || true

  git clone https://github.com/torvic9/plasmafox.git 'plasmafox' || true
  git clone https://github.com/torvic9/kplasmafoxhelper.git 'kplasmafoxhelper' || true
  git clone https://github.com/chaotic-aur/nvidia-tkg.git 'chaotic-nvidia-tkg' || true

  (makepwd) || true
  clean-logs
  pop-routine-dir
  return 0
}

function daily-afternoon() {
  set -euo pipefail
  (iterfere-sync)
  push-routine-dir 'afternoon' || return 12

  git clone 'https://gitlab.com/garuda-linux/packages/pkgbuilds/garuda-pkgbuilds.git' 'garuda-pkgbuilds' || true
  git clone 'https://github.com/excalibur1234/pacui.git' 'pacui-repo' || true
  git clone 'https://github.com/librewish/wishbuilds.git' 'wishbuilds' || true
  #git clone 'https://github.com/flightlessmango/PKGBUILDS.git' 'mangos' || true

  mv 'garuda-pkgbuilds/pkgbuilds'/* ./ || true
  mv 'wishbuilds/manjarowish'/* ./ || true
  #mv 'mangos'/* ./ || true

  mkdir 'pacui' 'pacui-git'
  mv 'pacui-repo/PKGBUILD' 'pacui/'
  mv 'pacui-repo/PKGBUILD-git' 'pacui-git/'

  rm -rf --one-file-system 'garuda-pkgbuilds' 'pacui-repo' 'wishbuilds' # 'mangos'

  (makepwd) || true
  clean-logs
  pop-routine-dir
  return 0
}

function daily-night() {
  set -euo pipefail

  routine-tkg

  return 0
}

function daily-midnight() {
  set -euo pipefail

  ([[ -e "$CAUR_LOWER_DIR/latest" ]] && rm "$CAUR_LOWER_DIR/latest") || true

  (iterfere-sync)
  push-routine-dir 'midnight' || return 12

  git clone 'https://github.com/SolarAquarion/PKGBUILD-CHAOTIC.git' 'schoina' || true

  mv 'schoina'/* ./ || true

  rm -rf --one-file-system 'schoina'

  (makepwd 'mesa-git' 'llvm-git') || true
  clean-logs
  pop-routine-dir
  return 0
}

function push-routine-dir() {
  set -euo pipefail

  if [ -z "${1:-}" ]; then
    echo 'Invalid routine'
    return 13
  fi

  local _DIR

  _DIR="${CAUR_ROUTINES}/$1.$(date '+%Y%m%d%H%M%S')"

  mkdir -p "$_DIR"
  pushd "$_DIR"

  if [ -z "${FREEZE_NOTIFIER:-}" ]; then
    freeze-notify &
    export FREEZE_NOTIFIER=$!
  fi

  return 0
}

function pop-routine-dir() {
  set -euo pipefail

  local _DIR

  _DIR="$(basename "$PWD")"

  cd ..

  kill-freeze-notify
  #rm -rf --one-file-system "$_DIR"

  popd

  return 0
}

function freeze-notify() {
  set -euo pipefail

  sleep 10800 # 3 hours
  (which 'telegram-send' 2>&3 >/dev/null) || return 0

  telegram-send \
    --config ~/.config/telegram-send-group.conf \
    'Hey onyii-san, wast houwwy buiwd stawted thwee houws ago (@pedrohlc)'

  return 0
}

function kill-freeze-notify() {
  set -euo pipefail

  [[ -z "${FREEZE_NOTIFIER:-}" ]] && return 0

  kill "$FREEZE_NOTIFIER" || true

  unset FREEZE_NOTIFIER

  return 0
}

function clean-archive() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  pushd "${CAUR_DEST_PKG}/../archive"

  find . -type f -mtime +7 -name '*' -execdir rm -- '{}' \; || true

  popd
  return 0
}
