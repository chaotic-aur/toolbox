#!/usr/bin/env bash

function queue-run-nspawn() {
    set -o errexit

    if [[ -d "${CAUR_PACKAGES}/queues/$1" ]]; then
        local _INPUTDIR="${CAUR_QUEUES}/${1}.$(date '+%Y%m%d%H%M%S')"

        pushd "${CAUR_PACKAGES}/queues/$1"
        if [[ ./* == './*' ]]; then]
            echo 'Empty queue, ignoring...'
            return 0
        fi

        mkdir -p "$_INPUTDIR"
        for f in *; do
            makepkg-gen-bash "$f" "${_INPUTDIR}" || continue
        done

        popd

    elif [[ -d "$1" ]]; then
        local _INPUTDIR="$( cd "$1"; pwd -P )"
    else
        echo 'Invalid parameters'
        return 19
    fi

    pushd "${_INPUTDIR}"

    for _pkg in *; do
       makepkg-run-nspawn "${_pkg}" | tee "${_pkg}.log" || continue
       deploy "${_pkg}" && db-bump || continue
       cleanup "${_pkg}" || continue
    done

    popd # _INPUT_DIR
    return 0
}
