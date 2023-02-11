#!/usr/bin/env bash

function makepwd() {
  set -euo pipefail

  local _LS _pkg _BUILDING_PIDS _MAX_JOBS

  _MAX_JOBS="${CAUR_PARALLEL:-1}"
  if [[ ${_MAX_JOBS} -lt 1 ]]; then
    _MAX_JOBS="$(nproc)"
  fi

  echo 'Trying to make directory...'

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
      echo "Skipping \"${_pkg}\", does not contain a PKGBUILD."
      continue
    fi
    (prepare "${_pkg}") || true # we want build to continue even if one pkg failed
  done

  _BUILDING_PIDS=()
  for _pkg in "${_LS[@]}"; do
    if [[ "$_pkg" == '--' ]]; then
      echo 'Trapped, waiting jobs until here.'
      if [[ -n "${_BUILDING_PIDS[*]}" ]]; then
        sane-wait "${_BUILDING_PIDS[@]}" || true
      fi
      _BUILDING_PIDS=()
      echo 'Keep going...'
    elif [[ "${_MAX_JOBS}" == '1' ]]; then
      pipepkg "$_pkg" || true
    else
      while [[ -n "${_BUILDING_PIDS:-}" ]] \
        && [[ $(comm -12 <(printf "%s\n" "${_BUILDING_PIDS[@]}" | sort) <(jobs -rp | sort) | wc -l) -gt ${_MAX_JOBS} ]]; do
        sleep 1
      done
      pipepkg "$_pkg" &
      _BUILDING_PIDS+=("$!")
      sleep 1
    fi
  done

  echo 'Waiting all jobs to finish'
  sane-wait

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

  echo "Starting making ${_pkg}"
  ({ time makepkg "${_pkg}" --noconfirm; } 2>&1 | tee "${_pkg}.log") \
    || if grep -qP "is not a clone of" "${_pkg}.log"; then
      clean-srccache "${_pkg}" # To fight failed builds due to changed git source
      ({ time makepkg "${_pkg}" --noconfirm; } 2>&1 | tee "${_pkg}.log") \
        || true
    elif grep -qP "One or more files did not pass the validity check!" "${_pkg}.log"; then
      clean-srccache "${_pkg}" # To fight failed builds due to wrong cached files
      ({ time makepkg "${_pkg}" --noconfirm; } 2>&1 | tee "${_pkg}.log") \
        || true
    fi \
    || true # we want to cleanup even if it failed

  (deploy "${_pkg}" && db-bump 2>&1 | tee -a "${_pkg}.log") || true
  (cleanup "${_pkg}" 2>&1 | tee -a "${_pkg}.log") || true

  return 0
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

function cleanpwd() {
  set -euo pipefail

  for f in ./*/; do
    [[ "$f" == './*/' ]] && continue
    cleanup "$f" || true
  done

  clean-logs

  rm ./*.lock || true

  return 0
}
