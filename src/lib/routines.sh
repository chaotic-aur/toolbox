#!/usr/bin/env bash

function routine() {
  set -euo pipefail

  # good time to maybe clean the pkgcache
  (clean-pkgcache -q) || true

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

function parse-package-list() {
  set -euo pipefail

  if [[ ! -f "${1:-}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  sed -E 's/#.*//;/^\s*$/d;s/^\s+//;s/\s+$//' "$1"
}

function generic-routine() {
  set -euo pipefail

  if [[ -z "${1:-}" ]]; then
    echo 'Invalid routine'
    return 13
  fi

  local _ROUTINE _LIST _DIR _URL _PACKAGES _ROUTINE_PACKAGES _EXISTING_PACKAGES_LIST _PACKAGES_NOT_IN_REPO _PACKAGES_IN_REPO
  _ROUTINE="$1"

  clean-xdg

  (package-lists-sync)

  _LIST="${CAUR_PACKAGE_LISTS}/${CAUR_CLUSTER_NAME}/${_ROUTINE}.txt"

  if [[ ! -f "${_LIST}" ]]; then
    echo 'Unrecognized routine'
    return 22
  fi

  (interfere-sync)
  (repoctl-sync-db)

  load-config "routines/$1"

  push-routine-dir "${_ROUTINE}" || return 12

  # non-VCS packages from AUR (download if updated)
  _ROUTINE_PACKAGES="$(parse-package-list "${_LIST}" | sed -E '/:/d;/-(git|svn|bzr|hg|nightly)$/d')"
  _EXISTING_PACKAGES_LIST="$(repoctl list)"

  _PACKAGES_NOT_IN_REPO=$(comm -13 <(tr " " "\n" <<<"$_EXISTING_PACKAGES_LIST" | sort -u) <(tr " " "\n" <<<"$_ROUTINE_PACKAGES" | sort -u))
  _PACKAGES_IN_REPO=$(comm -12 <(tr " " "\n" <<<"$_EXISTING_PACKAGES_LIST" | sort -u) <(tr " " "\n" <<<"$_ROUTINE_PACKAGES" | sort -u))

  echo "$_PACKAGES_IN_REPO" \
    | xargs --no-run-if-empty -L 200 repoctl down -u 2>&1 \
    | tee -a _repoctl_down.log \
    || true

  echo "$_PACKAGES_NOT_IN_REPO" \
    | xargs --no-run-if-empty -L 200 repoctl down 2>&1 \
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
      git clone --depth 1 "${_URL}" "${_DIR}" \
        | tee -a _repoctl_down.log \
        || true
    done

  (pkgrel-incrementer-start)

  # put in background and wait, otherwise trap does not work
  _PACKAGES=()
  mapfile -t _PACKAGES < <(
    parse-package-list "${_LIST}" \
      | sed -E 's/\:(.*)//'
  )
  makepwd "${_PACKAGES[@]}" &
  sane-wait "$!" || true

  (pkgrel-incrementer-stop)

  cleanpwd
  popd #routine dir

  # good time to do some cleanup
  (clean-post-routine) || true

  return 0
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
