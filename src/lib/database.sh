#!/usr/bin/env bash

function db-bump() {
  set -euo pipefail

  if [[ "$CAUR_TYPE" == 'cluster' ]]; then
    # shellcheck disable=SC2029
    ssh "$CAUR_DEPLOY_HOST" 'chaotic db-bump'

    return 0
  fi

  # Lock bump operations
  db-lock

  # Add them all
  if repoctl update && db-last-bump; then
    (db-pkglist) || true # we want to unlock even if it fails
  else
    db-unlock
    return 20
  fi

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
      {
        diff ../pkgs.files.old.txt ../pkgs.files.txt \
          | grep '^[\<\>]' \
          | telegram-send --config "$CAUR_TELEGRAM" --stdin --silent --pre
      } || true
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

  if [[ "${CAUR_TYPE}" != 'primary' ]] && [[ "${CAUR_TYPE}" != 'dev' ]]; then
    echo 'Secondary and mirrors should not manage database'
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
  return 0
}

function db-lock-notify() {
  telegram-send \
    --config "$CAUR_TELEGRAM" \
    "OwO database wock has timed-out (@pedrohlc)" \
    || true
}
