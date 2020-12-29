#!/usr/bin/env bash

function makepwd() {
  set -euo pipefail

  local _LS _pkg

  if [ ${#@} -eq 0 ]; then
    _LS=(./*/)
  else
    _LS=("$@")
  fi

  for _pkg in "${_LS[@]}"; do
    if [[ ! -d "${_pkg}" ]]; then
      echo "Skipping \"${_pkg}\", not a directory."
      continue
    elif [[ ! -f "${_pkg}/PKGBUILD" ]]; then
      echo "Skipping \"${_pkg}\", does not contains a PKGBUILD."
      continue
    fi
    (prepare "${_pkg}") || true # we want build to continue even if one pkg failed
  done

  for _pkg in "${_LS[@]}"; do
    if [[ "$_pkg" == '--' ]]; then
      echo 'Trapped, waiting jobs until here.'
      wait
    elif [[ -z "${CAUR_PARALLEL:-}" ]]; then
      pipepkg "$_pkg"
    else
      pipelimit
      pipepkg "$_pkg" &
      sleep 1
    fi
  done

  if [[ -n "${CAUR_PARALLEL:-}" ]]; then
    echo 'Waiting all jobs to finish'
    wait
  fi

  return 0
}

function pipepkg() {
  set -euo pipefail

  local _pkg

  if [ ${#@} -ne 1 ]; then
    echo 'Invalid number of parameters.'
    return 24
  fi

  _pkg="$(basename "$1")"

  if [[ -z "${_pkg}" ]] || [[ ! -f "${_pkg}/PKGTAG" ]]; then
    echo 'Invalid package name.'
    return 24
  fi

  (makepkg "${_pkg}" --noconfirm | tee "${_pkg}.log") \
    || true # we want to cleanup even if it failed
  (deploy "${_pkg}" && db-bump) || true
  (cleanup "${_pkg}") || true

  return 0
}

function limit_build() {
  set -euo pipefail

  local _MAX_JOBs

  if [[ -n "${FREEZE_NOTIFIER:-}" ]]; then
    _MAX_JOBs="$((1 + ${CAUR_PARALLEL:-1}))"
  else
    _MAX_JOBs="${CAUR_PARALLEL:-1}"
  fi

  while [[ $(jobs -rp | wc -l) -ge "${_MAX_JOBs}" ]]; do
    sleep 1
  done
}

function clean-logs() {
  set -euo pipefail

  local _TOREM

  mapfile -t _TOREM < <(grep -l -P 'ERROR: (A|The) package( group)? has already been built' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  mapfile -t _TOREM < <(grep -l 'Finished making: ' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  mapfile -t _TOREM < <(grep -l 'PKGBUILD does not exist.' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  return 0
}
