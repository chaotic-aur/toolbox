#!/usr/bin/env bash

function load-config() {
  set -euo pipefail

  if [[ -z "${1:-}" ]]; then
    echo 'Trying to load an invalid config'
    return 37
  elif [[ -f "/etc/chaotic/${1}.conf" ]]; then
    # shellcheck source=/dev/null
    source "/etc/chaotic/${1}.conf"
  elif [[ -f "$HOME/.chaotic/${1}.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.chaotic/${1}.conf"
  else
    echo 'Skipping config file that was not found'
  fi

  return 0
}

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

function optional-nuke-only-deployed() {
  set -euo pipefail

  CAUR_CLEAN_ONLY_DEPLOYED=1
  export CAUR_CLEAN_ONLY_DEPLOYED

  return 0
}

function sane-wait() {
  # https://stackoverflow.com/a/35755784/13649511
  local status=0
  while :; do
    wait "$@" || local status="$?"
    if [[ "$status" -lt 128 ]]; then
      return "$status"
    fi
  done
}

function parallel-scp() {
  set -euo pipefail

  local f host path _files
  f="$1"
  host="$2"
  path="$3"

  pushd "$(dirname "$f")"
  f="$(basename "$f")"

  if [[ ! -f "./${f}.sig" ]]; then
    popd # "$(dirname "$f")"
    echo "Files without signatures? That's a crime for us!"
    return 29
  fi

  if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
    rm -- ./".$f."*~ 2>/dev/null || true # there may exist leftover files from a previously failed scp
    split -n"$CAUR_SCP_STREAMS" --additional-suffix='~' -- ./"$f" ./".$f."
    _files=(./".$f."*~ ./"$f.sig")
  else
    _files=(./"$f" ./"$f.sig")
  fi

  printf '%s\n' "${_files[@]}" \
    | xargs -d'\n' -I'{}' -P"$((CAUR_SCP_STREAMS + 1))" -- \
      rsync --partial -e 'ssh -T -o Compression=no -x' --protect-args -- '{}' "${host}:${path}/"

  if [[ "$CAUR_SCP_STREAMS" -gt 1 ]]; then
    rm -- ./".$f."*~
    # shellcheck disable=SC2029
    ssh "${host}" "cd '$path' && cat -- ./'.$f.'*~ >'.$f~' && mv '.$f~' '$f' && rm -- ./'.$f.'*~"
  fi

  popd # "$(dirname "$f")"

  return 0
}

function reset-fakeroot-chown() {
  set -euo pipefail

  # https://podman.io/blogs/2018/10/03/podman-remove-content-homedir.html
  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
    singularity --silent exec --fakeroot \
      -B "${1}:/what-is-mine" \
      "${CAUR_DOCKER_ALPINE}" \
      chown -R 0:0 /what-is-mine # give me back
  fi

  return 0
}

function send-group() {
  # group messages cannot be silenced

  telegram-send --config "$CAUR_TELEGRAM" "$@" &>/dev/null || true

  return 0
}

function send-log() {
  [[ "$CAUR_SILENT" == '1' ]] && return 0

  telegram-send --config "$CAUR_TELEGRAM_LOG" --silent "$@" &>/dev/null || true

  return 0
}
