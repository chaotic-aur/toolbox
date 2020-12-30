#!/usr/bin/env bash

function deploy() {
  set -euo pipefail

  local _INPUTDIR _RESULT _NON_KISS_SUDO

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

  for f in !(*.sig); do
    [[ "$f" == '!(*.sig)' ]] && continue

    if [[ ! -e "${f}.sig" ]]; then
      ${_NON_KISS_SUDO} \
        "${CAUR_GPG_PATH}" --detach-sign \
        --use-agent -u "${CAUR_SIGN_KEY}" \
        --no-armor "$f"
    fi

    if [[ "$CAUR_TYPE" == 'cluster' ]]; then
      local _files

      if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
        rm ".$f."*~ 2>/dev/null || true  # there may exist leftover files from a previously failed deploy
        split -n"$CAUR_SCP_STREAMS" --additional-suffix='~' "$f" ".$f."
        _files=(".$f."*~ "$f.sig")
      else
        CAUR_SCP_STREAMS=1  # safety
        _files=("$f" "$f.sig")
      fi

      printf '%s\n' "${_files[@]}" |\
        xargs -d'\n' -I'{}' -P"$((CAUR_SCP_STREAMS+1))" -- \
          scp '{}' "${CAUR_DEPLOY_HOST}:${CAUR_DEPLOY_PATH}/"

      if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
        rm ".$f."*~
        # shellcheck disable=SC2029
        ssh "$CAUR_DEPLOY_HOST" "cd '$CAUR_DEPLOY_PATH' && cat '.$f.'*~ >'$f' && rm '.$f.'*~"
      fi
    else
      cp -v "$f"{,.sig} "${CAUR_DEST_PKG}/"
    fi
  done

  popd # "${_INPUTDIR}/dest"

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
