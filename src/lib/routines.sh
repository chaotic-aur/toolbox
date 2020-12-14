#!/usr/bin/env bash

function hourly() {
  set -euo pipefail

  iterfere-sync

  push-routine-dir 'hourly' || return 12

  aur-download libpdfium-nojs | tee _repoctl_down.log
  aur-download -ru | tee -a _repoctl_down.log
  xargs rm -rf <"${CAUR_INTERFERE}/ignore-hourly.txt"

  repoctl list \
    | grep '\-\(git\|svn\|bzr\|hg\|nightly\)$' \
    | sort | comm -13 "${CAUR_INTERFERE}/ignore-hourly.txt" - \
    | xargs -L 200 aur-download 2>&1 \
    | tee -a _repoctl_down.log

  makepwd

  pop-routine-dir

  return 0
}

function daily-morning() {
  set -euo pipefail

  # todo
  return 0
}

function daily-moon() {
  set -euo pipefail

  # todo
  return 0
}

function daily-night() {
  set -euo pipefail

  # todo
  return 0
}

function daily-midnight() {
  set -euo pipefail

  # todo
  return 0
}

function push-routine-dir() {
  set -euo pipefail

  if [ -z "$1" ]; then
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
  rm -rf --one-file-system "$_DIR"

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

  kill "$FREEZE_NOTIFIER"

  return 0
}
