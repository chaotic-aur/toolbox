#!/usr/bin/env bash

function clean-sig() {
  cd /srv/http/repos/chaotic-aur/x86_64 || exit
  mkdir -p ../archive

  chaotic dbb
  chaotic dedup

  TO_MV=()
  for pkg in ./*.pkg.tar.zst; do
  [[ "${pkg}" == './*.pkg.tar.zst' ]] && continue
  if [[ ! -f "${pkg}.sig" ]]; then
  TO_MV+=("$pkg");
  fi
  done

  if [[ -z "${TO_MV:-}" ]]; then
  echo '[!] Nothing to do...'
  exit 0
  fi

  echo '[!] Missing sig:'
  ls -lh "${TO_MV[@]}"

  if [[ "$1" != "--quiet" ]]; then
  read -r -p "[?] Are you sure? [y/N] " U_SURE
  case "$U_SURE" in
  [yY])
  mv -t ../archive "${TO_MV[@]}"
  ls -- *.pkg.* >../pkgs.files.txt
  ;;
  esac
  else
  mv -t ../archive "${TO_MV[@]}"
  ls -- *.pkg.* >../pkgs.files.txt
  fi
}
