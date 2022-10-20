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

  interference-pkgrel "${_PKGTAG}"

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
  if (grep -qP '^[ \t]*groups=' PKGBUILD); then
    sed -i'' 's/^\s*groups=.*$//g' PKGBUILD
  fi

  # * replaces=() (for VCS packages) generally causes unnecessary problems and should be avoided.
  # * https://wiki.archlinux.org/title/VCS_package_guidelines#Guidelines
  if [[ -n "${_PKGTAG_NON_VCS:-}" ]] && (grep -qP "^replaces=\(${_PKGTAG_NON_VCS}\)$" PKGBUILD); then
    sed -i'' "/^replaces=(${_PKGTAG_NON_VCS})$/d" PKGBUILD
  fi

  # * Get rid of 'native optimizations'
  if (grep -qP '\-march=native' PKGBUILD); then
    sed -i'' 's/-march=native//g' PKGBUILD
  fi

  return 0
}

function interference-pkgrel() {
  set -euo pipefail

  local _BUMPSFILE _PKGTAG _EPOCH _PKGVER _PKGREL _BUMPCOUNT

  _PKGTAG="${1:-}"
  _BUMPSFILE="${CAUR_INTERFERE}/PKGREL_BUMPS"

  if [ ! -f "${_BUMPSFILE}" ]; then
    return 0
  fi

  IFS=";" read -r _EPOCH _PKGVER _PKGREL _BUMPCOUNT <<<"$(awk -v pkgtag="${_PKGTAG}" '$1==pkgtag { epoch_index=index($2,":"); pkgrel_index=index($2,"-"); print (epoch_index==0 ? "0" : substr($2,0,epoch_index-1)) ";" substr($2,epoch_index+1,pkgrel_index-epoch_index-1) ";" substr($2,pkgrel_index+1) ";" $3; exit}' "${_BUMPSFILE}")"

  if [[ -z "${_EPOCH}" ]] || [[ -z "${_PKGVER}" ]] || [[ -z "${_PKGREL}" ]]; then
    return 0
  fi
  if [[ -z "${_BUMPCOUNT}" ]]; then
    _BUMPCOUNT=1
  fi

  echo "case \"\$(vercmp \"${_EPOCH}:${_PKGVER}\" \"\$epoch:\$pkgver\")\" in
  \"1\")
    pkgrel=1
    pkgver=\"${_PKGVER}\"
    epoch=\"${_EPOCH}\"
    ;&
  \"0\")
    if [[ \"\$pkgrel\" == \"${_PKGREL}\" ]]; then
      pkgrel=\"\$pkgrel.${_BUMPCOUNT}\"
    fi
    ;;
esac" >>PKGBUILD
}

function interference-makepkg() {
  set -euo pipefail

  $CAUR_PUSH exec /usr/local/bin/internal-makepkg --skippgpcheck "$@" "${TARGET_ARGS:-}" \$\@

  return 0
}

function interference-bump() {
  set -euo pipefail

  local _PACKAGES _PKGTAG _VERSION _BUMPSFILE _BUMPS _BUMP

  _BUMPSFILE="${CAUR_INTERFERE}/PKGREL_BUMPS"

  if [ -f "${_BUMPSFILE}" ]; then
    _BUMPS=$(<"${_BUMPSFILE}")
  else
    _BUMPS=""
  fi

  _PACKAGES="$(repoctl list -v)"

  # Clear old bumps
  while IFS= read -r _BUMP; do
    _PKGTAG=${_BUMP%% *}
    _VERSION="$(awk -v pkgtag="${_PKGTAG}" '$1==pkgtag { print $NF; exit }' <<<"${_PACKAGES}")"
    local _INTERNALVERSION _INTERNALBUMPCOUNT
    IFS=";" read -r _INTERNALVERSION _INTERNALBUMPCOUNT <<<"$(awk -v pkgtag="${_PKGTAG}" '$1==pkgtag { print $2 ";" $3; exit }' <<<"${_BUMPS}")"
    if [[ -z "${_INTERNALVERSION}" ]] || [[ -z "${_INTERNALBUMPCOUNT}" ]]; then
      continue
    fi
    if [[ "$(vercmp "${_VERSION}" "${_INTERNALVERSION}.${_INTERNALBUMPCOUNT}")" -gt 0 ]]; then
      _BUMPS="$(awk -v pkgtag="$_PKGTAG" '/^$/ {next} $1==pkgtag { next } 1' <<<"${_BUMPS}")"
    fi
  done <<<"$_BUMPS"

  # Add/increase existing bumps
  for _PKGTAG in "$@"; do
    _VERSION="$(awk -v pkgtag="${_PKGTAG}" '$1==pkgtag { print $NF; exit }' <<<"${_PACKAGES}")"
    if [ -z "${_VERSION}" ]; then
      echo "Package ${_PKGTAG} not found in repo" >&2
      return 1
    fi
    _VERSION="${_VERSION##* }"
    _BUMPS="$(awk -v pkgtag="$_PKGTAG" -v version="$_VERSION" '/^$/ {next} $1==pkgtag { if (!set) { print $1 " " $2 " " $3+1; set=1 }; next } ENDFILE { if (!set) { print pkgtag " " version " " "1" }; exit } 1' <<<"${_BUMPS}")"
  done

  echo "${_BUMPS}"
  echo "${_BUMPS}" >"${_BUMPSFILE}"

  interfere-push-bumps || interfere-sync
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
