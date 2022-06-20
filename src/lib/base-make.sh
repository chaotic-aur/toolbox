#!/usr/bin/env bash

function lowerstrap() {
  set -euo pipefail

  local _LOCK_FN _LOCK_FD

  [[ ! -e "$CAUR_LOWER_DIR" ]] && install -o"$(whoami)" -dDm755 "$CAUR_LOWER_DIR"

  _LOCK_FN="${CAUR_LOWER_DIR}/lock"
  touch "${_LOCK_FN}"
  exec {_LOCK_FD}<>"${_LOCK_FN}" # Lock

  if ! flock -x -n "$_LOCK_FD"; then
    echo 'Someone is already building a lowerdir, waiting...'
    flock -x "$_LOCK_FD" -c true
    echo 'Finished'
    exec {_LOCK_FD}>&- # Unlock
    return 0
  fi

  if [[ "${CAUR_ENGINE}" = "systemd-nspawn" ]]; then
    lowerstrap-systemd-nspawn "$@"
  elif [[ "${CAUR_ENGINE}" = "singularity" ]]; then
    lowerstrap-singularity "$@"
  else
    echo "Unsupported engine '${CAUR_ENGINE}'"
    exec {_LOCK_FD}>&- # Unlock
    return 26
  fi

  exec {_LOCK_FD}>&- # Unlock
  return 0
}

function lowerstrap-systemd-nspawn() {
  set -euo pipefail

  echo 'Building a systemd-nspawn lowerdir'

  local _CURRENT

  install -o"$(whoami)" -dDm755 "$CAUR_LOWER_DIR"
  pushd "$CAUR_LOWER_DIR"

  _CURRENT="$(date +%Y%m%d%H%M%S)"

  install -o"$(whoami)" -dm755 "$_CURRENT"
  pacstrap -c "./$_CURRENT" "${CAUR_LOWER_PKGS[@]}"
  pushd "$_CURRENT"

  install -dm755 './usr/local/bin'
  install -m644 "$CAUR_GUEST"/etc/pacman.conf './etc/pacman.conf'
  tee -a './etc/makepkg.conf' <"${CAUR_GUEST}/etc/makepkg.conf.append"
  if [[ -n "$CAUR_ARCH_MIRROR" ]]; then
    echo "$CAUR_ARCH_MIRROR" | stee './etc/pacman.d/mirrorlist'
  fi
  echo "PACKAGER=\"${CAUR_PACKAGER}\"" | tee -a './etc/makepkg.conf'
  install -m755 "$CAUR_GUEST"/bin/* './usr/local/bin/'

  stee -a './etc/pacman.conf' <<EOF

[${CAUR_DB_NAME}]
SigLevel = Never
Server = ${CAUR_URL}

EOF

  echo 'en_US.UTF-8 UTF-8' | stee './etc/locale.gen'
  echo 'LANG=en_US.UTF-8' | stee './etc/locale.conf'
  ln -rsf './usr/share/zoneinfo/UTC' './etc/localtime'

  arch-chroot . /usr/bin/bash <<EOF
#!/usr/bin/env sh
set -euo pipefail

locale-gen
useradd -Uu 1000 -m -s /bin/bash "main-builder"
EOF

  install -dm755 -o"1000" -g"1000" \
    "./home/main-builder/"{pkgwork,.ccache,pkgsrc,makepkglogs} \
    './var/pkgdest'

  popd # _CURRENT
  ln -fsT "./$_CURRENT" "./latest"

  # Delete old, unused lowerdirs
  echo 'Deleting old systemd-nspawn lowerdirs'
  for d in */; do
    if [ -L "${d%/}" ] || [[ "${d%/}" == "$_CURRENT" ]]; then continue; fi
    if [[ "$(findmnt -rnO "lowerdir=$(realpath "$d")")" == "" ]]; then rm -rf --one-file-system "$d"; fi
  done

  popd # CAUR_LOWER_DIR
  return 0
}

function lowerstrap-singularity() {
  set -euo pipefail

  echo 'Building a singularity base image'

  local _CURRENT

  _CURRENT="$(date +%Y%m%d%H%M%S).sif"

  pushd "$CAUR_GUEST"
  singularity build --fakeroot --force "${CAUR_LOWER_DIR}/${_CURRENT}" Singularity
  popd # CAUR_GUEST

  pushd "$CAUR_LOWER_DIR"
  ln -fsT "./$_CURRENT" "./latest"
  popd # CAUR_LOWER_DIR

  return 0
}
