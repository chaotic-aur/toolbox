#!/usr/bin/env bash

function key-trust() {
  gpg --homedir "${CAUR_GUEST_GNUPG}" \
    --keyserver 'keys.gnupg.net' \
    --recv-keys "$@"
}
