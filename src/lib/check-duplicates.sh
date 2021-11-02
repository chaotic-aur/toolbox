#!/bin/env sh

function check-duplicates() {
  set -euo pipefail

  REPOS="core extra community multilib chaotic-aur"

  # shellcheck disable=SC2086
  {
    # *-bin detector
    BINRX="(^$(pacman -Sql chaotic-aur | rg -r '' -- '-bin$' | sd '\n' '$|^')@)"
    BINRX="$(echo $BINRX | sd -s '|^@' '')"
    pacman -Sql $REPOS | rg -o -- "$BINRX" | awk '{print $1 "-bin"}' | huniq
    # aur -> cecm moved
    pacman -Sql $REPOS | sort | uniq -d
  }
}

