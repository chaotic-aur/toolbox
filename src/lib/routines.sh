#!/usr/bin/env bash

function routine() {
  set -euo pipefail

  if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ ! -e "${XDG_RUNTIME_DIR:-}" ]]; then
    # silence warning if $XDG_RUNTIME_DIR does not exist
    unset XDG_RUNTIME_DIR
  fi

  local _CMD

  _CMD="${1:-}"

  CAUR_IN_ROUTINE=1
  export CAUR_IN_ROUTINE

  case "${_CMD}" in
  'tkg-kernels')
    load-config 'routines/tkg-kernels'
    routine-tkg-kernels
    ;;
  'tkg-wine')
    load-config 'routines/tkg-wine'
    routine-tkg-wine
    ;;
  'clean-archive')
    clean-archive
    ;;
  *)
    generic-routine "${_CMD}"
    ;;
  esac

  echo 'Finished routine.'

  return 0
}

function generic-routine() {
  set -euo pipefail

  if [[ -z "${1:-}" ]]; then
    echo 'Invalid routine'
    return 13
  fi

  local _ROUTINE _LIST _DIR _URL _PACKAGES
  _ROUTINE="$1"

  (package-lists-sync)

  _LIST="${CAUR_PACKAGE_LISTS}/${CAUR_CLUSTER_NAME}/${_ROUTINE}.txt"

  if [[ ! -f "${_LIST}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  (iterfere-sync)
  (repoctl-sync-db)

  load-config "routines/$1"

  push-routine-dir "${_ROUTINE}" || return 12

  # non-VCS packages from AUR (download if updated)
  parse-package-list "${_LIST}" \
    | sed -E '/:/d;/-(git|svn|bzr|hg|nightly)$/d' \
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
  parse-package-list "${_LIST}" \
    | sed -En '/:/p' \
    | while IFS=':' read -r _DIR _URL; do
      git clone "${_URL}" "${_DIR}" \
        | tee -a _repoctl_down.log \
        || true
    done

  # put in background and wait, otherwise trap does not work
  _PACKAGES=()
  mapfile -t _PACKAGES < <(
    parse-package-list "${_LIST}" \
      | sed -E 's/\:(.*)//'
  )
  makepwd "${_PACKAGES[@]}" &
  sane-wait "$!" || true

  cleanpwd
  popd #routine dir

  # good time to maybe clean the archive
  (clean-archive) || true

  return 0
}

function parse-package-list() {
  set -euo pipefail

  if [[ ! -f "${1:-}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  sed -E 's/#.*//;/^\s*$/d;s/^\s+//;s/\s+$//' "$1"
}

function push-routine-dir() {
  set -euo pipefail

  if [ -z "${1:-}" ]; then
    echo 'Invalid routine'
    return 13
  fi

  local _DIR

  if [[ "${CAUR_STAMPROUTINES:-1}" == '1' ]]; then
    _DIR="${CAUR_ROUTINES}/$1.$(date '+%Y%m%d%H%M%S')"
  else
    _DIR="${CAUR_ROUTINES}/$1"
  fi

  if [[ -d "$_DIR" ]]; then
    pushd "$_DIR"
    echo 'Cleaning pre-existent routine directory.'
    cleanpwd
  else
    echo 'Creating new routine directory.'
    install -o"$(whoami)" -dDm755 "$_DIR"
    pushd "$_DIR"
  fi

  # shellcheck disable=SC2064
  trap "freeze-notify '$1' '${SLURM_NODELIST:-}'" SIGUSR1

  return 0
}

function freeze-notify() {
  local _PREPARED_REMAINING _TOUCHED_REMAINING
  _PREPARED_REMAINING="$(find . -mindepth 2 -maxdepth 2 -name PKGTAG | wc -l)"
  [[ ${_PREPARED_REMAINING} -lt 1 ]] && return 0
  _TOUCHED_REMAINING="$(find . -mindepth 2 -maxdepth 2 -name building.result | wc -l)"
  send-log "Hey onyii-san, wast ${1:-} buiwd on ${CAUR_CLUSTER_NAME}'s ${2:-} stawted lwng time ago (${CAUR_TELEGRAM_TAG}), with ${_PREPARED_REMAINING} packages remaining to build (${_TOUCHED_REMAINING} failed/building)."
}

function clean-archive() {
  set -euo pipefail

  [[ "$CAUR_TYPE" != 'primary' ]] && return 0

  pushd "${CAUR_DEPLOY_PKGS}/../archive"

  find . -type f -mtime +7 -name '*' -execdir rm -- '{}' \; || true

  popd
  return 0
}
