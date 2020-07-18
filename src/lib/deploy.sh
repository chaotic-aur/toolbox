#!/usr/bin/env bash
shopt -s extglob

function deploy() {
    set -o errexit

    local _INPUTDIR="$( cd "$1"; pwd -P )"

    if [[ -z "${CAUR_SIGN_KEY}" ]]; then
        echo 'An signing key is required for deploying.'
        return 17
    elif [[ `cat "${_INPUTDIR}/building.result"` != 'success' ]]; then
        echo 'Invalid package or last build did not succeed.'
        return 18
    fi

    pushd "${_INPUTDIR}/dest"
    for f in !(*.sig); do
        gpg --detach-sign --use-agent -u "${CAUR_SIGN_KEY}" --no-armor "$f"
    done
    cp * "${CAUR_DEST_PKG}/"
    popd
}

shopt -u extglob