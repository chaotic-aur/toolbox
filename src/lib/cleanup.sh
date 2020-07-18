#!/usr/bin/env bash

function cleanup() {
    set -o errexit

    local _INPUTDIR="$( cd "$1"; pwd -P )"
    
    pushd "${_INPUTDIR}"
    
    if [[ -e 'building.pid' ]]; then
        echo "Package is still building in PID: $(cat building.pid)."
        return 18
    elif [[ ! -e 'tag' ]]; then
        echo 'Invalid package directory.'
        return 19
    fi

    if [[ -d 'machine/root' ]]; then
        umount -Rv 'machine/root'
    fi

    popd # _INPUTDIR

    rm --one-file-system -rf "${_INPUTDIR}"
    return 0 
}
