#!/usr/bin/env bash

function interfere-sync() {
  set -euo pipefail

  echo 'Syncing interfere...'
  pushd "${CAUR_INTERFERE}"
  git fetch || true
  git reset --hard '@{u}' || true
  popd #CAUR_INTERFERE

  return 0
}

function interfere-push-bumps() {
  set -euo pipefail

  echo 'Push interfere...'
  pushd "${CAUR_INTERFERE}"
  GIT_AUTHOR_NAME="${CAUR_MAINTAINER}@$CAUR_DEPLOY_LABEL" git commit -m 'Update PKGREL_BUMPS' PKGREL_BUMPS \
    && git push || return 1
  popd #CAUR_INTERFERE

  return 0
}

function package-lists-sync() {
  set -euo pipefail

  echo 'Syncing packages...'
  pushd "${CAUR_PACKAGE_LISTS}"
  git pull --ff-only || true
  popd #CAUR_PACKAGE_LISTS

  return 0
}

function repoctl-sync-db() {
  set -euo pipefail

  [[ -z "${CAUR_REPOCTL_DB_URL:-}" ]] && return 0
  [[ -z "${CAUR_REPOCTL_DB_FILE:-}" ]] && return 0

  echo 'Syncing database...'

  install -o"$(whoami)" -dDm755 "${HOME}/.config/repoctl"
  [[ -z "${REPOCTL_CONFIG:-}" ]] && REPOCTL_CONFIG="${HOME}/.config/repoctl/config.toml"

  if [[ -e "${REPOCTL_CONFIG}" ]]; then
    if [[ "$(wc -l <"$REPOCTL_CONFIG")" -gt 2 ]]; then
      echo "sanity check: we are not going to overwrite existing repoctl config"
      return 31
    fi
  fi

  install -o"$(whoami)" -dDm755 "$(dirname "$CAUR_REPOCTL_DB_FILE")"
  curl -sLo "${CAUR_REPOCTL_DB_FILE}" "${CAUR_REPOCTL_DB_URL}"

  stee "${REPOCTL_CONFIG}" <<EOF
[profiles.default]
repo = "${CAUR_REPOCTL_DB_FILE}"
EOF

  export REPOCTL_CONFIG
}
