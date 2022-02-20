#!/usr/bin/env bash

function deploy() {
  set -euo pipefail

  local _INPUTDIR _RESULT _NON_KISS_SUDO _UPLOAD_PID _PKGTAG

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"

  _LOCK_FN="${_INPUTDIR}.lock"
  touch "${_LOCK_FN}"
  exec {_LOCK_FD}<>"${_LOCK_FN}" # Lock

  if ! flock -x -n "$_LOCK_FD"; then
    echo 'This package is already in use.'
    exec {_LOCK_FD}>&- # Unlock
    return 16
  elif [[ ! -f "${_INPUTDIR}/PKGTAG" ]]; then
    echo "\"${_INPUTDIR}\" doesn't look like a valid input directory."
    exec {_LOCK_FD}>&- # Unlock
    return 14
  fi

  _PKGTAG="$(cat "${_INPUTDIR}/PKGTAG")"
  if [[ -f "${_INPUTDIR}/PKGVAR" ]]; then
    _PKGTAG+="-$(cat "${_INPUTDIR}/PKGVAR")"
  fi

  _RESULT="${_INPUTDIR}/building.result"

  _NON_KISS_SUDO=""
  if [[ -n "${CAUR_SIGN_USER}" ]]; then
    _NON_KISS_SUDO="sudo -u ${CAUR_SIGN_USER}"
  fi

  if [[ -f "${_INPUTDIR}.log" ]]; then
    echo 'Trying to deploy log file...'
    if [[ "$CAUR_TYPE" == 'cluster' ]]; then
      rsync --verbose -e 'ssh -T -o Compression=no -x' \
        "${_INPUTDIR}.log" "$CAUR_DEPLOY_HOST:$CAUR_DEPLOY_LOGS/${_PKGTAG}.log"
    else
      cp -v "${_INPUTDIR}.log" "$CAUR_DEPLOY_LOGS/${_PKGTAG}.log" || true
    fi
  fi

  if [[ -z "${CAUR_SIGN_KEY}" ]]; then
    echo 'A signing key is required for deploying.'
    exec {_LOCK_FD}>&- # Unlock
    return 17
  elif [[ ! -e "${_RESULT}" ]] ||
    [[ "$(cat "${_RESULT}")" != 'success' ]]; then
    echo 'Invalid package, last build did not succeed, or already deployed.'
    exec {_LOCK_FD}>&- # Unlock
    return 18
  fi

  pushd "${_INPUTDIR}/dest"

  # get files back to us
  reset-fakeroot-chown .
  if [[ -n "${CAUR_SIGN_USER}" ]]; then
    chown "${CAUR_SIGN_USER}" .
  fi

  # delete files created with "fill-dest"
  unfill-dest
  if [[ -n "$(find . -type f -size 0 -print 2>&1)" ]]; then
    echo 'Failure in delete package placeholders.'
    exec {_LOCK_FD}>&- # Unlock
    return 28
  fi

  echo "Trying to deploy packages."
  _UPLOAD_PID=()
  for f in !(*.sig); do
    [[ "$f" == '!(*.sig)' ]] && continue

    if [[ ! -e "${f}.sig" ]]; then
      ${_NON_KISS_SUDO} \
        "${CAUR_GPG_PATH}" --detach-sign \
        --use-agent -u "${CAUR_SIGN_KEY}" \
        --no-armor "$f"
    fi

    if [[ "$CAUR_TYPE" == 'cluster' ]]; then
      {
        if ! rsync --verbose --partial -e 'ssh -T -o Compression=no -x' \
          "./$f" "${CAUR_DEPLOY_HOST}:${CAUR_DEPLOY_PKGS}/"; then
          echo "$f" >>../deploy.failures
        fi
      } &
      _UPLOAD_PID+=("$!")
    else
      cp -v "$f" "${CAUR_DEPLOY_PKGS}/"
    fi
  done

  [[ -n "${_UPLOAD_PID:-}" ]] && sane-wait "${_UPLOAD_PID[@]}"
  if [[ -e '../deploy.failures' ]]; then
    echo 'Some packages failed to upload.'
    exec {_LOCK_FD}>&- # Unlock
    return 29
  fi

  echo "Trying to deploy signatures."
  _UPLOAD_PID=()
  for f in *.sig; do
    [[ "$f" == '*.sig' ]] && continue

    if [[ "$CAUR_TYPE" == 'cluster' ]]; then
      {
        if ! rsync --verbose --partial -e 'ssh -T -o Compression=no -x' \
          "./$f" "${CAUR_DEPLOY_HOST}:${CAUR_DEPLOY_PKGS}/"; then
          echo "$f" >>../deploy.failures
        fi
      } &
      _UPLOAD_PID+=("$!")
    else
      cp -v "$f" "${CAUR_DEPLOY_PKGS}/"
    fi
  done

  [[ -n "${_UPLOAD_PID:-}" ]] && sane-wait "${_UPLOAD_PID[@]}"
  if [[ -e '../deploy.failures' ]]; then
    echo 'Some signatures failed to upload.'
    exec {_LOCK_FD}>&- # Unlock
    return 29
  fi

  popd # "${_INPUTDIR}/dest"

  (deploy-notify "${_PKGTAG}") || true

  echo 'deployed' >"${_RESULT}"

  exec {_LOCK_FD}>&- # Unlock
  return 0
}

function deploypwd() {
  set -euo pipefail

  local _LS

  if [ ${#@} -eq 0 ]; then
    _LS=(./*/)
  else
    _LS=("$@")
  fi

  if [[ -z "${CAUR_SIGN_KEY}" ]]; then
    echo 'A signing key is required for deploying.'
    return 17
  fi

  for _pkg in "${_LS[@]}"; do
    (deploy "$_pkg") || continue
  done

  return 0
}

function deploy-notify() {
  set -euo pipefail

  local _PKGTAG _AUTHOR

  _PKGTAG="${1:-}"
  [[ -z "$_PKGTAG" ]] && return 36

  _AUTHOR="$CAUR_DEPLOY_LABEL"
  [[ "${CAUR_IN_ROUTINE:-0}" != '1' ]] && _AUTHOR="${CAUR_MAINTAINER}@$CAUR_DEPLOY_LABEL"

  send-log --format markdown \
    "${_AUTHOR} just deployed \`${_PKGTAG}\` successfully!" ||
    true

  return 0
}
