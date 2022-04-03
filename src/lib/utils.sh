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

function rm-as-root() {
  set -euo pipefail

  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
    $CAUR_USERNS_EXEC_CMD rm --one-file-system -rf "$1"
  else
    rm --one-file-system -rf "$1"
  fi

  return 0
}

function reset-fakeroot-chown() {
  set -euo pipefail

  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
    $CAUR_USERNS_EXEC_CMD chown -R 0:0 "$1"
  fi

  return 0
}

function clean-xdg() {
  rm -rf "/tmp/run-$(id -u)" || true
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

function sort-logs() {
  set -euo pipefail

  if [[ "$CAUR_TYPE" != 'primary' ]]; then
    echo 'Only primary node can do this action.'
    return 0
  fi

  local CAUR_LOG_CACHE="$(mktemp '/tmp/chaotic/logs-XXXXXXXXXX')"
  
  if ![[ -d "$CAUR_LOG_CACHE" ]]; then
     echo 'It was not possible to create a temporary directory for this action.'
     return 62 # Nico, find the next number, and put it here, I lost count already.
  fi

  function cleanup-logs()
  (
      for i in *; do grep "$1" "$i" && rm "$i"; done
  )

  function move-logs()
  (
      for i in *; do grep "$1" "$i" && mv "$i" "$2"; done
  )

  cp -ar "$CAUR_DEPLOY_LOGS" "$CAUR_LOG_CACHE" && cd "$CAUR_LOG_CACHE"/logs

  cleanup-logs "The package group has already been built."
  cleanup-logs "A package has already been built."
  cleanup-logs "Finished making:"

  mkdir -p "$CAUR_LOG_CACHE"/logs/{partly-built,source-changed,misc,checksums,build-failed,dep-not-in-repo,dep-runtime,space-missing}

  move-logs "Part of the package group has already been built." "partly-build"
  move-logs "is not a clone of" "source-changed"
  move-logs "One or more files did not pass the validity check!" "checksums"
  move-logs "error: target not found:" "dep-not-in-repo"
  move-logs "not found, tried pkgconfig" "dep-runtime"
  move-logs "No space left on device" "space-missing"
  move-logs "build stopped: subcommand failed." "build-failed"

  mv ./*.log misc 

  # We don't want to have already fixed logs in there
  rm -r "$CAUR_DEPLOY_LOGS_FILTERED"
  mv "$CAUR_LOG_CACHE"/logs "$CAUR_DEPLOY_LOGS_FILTERED"
}