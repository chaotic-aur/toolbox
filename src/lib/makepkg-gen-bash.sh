#!/usr/bin/env bash

function makepkg-gen-bash() {
    set -o errexit

    local _PKGTAG="$1"
    local _DEST_PARENT="$2"
    local _PARAMS="${@:3}"
    local _GENESIS="${CAUR_PACKAGES}/entries/${_PKGTAG}"

    if [[ -z "${_PKGTAG}" ]]; then
        echo "Invalid parameters package tag."
        return 11
    elif [[ -z "${_DEST_PARENT}" ]]; then
        echo "Invalid destination directory."
        return 12
    elif [[ ! -d "${_GENESIS}/source" ]]; then
        echo "\"${_PKGTAG}\" is not a valid package."
        return 10
    fi

    if [[ -f "${_GENESIS}/variations.sh" ]]; then
        local _i=0
        "${_GENESIS}"/variations.sh | while read _VARIATION; do
            local _DEST="${_DEST_PARENT}/${_PKGTAG}.${_i}"
            local _i=$((_i+1))

            [[ -d "${_DEST}" ]] && continue # Don't prepare a new one if there is another pending
            
            mkdir -p "${_DEST}/source"
            echo -n "${_PKGTAG}" > "${_DEST}/tag"
            echo -n "${_VARIATION}" > "${_DEST}/variation"
            makepkg-gen-bash-init "${_DEST}"

            pushd "$_GENESIS/source"
            cp -r * "${_DEST}/source" # We don't need hidden files
            popd

            pushd "${_DEST}/source"
            "${_GENESIS}"/variate.sh ${_VARIATION}
            popd


            pushd "${_DEST}"
            if [[ -n "${CAUR_SUBPKGDIR}" ]]; then
                mv "source/${CAUR_SUBPKGDIR}" 'pkgwork'
                unset CAUR_SUBPKGDIR
            else
                mv 'source' 'pkgwork'
            fi
            popd

            pushd "${_DEST}/pkgwork"
            interference-apply "${_PKGTAG}"
            popd

            interference-makepkg ${_PARAMS}
            makepkg-gen-bash-finish "${_DEST}"
        done
    else
        local _DEST="${_DEST_PARENT}/${_PKGTAG}"

        [[ -d "${_DEST}" ]] && return # Don't prepare a new one if there is another pending
            
        mkdir -p "${_DEST}/pkgwork"
        echo -n "${_PKGTAG}" > "${_DEST}/tag"
        makepkg-gen-bash-init "${_DEST}"

        pushd "$_GENESIS/source"
        cp -r * "${_DEST}/pkgwork" # We don't need hidden files
        popd

        pushd "${_DEST}/pkgwork"
        interference-apply "${_PKGTAG}"
        popd

        interference-makepkg ${_PARAMS}
        makepkg-gen-bash-finish "${_DEST}"
    fi

    return 0
}

function makepkg-gen-bash-init() {
    set -o errexit

    local _DEST="$1"

    export CAUR_WIZARD="${_DEST}/${CAUR_BASH_WIZARD}"
    echo '#!/usr/bin/env bash' | tee "${CAUR_WIZARD}" > /dev/null
    export CAUR_PUSH="makepkg-gen-bash-append"

    return 0
}

function makepkg-gen-bash-append() {
    set -o errexit

    echo "${@}" | tee -a "${CAUR_WIZARD}" > /dev/null

    return 0
}

function makepkg-gen-bash-finish() {
    set -o errexit

    local _DEST="$1"

    unset CAUR_PUSH
    unset CAUR_WIZARD
    echo -n 'bash' > "${_DEST}/type"

    return 0
}
