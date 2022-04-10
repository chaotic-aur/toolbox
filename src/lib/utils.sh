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

function sort-logs() (
  set -euo pipefail

  if [[ "$CAUR_TYPE" != 'primary' ]]; then
    echo 'Only primary node can do this action.'
    return 0
  fi

  # We don't want to have already fixed logs in there
  if [[ -d "$CAUR_DEPLOY_LOGS_FILTERED" ]]; then
    rm -r "$CAUR_DEPLOY_LOGS_FILTERED"
  fi
  mkdir -p "${CAUR_DEPLOY_LOGS_FILTERED}"/{partly-built,source-changed,misc,checksums,build-failed,dep-not-in-repo,dep-runtime,space-missing}

  # Find all candidate files, excluding successful packages
  mapfile -t candidates < <(find "${CAUR_DEPLOY_LOGS}" -maxdepth 1 -type f -exec grep -LFe "The package group has already been built." -e "A package has already been built." -e "Finished making:" {} \;)

  function symlink-logs() {
    set -euo pipefail
    local DESTINATION
    DESTINATION="${CAUR_DEPLOY_LOGS_FILTERED}/${3}/"
    grep -qF "$2" "$1" && ln -s "$(realpath --relative-to="${DESTINATION}" "${1}")" "${DESTINATION}"
  }

  for candidate in "${candidates[@]}"; do
    symlink-logs "$candidate" "Part of the package group has already been built." "partly-build" \
      || symlink-logs "$candidate" "is not a clone of" "source-changed" \
      || symlink-logs "$candidate" "One or more files did not pass the validity check!" "checksums" \
      || symlink-logs "$candidate" "error: target not found:" "dep-not-in-repo" \
      || symlink-logs "$candidate" "not found, tried pkgconfig" "dep-runtime" \
      || symlink-logs "$candidate" "No space left on device" "space-missing" \
      || symlink-logs "$candidate" "build stopped: subcommand failed." "build-failed" \
      || symlink-logs "$candidate" "" "misc"
  done
)
