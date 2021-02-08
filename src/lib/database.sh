#!/usr/bin/env bash

function db-add() {
  set -euo pipefail

  if [ ${#@} -gt 0 ]; then
    echo 'Invalid db-add parameters'
    return 23
  fi

  if [[ "$CAUR_TYPE" == 'cluster' ]]; then
    # shellcheck disable=SC2029
    ssh "$CAUR_DEPLOY_HOST" "chaotic db-add $*"

    return 0
  fi

  # Lock bump operations
  db-lock

  # Add them all
  if repo-add "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}" "$@" && db-last-bump; then
    (db-pkglist) || true # we want to unlock even if it fails
  else
    db-unlock
    return 20
  fi

  db-unlock
  return 0
}

function db-bump() {
  set -euo pipefail

  local _RUN_TIME _NEW_SIGS _DB_FILE

  _DB_FILE="${CAUR_DB_NAME}.db.${CAUR_DB_EXT}"

  if [[ "$CAUR_TYPE" == 'cluster' ]]; then
    # shellcheck disable=SC2029
    ssh "$CAUR_DEPLOY_HOST" 'chaotic db-bump'

    return 0
  fi

  # Lock bump operations
  db-lock

  if [[ ! -f "$CAUR_CHECKPOINT" ]]; then
    touch -d "$(date -R -r "$_DB_FILE")" "$CAUR_CHECKPOINT"
  fi
  _RUN_TIME="$(date -R)"

  pushd "$CAUR_DEPLOY_PATH"
  _NEW_SIGS="$(find ./*.sig -newer "$CAUR_CHECKPOINT")" || true

  if [[ -n "${_NEW_SIGS:-}" ]]; then
    {
      echo "$_NEW_SIGS" \
        | grep -Po '.*(?:-(?:[^-]*)){3}\.pkg\.tar(?:\.xz|\.zst)?(?=\.sig)' \
        | xargs repo-add "$_DB_FILE" \
        && db-last-bump && db-pkglist && touch -d "$_RUN_TIME" "$CAUR_CHECKPOINT"
    } || true
  fi

  popd # CAUR_DEPLOY_PATH

  db-unlock
  return 0
}

function db-last-bump() {
  set -euo pipefail

  date +'%s' >"${CAUR_DEST_LAST}"
  echo 'Checkpoints updated'

  return 0
}

function db-pkglist() {
  set -euo pipefail

  pushd "${CAUR_DEST_PKG}"
  if (tar -tv --zstd \
    -f "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}" \
    | awk '/^d/{print $6}' >../pkgs.txt); then

    if [[ -e ../pkgs.files.txt ]]; then
      mv ../pkgs.files.txt ../pkgs.files.old.txt
    fi

    ls -- *.pkg.* >../pkgs.files.txt

    if [[ -e ../pkgs.files.old.txt ]]; then
      diff ../pkgs.files.old.txt ../pkgs.files.txt \
        | grep '^[\<\>]' \
        | send-log --stdin --pre
    fi

    echo "Database's package list dumped"
  else
    echo 'Failed to dump package list'
  fi
  popd # CAUR_DEST_PKG

  return 0
}

function db-lock() {
  set -euo pipefail

  touch "${CAUR_DB_LOCK}"
  exec {CAUR_LOCK_FD}<>"${CAUR_DB_LOCK}"

  echo 'Lock work: Waiting for the other process to finish...'
  if ! flock -x -w 360 "$CAUR_LOCK_FD"; then
    db-lock-notify
    return 33
  fi
  echo "Lock acquired."

  export CAUR_LOCK_FD

  return 0
}

function db-unlock() {
  exec {CAUR_LOCK_FD}>&-

  unset CAUR_LOCK_FD
  echo 'Lock released.'

  return 0
}

function remove() {
  set -euo pipefail

  if [[ "${CAUR_TYPE}" == 'cluster' ]]; then
    # shellcheck disable=SC2029
    ssh "$CAUR_DEPLOY_HOST" "chaotic -s rm $*"

    remove-notify "$@"

    return 0
  fi

  # Lock bump operations
  db-lock

  # Remove them all
  if repoctl remove "$@"; then
    (db-pkglist) || true # we want to unlock even if it fails
  else
    db-unlock
    return 21
  fi

  db-unlock

  remove-notify "$@"

  return 0
}

function db-lock-notify() {
  send-group "OwO database wock has timed-out (@pedrohlc)"
}

function remove-notify() {
  set -euo pipefail

  [[ -z "$*" ]] && return 0

  local _AUTHOR

  _AUTHOR="${CAUR_MAINTAINER}@$CAUR_DEPLOY_LABEL"

  send-log --format markdown \
    "${_AUTHOR} just removed \`$*\`" \
    || true

  return 0
}
