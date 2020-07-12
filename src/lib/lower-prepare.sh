#!/usr/bin/env bash

function lower-prepare() {
    set -o errexit

    if [[ -f "$CAUR_LOWER_DIR/lock" ]]; then
        echo 'Somone is already building a lowerdir'
        return 0
    fi

    mkdir -p "$CAUR_LOWER_DIR"
    pushd "$CAUR_LOWER_DIR"

    echo $$ > "lock" # We're building a new
    local _CURRENT="$(date +%Y%m%d%H%M%S)"

    mkdir "$_CURRENT"
    pacstrap -C "$CAUR_GUEST_PACMAN" "./$_CURRENT" $CAUR_LOWER_PKGS
    pushd "$_CURRENT"

    install -d755 './usr/local/bin'
    install -m644 "$CAUR_GUEST_ETC"/* './etc/'
    install -m755 "$CAUR_GUEST_BIN"/* './usr/local/bin/'

    echo 'en_US.UTF-8 UTF-8' | tee './etc/locale.gen'
    echo 'LANG=en_US.UTF-8' | tee './etc/locale.conf'
    ln -rsf './usr/share/zoneinfo/America/Sao_Paulo' './etc/localtime'

    arch-chroot . /usr/bin/bash <<EOF
#!/usr/bin/env sh
set -o errexit

locale-gen
useradd -Uu $CAUR_GUEST_UID -m -s /bin/bash "$CAUR_GUEST_USER"
EOF

    install -dm755 "./home/$CAUR_GUEST_USER/"{pkgwork,.ccache,pkgdest,pkgsrc,makepkglogs}
    install -dm700 "./home/$CAUR_GUEST_USER/.gnupg"
    install -Dm700 -o1000 \
        "$CAUR_GUEST_GNUPG"/{pubring.kbx,tofu.db,trustdb.gpg,crls.d} \
        "./home/$CAUR_GUEST_USER/.gnupg/"

    popd
    ln -s "./$_CURRENT" "./latest"
    rm lock

    popd
    return 0
}
