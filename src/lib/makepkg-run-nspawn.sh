#!/usr/bin/env bash

function makepkg-run-nspawn() {
    #set -euo pipefail # This one we may prefer that go till the end

    local _INPUTDIR="$( cd "$1"; pwd -P )"
    local _PARAMS="${@:2}"

    if [[ ! -f "${_INPUTDIR}/type" ]]; then
        echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
        return 14
    elif [[ `cat ${_INPUTDIR}/type` != 'bash' ]]; then
        echo "\"${_INPUTDIR}\" is not valid for systemd-nspawn."
        return 15
    elif [[ -f "${_INPUTDIR}/building.pid" ]]; then
        echo 'This package is already building.'
        return 16
    fi

    echo -n $$ > "${_INPUTDIR}/building.pid"

    if [[ ! -e "${CAUR_LOWER_DIR}/latest" ]]; then
        lower-prepare
    fi

    pushd "${_INPUTDIR}"
    [[ -e 'building.result' ]] && rm 'building.result'
    local _PKGTAG=`cat tag`
    local _GENESIS="${CAUR_PACKAGES}/entries/${_PKGTAG}"
    local _LOWER="$( cd "${CAUR_LOWER_DIR}" ; cd $(readlink latest) ; pwd -P )"

    local _HOME="machine/root/home/${CAUR_GUEST_USER}"
    local _CCACHE="${CAUR_CACHE_CC}/${_PKGTAG}"
    local _SRCCACHE="${CAUR_CACHE_SRC}/${_PKGTAG}"
    local _PKGDEST="${_HOME}/pkgdest"

    mkdir -p machine/{up,work,root,destwork} dest "${_CCACHE}" "${_SRCCACHE}" "${CAUR_CACHE_PKG}" "${CAUR_DEST_PKG}" 
    mount overlay -t overlay -olowerdir=${_LOWER},upperdir=machine/up,workdir=machine/work machine/root
    
    mount --bind 'pkgwork' "${_HOME}/pkgwork" 
    mount --bind "${_CCACHE}" "${_HOME}/.ccache" 
    mount --bind "${_SRCCACHE}" "${_HOME}/pkgsrc"
    mount --bind "${CAUR_CACHE_PKG}" 'machine/root/var/cache/pacman/pkg'
    mount --bind 'dest' "${_PKGDEST}"
    #mount overlay -t overlay -olowerdir=${CAUR_DEST_PKG},upperdir=./dest,workdir=./machine/destwork "${_PKGDEST}"

    local _CAUR_WIZARD="machine/root/home/${CAUR_GUEST_USER}/wizard.sh"
    cp "${CAUR_BASH_WIZARD}" "${_CAUR_WIZARD}"
    chown -R ${CAUR_GUEST_UID}:${CAUR_GUEST_GID} "${_CAUR_WIZARD}" pkgwork "${_PKGDEST}" "$_CCACHE" "$_SRCCACHE"
    chmod 755 "${_CAUR_WIZARD}"

    local _MECHA_NAME="pkg$(echo -n "$_PKGTAG" | sha256sum | cut -c1-11)"
    local _BUILD_FAILED=''
    systemd-nspawn -M ${_MECHA_NAME} \
        -u "${CAUR_GUEST_USER}" \
        --capability=CAP_IPC_LOCK,CAP_SYS_NICE \
        -D machine/root \
        "/home/${CAUR_GUEST_USER}/wizard.sh" ${_PARAMS} || local _BUILD_FAILED="$?"

    if [[ -z "${_BUILD_FAILED}" ]]; then
        echo 'success' >  'building.result'
    elif  [[ -f "${_GENESIS}/on-failure.sh" ]]; then
        echo "${_BUILD_FAILED}" >  'building.result'
        source "${_GENESIS}/on-failure.sh"
    fi

    umount -Rv machine/root && \
       rm --one-file-system -rf machine

    rm 'building.pid'
    popd # "${_INPUTDIR}"
    [[ -n "${_BUILD_FAILED}" ]] \
        && return ${_BUILD_FAILED}
    return 0
}