#!/usr/bin/env bash

function makepwd() {
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
  done

  for _pkg in *; do
    [ ! -f "${_pkg}/PKGTAG" ] || continue
    makepkg "${_pkg}" --noconfirm | tee "${_pkg}.log" || continue
    if (deploy "${_pkg}"); then db-bump; else continue; fi
    cleanup "${_pkg}" || continue
  done

  return 0
}
