#!/usr/bin/env bash

function routine() {
  set -euo pipefail

  CAUR_CURRENT_ROUTINE="${1:-}"

  case "${CAUR_CURRENT_ROUTINE}" in
  'tkg-kernels')
    routine-tkg-kernels
    ;;
  'clean-archive')
    clean-archive
    ;;
  *)
    generic-routine
    ;;
  esac

  return 0
}

function generic-routine() {
  set -euo pipefail

  local listfile

  if [[ -z "${CAUR_CURRENT_ROUTINE}" ]]; then
    echo 'Invalid routine'
    return 13
  fi

  (package-lists-sync)

  listfile="${CAUR_PACKAGE_LISTS}/${CAUR_CLUSTER_NAME}/${CAUR_CURRENT_ROUTINE}.txt"
  if [[ ! -f "${listfile}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  (iterfere-sync)
  push-routine-dir "${CAUR_CURRENT_ROUTINE}" || return 12

  (repoctl-sync-db)

  aur-download libpdfium-nojs | tee _repoctl_down.log || true
  aur-download -ru | tee -a _repoctl_down.log || true
  xargs rm -rf <"${CAUR_INTERFERE}/ignore-hourly.txt" || true

  repoctl list \
    | grep '\-\(git\|svn\|bzr\|hg\|nightly\)$' \
    | sort | comm -13 "${CAUR_INTERFERE}/ignore-hourly.txt" - \
    | xargs -L 200 repoctl down 2>&1 \
    | tee -a _repoctl_down.log \
    || true

  # put in background and wait, otherwise trap does not work
  makepwd &
  wait "$!" || true

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

  install -o"$(whoami)" -dDm755 "$_DIR"
  pushd "$_DIR"

  if [ -z "${SLURM_JOBID:-}" ]; then
    if [ -z "${FREEZE_NOTIFIER:-}" ]; then
      wait-freeze-and-notify &
      export FREEZE_NOTIFIER="$!"
    fi
  else
    trap freeze-notify SIGUSR1 
  fi

  return 0
}

function pop-routine-dir() {
  set -euo pipefail

  local _DIR

  _DIR="$(basename "$PWD")"

  cd ..

  cancel-freeze-notify
  #rm -rf --one-file-system "$_DIR"

  popd

  return 0
}

function wait-freeze-and-notify() {
  set -euo pipefail

  sleep 10800 # 3 hours
  freeze-notify

  return 0
}

function cancel-freeze-notify() {
  set -euo pipefail

  [[ -z "${FREEZE_NOTIFIER:-}" ]] && return 0

  kill "$FREEZE_NOTIFIER" || true

  unset FREEZE_NOTIFIER

  return 0
}

function freeze-notify() {
  (which 'telegram-send' 2>&3 >/dev/null) || return 0

  telegram-send \
    --config ~/.config/telegram-send-group.conf \
    "Hey onyii-san, wast ${CAUR_CURRENT_ROUTINE} buiwd on ${CAUR_CLUSTER_NAME} stawted lwng time ago (@pedrohlc)"

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
