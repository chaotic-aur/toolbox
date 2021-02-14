#!/usr/bin/env bash

function deploy() {
  set -euo pipefail

  local _INPUTDIR _RESULT _NON_KISS_SUDO _FILES

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"

  _RESULT="${_INPUTDIR}/building.result"

  _NON_KISS_SUDO=""
  if [[ -n "${CAUR_SIGN_USER}" ]]; then
    _NON_KISS_SUDO="sudo -u ${CAUR_SIGN_USER}"
  fi

  if [[ -z "${CAUR_SIGN_KEY}" ]]; then
    echo 'A signing key is required for deploying.'
    return 17
  elif [[ ! -e "${_RESULT}" ]] \
    || [[ "$(cat "${_RESULT}")" != 'success' ]]; then
    echo 'Invalid package, last build did not succeed, or aready deployed.'
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
    return 28
  fi

  _FILES=()
  for f in !(*.sig); do
    [[ "$f" == '!(*.sig)' ]] && continue

    if [[ ! -e "${f}.sig" ]]; then
      ${_NON_KISS_SUDO} \
        "${CAUR_GPG_PATH}" --detach-sign \
        --use-agent -u "${CAUR_SIGN_KEY}" \
        --no-armor "$f"
    fi

    _FILES+=("$f")
  done

  if [[ ${#_FILES[@]} -gt 0 ]]; then
    tar -c "${_FILES[@]}" "${_FILES[@]/%/.sig}" | (deploy-recv)
  fi

  popd # "${_INPUTDIR}/dest"

  (deploy-notify "${_INPUTDIR}") || true

  echo 'deployed' >"${_RESULT}"

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

  local _INPUTDIR _PKGTAG _AUTHOR

  _INPUTDIR="${1:-}"

  _PKGTAG="$(cat "${_INPUTDIR}/PKGTAG")"
  [[ -z "$_PKGTAG" ]] && return 36

  _AUTHOR="$CAUR_DEPLOY_LABEL"
  [[ "${CAUR_IN_ROUTINE:-0}" != '1' ]] && _AUTHOR="${CAUR_MAINTAINER}@$CAUR_DEPLOY_LABEL"

  send-log --format markdown \
    "${_AUTHOR} just deployed \`${_PKGTAG}\` successfully!" \
    || true

  return 0
}

function deploy-recv() {
  set -euo pipefail
  local _TEMPTAR _TEMPDIR

  if [ ${#@} -lt 1 ]; then
    echo 'Invalid deploy-recv parameters'
    return 23
  fi

  _TEMPTAR="$(mktemp)"
  _TEMPDIR="$(mktemp -d)"

  cat - | tee "$_TEMPTAR"

  # Test received file
  if ! tar tf "$_TEMPTAR" &>/dev/null; then
    echo 'Corrupt tar received.'
    return 37
  fi

  pushd "$_TEMPDIR"
  # Extract files
  tar -xf "$_TEMPTAR"

  for f in ./*; do if [[ "$f" == './*' ]]; then
    echo 'Invalid (empty) directory'
    return 38
  fi; done

  repoctl add ./*
  popd # _TEMPDIR

  # Delete uploaded remains
  rm -r "$_TEMPDIR"
  rm "$_TEMPTAR"

  return 0
}
