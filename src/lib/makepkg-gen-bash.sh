#!/usr/bin/env bash

function prepare() {
    set -euo pipefail

    local _PKGDIR="$( cd "$1"; pwd -P )"
    local _PARAMS="${@:2}"

    if [[ -e "${_PKGDIR}/PKGTAG" ]]; then
        echo "Package already was prepared."
        return 0
    if [[ -e "${_PKGDIR}/PKGBUILD" ]]; then
        echo "Invalid parameter, \"${_PKGDIR}\" does not contains a PKGBUILD."
        return 10
    fi

    pushd "${_PKGDIR}"
    local _PKGTAG="$(basename $PWD)"
    local _INTERFERE="${CAUR_INTERFERE}/${_PKGTAG}"

    mkdir 'genesis'
    mv *!(genesis) 'genesis/'

    if [[ -f "${_INTERFERE}/variations.sh" ]]; then
        local _i=0
        "${_INTERFERE}"/variations.sh | while read _VARIATION; do
            local _DEST="${_PKGTAG}.$(printf '%04d' $_i)"
            local _i=$((_i+1))

            mkdir -p "${_DEST}/pkgwork"
            echo -n "${_PKGTAG}" > "${_DEST}/PKGTAG"
            echo -n "${_VARIATION}" > "${_DEST}/PKGVAR"
            makepkg-gen-bash-init "${_DEST}"

            cp -r genesis "${_DEST}/pkgwork"
            
            pushd "${_DEST}/pkgwork"
            "${_INTERFERE}"/variate.sh ${_VARIATION}
            interference-apply "${_INTERFERE}"
            popd

            interference-makepkg ${_PARAMS}
            makepkg-gen-bash-finish
        done

        rm -rf --one-file-system 'genesis'
    else
        echo -n "${_PKGTAG}" > 'PKGTAG'
        makepkg-gen-bash-init "${_PKGDIR}"

        mv 'genesis' 'pkgwork'

        pushd 'pkgwork'
        interference-apply "${_INTERFERE}"
        popd

        interference-makepkg ${_PARAMS}
        makepkg-gen-bash-finish
    fi

    return 0
}

function makepkg-gen-bash-init() {
    set -euo pipefail

    local _DEST="$1"

    export CAUR_WIZARD="${_DEST}/${CAUR_BASH_WIZARD}"
    echo '#!/usr/bin/env bash' | tee "${CAUR_WIZARD}" > /dev/null
    export CAUR_PUSH="makepkg-gen-bash-append"

    return 0
}

function makepkg-gen-bash-append() {
    set -euo pipefail

    echo "${@}" | tee -a "${CAUR_WIZARD}" > /dev/null

    return 0
}

function makepkg-gen-bash-finish() {
    set -euo pipefail

    unset CAUR_PUSH
    unset CAUR_WIZARD

    return 0
}
