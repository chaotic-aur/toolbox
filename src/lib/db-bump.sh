#!/usr/bin/env bash

function db-bump() {
    set -o errexit

    if [[ "${CAUR_TYPE}" != 'primary' ]]; then
        echo 'Secondary and mirrors should not bump database'
        return 0
    fi

    while [[ -f "${CAUR_DB_LOCK}" ]]; do
        sleep 2
    done
    echo -n $$ > "${CAUR_DB_LOCK}"

    pushd "${CAUR_DEST_PKG}"

    if [[ ! -f "${CAUR_DB_LAST}" ]]; then
        touch -d "$(date -R -r "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}")" "${CAUR_DB_LAST}"
    fi
    export _RUN_TIME="$(date -R)"

    local _NEW_SIGS="$(find *.sig -newer "${CAUR_DB_LAST}")"
    if [[ -z "${_NEW_SIGS}" ]]; then
        local _PKGS=$(echo "$_NEW_SIGS" |\
            grep -Po '(.*)(?=(?:-(?:[^-]*)){3}\.pkg\.tar(?:\.xz|\.zst)?\.sig)')
    
        echo 'Adding new packages'
        echo "$_PKGS" |\
            xargs repoctl update \
            \
            && db-last-bump && \
            db-pkglist 
    fi

    popd # CAUR_DEST_PKG

    rm "${CAUR_DB_LOCK}"
    return 0
}

function db-last-bump() {
    if [ $(date -d "$_RUN_TIME" +'%s') -ge $(date -r ~/last-add +'%s') ]; then
        touch -d "$_RUN_TIME" "${CAUR_DB_LAST}"
        date +'%s' > "${CAUR_DEST_LAST}"
        echo 'Checkpoints updated'
    fi
}

function db-pkglist() {
    tar -tv --zstd -f "${CAUR_DB_NAME}.db.${CAUR_DB_EXT}" | awk '/^d/{print $6}' > ../pkgs.txt
    echo "Database's package list dumped again"
}