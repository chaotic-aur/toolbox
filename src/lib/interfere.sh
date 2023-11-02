#!/usr/bin/env bash
function interference-apply() {
  set -euo pipefail

  local _INTERFERE _PREPEND _PKGBUILD

  _INTERFERE="${1:-}"

  interference-generic "${_PKGTAG}"

  [[ -d "${_INTERFERE}" ]] && echo 'optdepends+=("chaotic-interfere")' >>PKGBUILD

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
    echo "${_PREPEND}" >PKGBUILD
    echo "${_PKGBUILD}" >>PKGBUILD
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

  # * Treats VCs
  if (echo "${_PKGTAG}" | grep -qP '\-git$'); then
    extra_pkgs+=("git")
    _PKGTAG_NON_VCS="${_PKGTAG%-git}"
  fi
  if (echo "${_PKGTAG}" | grep -qP '\-svn$'); then
    extra_pkgs+=("subversion")
    _PKGTAG_NON_VCS="${_PKGTAG%-svn}"
  fi
  if (echo "${_PKGTAG}" | grep -qP '\-bzr$'); then
    extra_pkgs+=("breezy")
    _PKGTAG_NON_VCS="${_PKGTAG%-bzr}"
  fi
  if (echo "${_PKGTAG}" | grep -qP '\-hg$'); then
    extra_pkgs+=("mercurial")
    _PKGTAG_NON_VCS="${_PKGTAG%-hg}"
  fi

  # * Multilib
  if (echo "${_PKGTAG}" | grep -qP '^lib32-'); then
    extra_pkgs+=("multilib-devel")
  fi

  # * Special cookie for TKG kernels
  if (echo "${_PKGTAG}" | grep -qP '^linux.*tkg'); then
    extra_pkgs+=("git")
  fi

  # * Read options
  if (grep -qPo "^options=\([a-z! \"']*(?<!!)ccache[ '\"\)]" PKGBUILD); then
    extra_pkgs+=("ccache")
  fi

  # * CHROOT Update
  ${CAUR_PUSH} pacman -Syu --noconfirm "${extra_pkgs[@]}"

  # * Add missing newlines at end of file
  # * Get rid of troublesome options
  {
    echo -e '\n\n\n'
    echo "PKGEXT='.pkg.tar.zst'"
    echo 'unset groups'
    echo 'unset replaces'
  } >>PKGBUILD

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

  if [[ ! -f "${_BUMPSFILE}" ]]; then
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

  ${CAUR_PUSH} exec /usr/local/bin/internal-makepkg --skippgpcheck "$@" "${TARGET_ARGS:-}" \$\@

  return 0
}

function interference-bump() {
  set -euo pipefail

  local _PACKAGES _PKGTAG _BUMPSFILE _BUMPS
  local _BUMPS_TMP _BUMPS_UPD _BUMPS_BRK _BUMP _LINE

  _BUMPSFILE="${CAUR_INTERFERE}/PKGREL_BUMPS"

  if [[ -f "${_BUMPSFILE}" ]]; then
    _BUMPS=$(sort -u "${_BUMPSFILE}")
  else
    _BUMPS=""
  fi

  # put into format: [name] [version]-pkgrel bump
  _PACKAGES="$(
    repoctl list -v \
      | sed -E \
        -e 's@-([0-9]+\S*)$@-\1 0@' \
        -e 's@-([0-9]+)(\.([0-9]+)) 0$@-\1 \3@' \
      | sort -u
  )"

  ## Clear old bumps
  # collect packages that have not been rebuilt
  _BUMPS_TMP=$(
    comm -13 \
      <(sort -u <<<"${_PACKAGES}" || true) \
      <(sort -u <<<"${_BUMPS}" || true)
  )

  # collect existing versions of packages
  _BUMPS_TMP+=$(
    echo
    while read -r _LINE; do
      [[ -z "${_LINE}" ]] && continue
      grep -E '^'"${_LINE%% *}"'\b .*$' <<<"${_PACKAGES}"
    done <<<"${_BUMPS_TMP}"
  )

  _BUMPS_TMP=$(
    echo
    sort -u <<<"${_BUMPS_TMP}"
  )

  _BUMPS_BRK="${_BUMPS_TMP}"

  # remove broken packages; keep updated packages
  _BUMPS_TMP=$(
    sed -Ez \
      -e 's&\n(\S+ \S+) \S+\n\1 \S+\n&\n\n&g' \
      -e 's&\n(\S+ \S+) \S+\n\1 \S+\n&\n\n&g' \
      <<<"${_BUMPS_TMP}"
  )

  _BUMPS_UPD=$(
    sort -u <<<"${_BUMPS_TMP}"
  )

  # keep broken packages only
  _BUMPS_BRK=$(
    comm -23 \
      <(sort -u <<<"${_BUMPS_BRK}" || true) \
      <(sort -u <<<"${_BUMPS_UPD}" || true)
  )

  # remove updated packages from bump list
  _BUMPS_TMP=$(sed -E 's& .*$&&' <<<"${_BUMPS_UPD}")

  while read -r _LINE; do
    [[ -z "${_LINE}" ]] && continue
    _BUMPS=$(
      sed -E "s&^${_LINE} .*+\$&&" <<<"${_BUMPS}"
    )
  done <<<"${_BUMPS_TMP}"

  # Add/increase existing bumps
  for _PKGTAG in "$@"; do
    [[ -z "${_PKGTAG}" ]] && continue
    _LINE=$(grep -E "^${_PKGTAG} " <<<"${_BUMPS}")
    _BUMP=$(sed -E 's&^.* ([0-9]+)&\1&' <<<"${_LINE}")
    _BUMPS=$(sed -E 's&^('"${_LINE% *}"') '"${_BUMP}"'$&\1 '"$((_BUMP + 1))"'&' <<<"${_BUMPS}")
  done

  echo "${_BUMPS_BRK}"
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
