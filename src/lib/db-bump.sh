#!/usr/bin/env bash

function db-bump() {
  set -euo pipefail

  if [[ "${CAUR_TYPE}" != 'primary' ]] && [[ "${CAUR_TYPE}" != 'dev' ]]; then
    echo 'Secondary and mirrors should not bump database'
    return 0
  fi

  # Lock bump operations
  while [[ -f "${CAUR_DB_LOCK}" ]]; do
    sleep 2
  done
  echo -n $$ >"${CAUR_DB_LOCK}"

  # Add them all
  if repoctl update && db-last-bump; then
    db-pkglist
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
  while [[ -f "${CAUR_DB_LOCK}" ]]; do
    sleep 2
  done
  echo -n $$ >"${CAUR_DB_LOCK}"

  # Remove them all
  if repoctl remove "$@"; then
    db-pkglist
  else
    db-unlock
    return 21
  fi

  db-unlock
  return 0
}
