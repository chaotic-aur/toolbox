#!/usr/bin/env bash

function mount-overlayfs() {
  set -euo pipefail

  if [[ "$CAUR_OVERLAY_TYPE" == 'fuse' ]]; then
    fuse-overlayfs "$@"
  else
    mount overlay -t overlay "$@"
  fi

  return 0
}

function optional-parallel() {
  set -euo pipefail

  local _JOBN

  _JOBN="${1:-}"

  case "$_JOBN" in
  '0' | 'host' | 'n' | 'auto')
    CAUR_PARALLEL="$(nproc)"
    ;;
  [0-9]*)
    CAUR_PARALLEL="$_JOBN"
    ;;
  *)
    echo 'Wrong number of parallel jobs.'
    return 27
    ;;
  esac

  export CAUR_PARALLEL
  return 0
}

function parallel-scp() {
  set -euo pipefail

  local f host path _files
  f="$1"
  host="$2"
  path="$3"

  if [[ ! -f "${f}.sig" ]]; then
    echo "Files without signatures? That's a crime for us!"
    return 29
  fi

  if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
    rm ".$f."*~ 2>/dev/null || true  # there may exist leftover files from a previously failed scp
    split -n"$CAUR_SCP_STREAMS" --additional-suffix='~' "$f" ".$f."
    _files=(".$f."*~ "$f.sig")
  else
    CAUR_SCP_STREAMS=1  # safety
    _files=("$f" "$f.sig")
  fi

  printf '%s\n' "${_files[@]}" |\
    xargs -d'\n' -I'{}' -P"$((CAUR_SCP_STREAMS+1))" -- \
      scp '{}' "${host}:${path}/"

  if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
    rm ".$f."*~
    # shellcheck disable=SC2029
    ssh "${host}" "cd '$path' && cat '.$f.'*~ >'$f' && rm '.$f.'*~"
  fi
}

function reset-fakeroot-chown() {
  set -euo pipefail

  # https://podman.io/blogs/2018/10/03/podman-remove-content-homedir.html
  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
      singularity --silent exec --fakeroot \
        -B "${1}:/what-is-mine" \
        "${CAUR_DOCKER_ALPINE}" \
        chown -R 0:0 /what-is-mine  # give me back
  fi
}
