#!/usr/bin/env bash

function db-bump() {
    set -o errexit

    if [[ "${CAUR_TYPE}" != 'primary' ]]; then
        echo 'Secondary and mirrors should not bump database'
        return 0
    fi

    pushd "${CAUR_ADD_QUEUE}"
    local _PKGS=(*)
    if [[ "${_PKGS[@]}" == '*' ]]; then
        echo 'No packages to add.'
        return 0;
    fi
    rm ${_PKGS[@]} || echo 'ok'
    popd # CAUR_ADD_QUEUE

    while [[ -f "${CAUR_DB_LOCK}" ]]; do
        sleep 2
    done
    echo -n $$ > "${CAUR_DB_LOCK}"

    pushd "${CAUR_DEST_PKG}"
    repoctl add \
        ${_PKGS[@]} \
        && db-last-bump && \
        db-pkglist
    popd # CAUR_DEST_PKG

    rm "${CAUR_DB_LOCK}"
    return 0
}

function db-last-bump() {
    if [ $(date -d "$_RUN_TIME" +'%s') -ge $(date -r ~/last-add +'%s') ]; then
        date +'%s' > "${CAUR_DEST_LAST}"
        echo 'Checkpoints updated'
    fi
}

function db-pkglist() {
    tar -tv --zstd -f "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}" | awk '/^d/{print $6}' > ../pkgs.txt
    echo "Database's package list dumped again"
}