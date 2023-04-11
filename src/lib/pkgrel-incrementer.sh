#!/usr/bin/env bash

function pkgrel-incrementer-start() {
  set -euo pipefail

  if [[ "${CAUR_ENGINE}" = 'singularity' ]]; then
    singularity run -B "$HOME/chaotic/pkgrel_incrementer/data":/data "$HOME/chaotic/pkgrel_incrementer/pkgrel_incrementer.sif" &
    PKGREL_INCREMENTER_PID="$!"
  fi
}

function pkgrel-incrementer-stop() {
  set -euo pipefail

  if [[ -n "${PKGREL_INCREMENTER_PID:-}" ]]; then
    kill "${PKGREL_INCREMENTER_PID}"
  fi
}
