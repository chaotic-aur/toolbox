#!/usr/bin/env bash
function interference-apply() {
  set -euo pipefail

  local _INTERFERE _PREPEND _PKGBUILD

  _INTERFERE="$1"

  interference-generic "${_PKGTAG}"

  # shellcheck source=/dev/null
  [[ -f "${_INTERFERE}/prepare" ]] \
    && source "${_INTERFERE}/prepare"

  if [[ -f "${_INTERFERE}/PKGBUILD.prepend" ]]; then
    # The worst one, but KISS and easier to maintain
    _PREPEND="$(cat "${_INTERFERE}/PKGBUILD.prepend")"
    _PKGBUILD="$(cat PKGBUILD)"
    echo "$_PREPEND" >PKGBUILD
    echo "$_PKGBUILD" >>PKGBUILD
  fi

  [[ -f "${_INTERFERE}/PKGBUILD.append" ]] \
    && cat "${_INTERFERE}/PKGBUILD.append" >>PKGBUILD

  return 0
}

function interference-generic() {
  set -euo pipefail

  local _PKGTAG

  _PKGTAG="$1"

  # * CHROOT Update
  $CAUR_PUSH sudo pacman -Syu --noconfirm

  # * Treats VCs
  if (echo "$_PKGTAG" | grep -qP '\-git$'); then
    $CAUR_PUSH sudo pacman -S --needed --noconfirm git
  fi
  if (echo "$_PKGTAG" | grep -qP '\-svn$'); then
    $CAUR_PUSH sudo pacman -S --needed --noconfirm subversion
  fi
  if (echo "$_PKGTAG" | grep -qP '\-bzr$'); then
    $CAUR_PUSH sudo pacman -S --needed --noconfirm breezy
  fi
  if (echo "$_PKGTAG" | grep -qP '\-hg$'); then
    $CAUR_PUSH sudo pacman -S --needed --noconfirm mercurial
  fi

  # * Read options
  if (grep -qPo "^options=\([a-z! \"']*(?<!!)ccache[ '\"\)]" PKGBUILD); then
    $CAUR_PUSH sudo pacman -S --needed --noconfirm ccache
  fi

  # * People who think they're smart
  if (grep -qP '^PKGEXT=' PKGBUILD); then
    sed -i'' 's/^PKGEXT=.*$//g' PKGBUILD
  fi

  return 0
}

function interference-makepkg() {
  set -euo pipefail

  $CAUR_PUSH exec /usr/local/bin/internal-makepkg -s --noprogressbar "$@" "${TARGET_ARGS:-}" \$\@

  return 0
}

function interference-finish() {
  set -euo pipefail

  unset TARGET_ARGS

  return 0
}
