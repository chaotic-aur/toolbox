#!/usr/bin/env bash
function interference-apply() {
  set -euo pipefail

  local _INTERFERE _PREPEND _PKGBUILD

  _INTERFERE="${1:-}"

  interference-generic "${_PKGTAG}"

  # shellcheck source=/dev/null
  [[ -f "${_INTERFERE}/prepare" ]] \
    && source "${_INTERFERE}/prepare"

  if [[ -f "${_INTERFERE}/interfere.patch" ]]; then
    if patch -Np1 <"${_INTERFERE}/interfere.patch"; then
      echo 'Patches applied with success'
    else
      echo 'Ignoring patch failure...'
    fi
  fi

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
  set -euo pipefail -o functrace

  local _PKGTAG
  local _PKGTAG_NON_VCS

  _PKGTAG="${1:-}"

  # * CHROOT Update
  $CAUR_PUSH pacman -Syu --noconfirm

  # * Treats VCs
  if (echo "$_PKGTAG" | grep -qP '\-git$'); then
    $CAUR_PUSH pacman -S --needed --noconfirm git
    _PKGTAG_NON_VCS="${_PKGTAG%-git}"
  fi
  if (echo "$_PKGTAG" | grep -qP '\-svn$'); then
    $CAUR_PUSH pacman -S --needed --noconfirm subversion
    _PKGTAG_NON_VCS="${_PKGTAG%-svn}"
  fi
  if (echo "$_PKGTAG" | grep -qP '\-bzr$'); then
    $CAUR_PUSH pacman -S --needed --noconfirm breezy
    _PKGTAG_NON_VCS="${_PKGTAG%-bzr}"
  fi
  if (echo "$_PKGTAG" | grep -qP '\-hg$'); then
    $CAUR_PUSH pacman -S --needed --noconfirm mercurial
    _PKGTAG_NON_VCS="${_PKGTAG%-hg}"
  fi

  # * Multilib
  if (echo "$_PKGTAG" | grep -qP '^lib32-'); then
    $CAUR_PUSH pacman -S --needed --noconfirm multilib-devel
  fi

  # * Read options
  if (grep -qPo "^options=\([a-z! \"']*(?<!!)ccache[ '\"\)]" PKGBUILD); then
    $CAUR_PUSH pacman -S --needed --noconfirm ccache
  fi

  # * People who think they're smart
  if (grep -qP '^PKGEXT=' PKGBUILD); then
    sed -i'' 's/^PKGEXT=.*$//g' PKGBUILD
  fi

  # * Get rid of groups
  if (grep -qP '^groups=' PKGBUILD); then
    sed -i'' 's/^groups=.*$//g' PKGBUILD
  fi

  # * replaces=() (for VCS packages) generally causes unnecessary problems and should be avoided.
  # * https://wiki.archlinux.org/title/VCS_package_guidelines#Guidelines
  if ([ -z "${_PKGTAG_NON_VCS}" ] && grep -qP "^replaces=(${_PKGTAG_NON_VCS})$" PKGBUILD); then
    sed -i'' "/^replaces=(${_PKGTAG_NON_VCS})$/d" PKGBUILD
  fi

  # * Get rid of 'native optimizations'
  if (grep -qP '\-march=native' PKGBUILD); then
    sed -i'' 's/-march=native//g' PKGBUILD
  fi

  return 0
}

function interference-makepkg() {
  set -euo pipefail

  $CAUR_PUSH exec /usr/local/bin/internal-makepkg --skippgpcheck "$@" "${TARGET_ARGS:-}" \$\@

  return 0
}

function interference-finish() {
  set -euo pipefail

  unset TARGET_ARGS || true

  if [[ -n "${TARGET_RUN:-}" ]]; then
    echo "${TARGET_RUN}" >'CONTAINER_ARGS'
  fi

  unset TARGET_RUN || true

  return 0
}
