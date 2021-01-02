#!/usr/bin/env bash

function routine() {
  set -euo pipefail

  if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ ! -e "${XDG_RUNTIME_DIR:-}" ]]; then
    # silence warning if $XDG_RUNTIME_DIR does not exist
    unset XDG_RUNTIME_DIR
  fi

  local _CMD

  _CMD="${1:-}"

  case "${_CMD}" in
  'tkg-kernels')
    routine-tkg-kernels
    ;;
  'clean-archive')
    clean-archive
    ;;
  *)
    generic-routine "${_CMD}"
    ;;
  esac

  return 0
}

function generic-routine() {
  set -euo pipefail

  if [[ -z "${1:-}" ]]; then
    echo 'Invalid routine'
    return 13
  fi

  local _ROUTINE
  _ROUTINE="$1"

  (package-lists-sync)

  local _LIST
  _LIST="${CAUR_PACKAGE_LISTS}/${CAUR_CLUSTER_NAME}/${_ROUTINE}.txt"

  if [[ ! -f "${_LIST}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  (iterfere-sync)
  (repoctl-sync-db)

  push-routine-dir "${_ROUTINE}" || return 12

  # non-VCS packages from AUR (download if updated)
  parse-package-list "${_LIST}" \
    | sed -E '/:/d' \
    | sed -E '/-(git|svn|bzr|hg|nightly)$/d' \
    | xargs --no-run-if-empty -L 200 repoctl down -u 2>&1 \
    | tee -a _repoctl_down.log \
    || true

  # VCS packages from AUR (always download)
  parse-package-list "${_LIST}" \
    | sed -E '/:/d' \
    | sed -En '/-(git|svn|bzr|hg|nightly)$/p' \
    | xargs --no-run-if-empty -L 200 repoctl down 2>&1 \
    | tee -a _repoctl_down.log \
    || true

  # PKGBUILDs hosted on git repos (always download)
  local _dir _url
  parse-package-list "${_LIST}" \
    | sed -En '/:/p' \
    | while IFS=':' read -r _dir _url; do
        git clone "${_url}" "${_dir}" \
          | tee -a _repoctl_down.log \
          || true
      done

  # put in background and wait, otherwise trap does not work
  makepwd &
  sane-wait "$!" || true

  clean-logs
  pop-routine-dir
  return 0
}

function parse-package-list() {
  set -euo pipefail

  if [[ ! -f "${1:-}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  sed -E 's/#.*//' "$1" | xargs -L 1 echo
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

  if [ -z "${SLURM_JOB_ID:-}" ]; then
    if [ -z "${FREEZE_NOTIFIER:-}" ]; then
      wait-freeze-and-notify "$1" &
      export FREEZE_NOTIFIER="$!"
    fi
  else
    trap "freeze-notify '$1'" SIGUSR1
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
  freeze-notify "$1"

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
  telegram-send \
    --config ~/.config/telegram-send-group.conf \
    "Hey onyii-san, wast $1 buiwd on ${CAUR_CLUSTER_NAME} stawted lwng time ago (@pedrohlc)" \
    || true
}

function clean-archive() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  pushd "${CAUR_DEST_PKG}/../archive"

  find . -type f -mtime +7 -name '*' -execdir rm -- '{}' \; || true

  popd
  return 0
}
