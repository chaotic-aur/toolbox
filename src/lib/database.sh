#!/usr/bin/env bash

function db-bump() {
  set -euo pipefail

  if [[ "$CAUR_TYPE" == 'cluster' ]]; then
    # shellcheck disable=SC2029
    ssh "$CAUR_DEPLOY_DEST" 'chaotic db-bump'

    return 0
  fi

  # Lock bump operations
  if [[ -f "${CAUR_DB_LOCK}" ]]; then
    echo 'Lock found, waiting for the other process to finish...'
    while [[ -f "${CAUR_DB_LOCK}" ]]; do
      sleep 2
    done
  fi
  echo -n $$ >"${CAUR_DB_LOCK}"

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

    ls *.pkg.* > ../pkgs.files.txt

    echo "Database's package list dumped"
  else
    echo 'Failed to dump package list'
  fi
  popd # CAUR_DEST_PKG

  return 0
}

function db-unlock() {
  rm "${CAUR_DB_LOCK}"

  return 0
}

function remove() {
  set -euo pipefail

  if [[ "${CAUR_TYPE}" != 'primary' ]] && [[ "${CAUR_TYPE}" != 'dev' ]]; then
    echo 'Secondary and mirrors should not manage database'
    return 0
  fi

  # Lock bump operations
  if [[ -f "${CAUR_DB_LOCK}" ]]; then
    echo 'Lock found, waiting for the other process to finish...'
    while [[ -f "${CAUR_DB_LOCK}" ]]; do
      sleep 2
    done
  fi
  echo -n $$ >"${CAUR_DB_LOCK}"

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
