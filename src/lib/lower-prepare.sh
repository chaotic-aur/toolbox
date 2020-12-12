#!/usr/bin/env bash

function lowerstrap() {
  set -euo pipefail

  local _CURRENT

  if [[ -f "$CAUR_LOWER_DIR/lock" ]]; then
    echo 'Somone is already building a lowerdir, waiting...'
    while [[ -f "$CAUR_LOWER_DIR/lock" ]]; do sleep 2; done
    return 0
  fi

  mkdir -p "$CAUR_LOWER_DIR"
  pushd "$CAUR_LOWER_DIR"

  echo $$ >"lock" # We're building a new
  _CURRENT="$(date +%Y%m%d%H%M%S)"

  mkdir "$_CURRENT"
  pacstrap -c "./$_CURRENT" "$CAUR_LOWER_PKGS"
  pushd "$_CURRENT"

  install -dm755 './usr/local/bin'
  install -m644 "$CAUR_GUEST_ETC"/* './etc/'
  install -m755 "$CAUR_GUEST_BIN"/* './usr/local/bin/'

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

  echo "$CAUR_GUEST_USER ALL=(ALL) NOPASSWD: ALL" | stee -a "./etc/sudoers"

  install -dm755 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_GID}" \
    "./home/$CAUR_GUEST_USER/"{pkgwork,.ccache,pkgdest,pkgsrc,makepkglogs}
  install -dm700 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_GID}" \
    "./home/$CAUR_GUEST_USER/.gnupg"
  install -Dm700 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_UID}" \
    "$CAUR_GUEST_GNUPG"/{pubring.kbx,tofu.db,trustdb.gpg} \
    "./home/$CAUR_GUEST_USER/.gnupg/"
  install -dm700 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_UID}" \
    "./home/$CAUR_GUEST_USER/.gnupg/crls.d"
  install -Dm700 -o"${CAUR_GUEST_UID}" -g"${CAUR_GUEST_UID}" \
    "$CAUR_GUEST_GNUPG/crls.d/DIR.txt" \
    "./home/$CAUR_GUEST_USER/.gnupg/crls.d/"

  popd
  ln -s "./$_CURRENT" "./latest"
  rm lock

  popd
  return 0
}
