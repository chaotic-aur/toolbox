#!/usr/bin/env bash

function lowerstrap() {
  set -euo pipefail

  mkdir -p "$CAUR_LOWER_DIR"
  if [[ -f "$CAUR_LOWER_DIR/lock" ]]; then
    echo 'Somone is already building a lowerdir, waiting...'
    while [[ -f "$CAUR_LOWER_DIR/lock" ]]; do sleep 2; done
    return 0
  fi

  trap 'rm "${CAUR_LOWER_DIR}/lock"' EXIT HUP INT TERM ERR
  echo $$ >"${CAUR_LOWER_DIR}/lock" # We're building a new

  if [[ "${CAUR_ENGINE}" = "systemd-nspawn" ]]; then
    lowerstrap-systemd-nspawn "$@"
  elif [[ "${CAUR_ENGINE}" = "singularity" ]]; then
    lowerstrap-singularity "$@"
  else
    echo "Unsupported engine '${CAUR_ENGINE}'"
    exit 255
  fi
}

function lowerstrap-systemd-nspawn() {
  local _CURRENT

  mkdir -p "$CAUR_LOWER_DIR"
  pushd "$CAUR_LOWER_DIR"

  _CURRENT="$(date +%Y%m%d%H%M%S)"

  mkdir "$_CURRENT"
  pacstrap -c "./$_CURRENT" "${CAUR_LOWER_PKGS[@]}"
  pushd "$_CURRENT"

  install -dm755 './usr/local/bin'
  install -m644 "$CAUR_GUEST"/etc/* './etc/'
  install -m755 "$CAUR_GUEST"/bin/* './usr/local/bin/'

  stee -a './etc/pacman.conf' <<EOF

[${CAUR_DB_NAME}]
SigLevel = Never
Server = ${CAUR_URL}

EOF

  echo 'en_US.UTF-8 UTF-8' | stee './etc/locale.gen'
  echo 'LANG=en_US.UTF-8' | stee './etc/locale.conf'
  ln -rsf './usr/share/zoneinfo/America/Sao_Paulo' './etc/localtime'

  arch-chroot . /usr/bin/bash <<EOF
#!/usr/bin/env sh
set -euo pipefail

locale-gen
useradd -Uu $CAUR_GUEST_UID -m -s /bin/bash "$CAUR_GUEST_USER"
EOF

  install -dm755 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_GID}" \
    "./home/$CAUR_GUEST_USER/"{pkgwork,.ccache,pkgdest,pkgsrc,makepkglogs}

  popd # _CURRENT
  ln -sf "./$_CURRENT" "./latest"

  popd # CAUR_LOWER_DIR
  return 0
}

function lowerstrap-singularity() {
  local _CURRENT

  _CURRENT="$(date +%Y%m%d%H%M%S).sif"

  pushd "$CAUR_GUEST"
  singularity build --fakeroot --force "${CAUR_LOWER_DIR}/${_CURRENT}" Singularity
  popd # CAUR_GUEST

  pushd "$CAUR_LOWER_DIR"
  ln -sf "./$_CURRENT" "./latest"
  popd # CAUR_LOWER_DIR

  return 0
}
