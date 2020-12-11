#!/usr/bin/env bash

function queue-run-nspawn() {
    set -euo pipefail

    for _pkg in *; do
        if [ ! -d "${_pkg}" ]; then
            echo "Skipping \"${_pkg}\", not a directory."
            continue
        elif [ ! -f "${_pkg}/PKGBUILD" ]; then
            echo "Skipping \"${_pkg}\", does not contains a PKGBUILD."
            continue
        fi
        prepare "${_pkg}" 
    fi

    for _pkg in *; do
        [ ! -f "${_pkg}/PKGTAG" ] || continue
        makepkg "${_pkg}" --noconfirm | tee "${_pkg}.log" || continue
        deploy "${_pkg}" && db-bump || continue
        cleanup "${_pkg}" || continue
    done

    return 0
}
