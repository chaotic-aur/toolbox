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
    echo -n $$ > "${CAUR_DB_LOCK}"

    # Add them all
    if sudo -u "${CAUR_DB_USER}" repoctl update && db-last-bump; then
        db-pkglist
    else
        db-unlock
        return 3
    fi

    db-unlock
    return 0
}

function db-last-bump() {
    set -euo pipefail

    date +'%s' > "${CAUR_DEST_LAST}"
    echo 'Checkpoints updated'

    return 0
}

function db-pkglist() {
    set -euo pipefail

    pushd "${CAUR_DEST_PKG}"
    tar -tv --zstd -f "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}" |\
        awk '/^d/{print $6}' > ../pkgs.txt &&\
        echo "Database's package list dumped" ||\
        echo 'Failed to dump package list'
    popd # CAUR_DEST_PKG

    return 0
}

function db-unlock() {
    # doesn't matter if it fails
    rm "${CAUR_DB_LOCK}"

    return 0
}