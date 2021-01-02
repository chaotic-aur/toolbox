#!/usr/bin/env bash

function iterfere-sync() {
  set -euo pipefail

  pushd "${CAUR_INTERFERE}"
  git pull --ff-only || true
  popd #CAUR_INTERFERE

  return 0
}

function package-lists-sync() {
  set -euo pipefail

  pushd "${CAUR_PACKAGE_LISTS}"
  git pull --ff-only || true
  popd #CAUR_PACKAGE_LISTS

  return 0
}

function repoctl-sync-db() {
  set -euo pipefail

  [[ -z "${CAUR_REPOCTL_DB_URL:-}" ]] && return 0
  [[ -z "${CAUR_REPOCTL_DB_FILE:-}" ]] && return 0

  local repoctl_config

  install -o"$(whoami)" -dDm755 "${HOME}/.config/repoctl"
  repoctl_config="${HOME}/.config/repoctl/config.toml"

  if [[ -e "${repoctl_config}" ]]; then
    if [[ "$(wc -l <"$repoctl_config")" -gt 2 ]]; then
      echo "sanity check: we are not going to overwrite existing repoctl config"
      return 31
    fi
  fi

  install -o"$(whoami)" -dDm755 "$(dirname "$CAUR_REPOCTL_DB_FILE")"
  curl -s -o "${CAUR_REPOCTL_DB_FILE}" "${CAUR_REPOCTL_DB_URL}"

  stee "${repoctl_config}" <<EOF
[profiles.default]
repo = "${CAUR_REPOCTL_DB_FILE}"
EOF
}

