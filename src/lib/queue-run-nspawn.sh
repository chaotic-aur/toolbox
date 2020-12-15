#!/usr/bin/env bash

function makepwd() {
  set -euo pipefail

  for _pkg in *; do
    if [[ ! -d "${_pkg}" ]]; then
      echo "Skipping \"${_pkg}\", not a directory."
      continue
    elif [[ ! -f "${_pkg}/PKGBUILD" ]]; then
      echo "Skipping \"${_pkg}\", does not contains a PKGBUILD."
      continue
    fi
    prepare "${_pkg}"
  done

  for _pkg in *; do
    [[ ! -f "${_pkg}/PKGTAG" ]] && continue
    makepkg "${_pkg}" --noconfirm | tee "${_pkg}.log" || continue
    if deploy "${_pkg}"; then db-bump; else continue; fi
    cleanup "${_pkg}"
  done

  return 0
}

function clean-logs() {
  set -euo pipefail

  local _TOREM

  mapfile -t _TOREM < <(grep -l -P 'ERROR: (A|The) package( group)? has already been built' ./*.log)
  [[ -n "${_TOREM[0]}" ]] && echo "${_TOREM[@]}" | xargs rm

  mapfile -t _TOREM < <(grep -l 'Finished making: ' ./*.log)
  [[ -n "${_TOREM[0]}" ]] && echo "${_TOREM[@]}" | xargs rm

  mapfile -t _TOREM < <(grep -l 'PKGBUILD does not exist.' ./*.log)
  [[ -n "${_TOREM[0]}" ]] && echo "${_TOREM[@]}" | xargs rm

  return 0
}
