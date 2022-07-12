#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2164

pushd() { command pushd "$@" >/dev/null; }
popd() { command popd >/dev/null; }
stee() { command tee "$@" >/dev/null; }

pushd "$(dirname "$0")/.." || exit 2
CAUR_PREFIX="$(pwd -P)"
[[ -z "${HOME:-}" ]] && HOME="$(getent passwd "$(whoami)" | cut -d: -f6)"
export HOME
CAUR_MAINTAINER="${CAUR_REAL_USER:-${CAUR_REAL_UID:-${USER:-$UID}}}"
popd || exit 2

CAUR_CACHE='/var/cache/chaotic'
CAUR_CLUSTER_NAME=''
CAUR_DB_NAME='chaotic-aur'
CAUR_INTERFERE='/var/lib/chaotic/interfere'
CAUR_PACKAGE_LISTS='/var/lib/chaotic/packages'

CAUR_ARCH_MIRROR="Server = https://cloudflaremirrors.com/archlinux/\$repo/os/\$arch\nServer = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch"
CAUR_BASH_WIZARD='wizard.sh'
CAUR_CACHE_CC="${CAUR_CACHE}/cc"
CAUR_CACHE_PKG="${CAUR_CACHE}/packages"
CAUR_CACHE_SRC="${CAUR_CACHE}/sources"
CAUR_CLEAN_ONLY_DEPLOYED=0
CAUR_DB_EXT='tar.zst'
CAUR_DB_LOCK="${CAUR_CACHE}/db.lock"
CAUR_CHECKPOINT="${CAUR_CACHE}/checkpoint"
CAUR_DEPLOY_HOST='builds.garudalinux.org'
CAUR_DEPLOY_PKGS="/srv/http/repos/${CAUR_DB_NAME}/x86_64"
CAUR_DEPLOY_LOGS="/srv/http/repos/${CAUR_DB_NAME}/logs"
CAUR_DEPLOY_LOGS_FILTERED="$CAUR_DEPLOY_LOGS/filtered"
CAUR_DEPLOY_LAST="/srv/http/repos/${CAUR_DB_NAME}/lastupdate"
CAUR_USERNS_EXEC_CMD="podman unshare"
CAUR_ENGINE="systemd-nspawn"
CAUR_FILL_DEST='https://builds.garudalinux.org/repos/chaotic-aur/pkgs.files.txt'
CAUR_GPG_PATH="/usr/bin/gpg"
CAUR_LIB="${CAUR_PREFIX}/lib/chaotic"
CAUR_GUEST="${CAUR_LIB}/guest"
CAUR_LOWER_DIR="${CAUR_CACHE}/lower"
CAUR_LOWER_PKGS=(base base-devel)
CAUR_OVERLAY_TYPE='kernel'
CAUR_TEMP='/tmp/chaotic'
CAUR_ROUTINES="${CAUR_TEMP}/routines"
CAUR_SANDBOX='' # singularity only
CAUR_SIGN_KEY=''
CAUR_SIGN_USER='root' # who owns the key in gnupg's keyring.
CAUR_PACKAGER='Chaotic-AUR Team <team@chaotic.cx>'
CAUR_SILENT=0
CAUR_TELEGRAM="$HOME/.config/telegram-send-group.conf"
CAUR_TELEGRAM_LOG="$HOME/.config/telegram-send-log.conf"
CAUR_TYPE='primary' # only the primary cluster manages the database.
CAUR_URL="http://localhost/${CAUR_DB_NAME}/x86_64"
CAUR_TELEGRAM_TAG="@pedrohlc"
CAUR_STAMPROUTINES=0
CAUR_REPOCTL_DB_URL=''  # only required when not hosting a local mirror
CAUR_REPOCTL_DB_FILE='' # only required when not hosting a local mirror

# shellcheck source=/dev/null
[[ -f '/etc/chaotic.conf' ]] && source '/etc/chaotic.conf'

# shellcheck source=/dev/null
[[ -f "$HOME/.chaotic/chaotic.conf" ]] && source "$HOME/.chaotic/chaotic.conf"

[[ -z "${CAUR_DEPLOY_LABEL:-}" ]] && CAUR_DEPLOY_LABEL="${CAUR_CLUSTER_NAME:-Unknown Machine}"

if [ "$EUID" -ne 0 ] && [ "$CAUR_ENGINE" != "singularity" ]; then
  echo 'This script must be run as root.'
  exit 255
fi

if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ ! -e "${XDG_RUNTIME_DIR:-}" ]]; then
  # avoid error if $XDG_RUNTIME_DIR does not exist
  unset XDG_RUNTIME_DIR
fi

shopt -s extglob
for _LIB in "${CAUR_LIB}"/*.sh; do
  # shellcheck source=/dev/null
  source "${_LIB}"
done

function main() {
  set -euo pipefail

  local _CMD

  _CMD="${1:-}"
  # Note: there is usage of "${@:2}" below.

  case "${_CMD}" in
  '--jobs' | '-j')
    optional-parallel "${2:-}"
    main "${@:3}"
    ;;
  '--only-nuke-deployed' | '-D')
    optional-nuke-only-deployed
    main "${@:2}"
    ;;
  '--silent' | '-s')
    CAUR_SILENT=1
    export CAUR_SILENT
    main "${@:2}"
    ;;
  'prepare' | 'pr')
    prepare "${@:2}"
    ;;
  'lowerstrap' | 'lw')
    lowerstrap "${@:2}"
    ;;
  'makepkg' | 'mk')
    makepkg "${@:2}"
    ;;
  'makepwd' | 'mkd')
    makepwd "${@:2}"
    ;;
  'interfere-sync' | 'si')
    interfere-sync "${@:2}"
    ;;
  'interfere-bump' | 'bump')
    interference-bump "${@:2}"
    ;;
  'package-lists-sync' | 'sp')
    package-lists-sync "${@:2}"
    ;;
  'repoctl-sync-db' | 'sd')
    repoctl-sync-db
    ;;
  'clean-duplicates' | 'dedup')
    clean-duplicates "${@:2}"
    ;;
  'clean-pkgcache' | 'clp')
    clean-pkgcache "${@:2}"
    ;;
  'clean-sigs')
    clean-sigs "${@:2}"
    ;;
  'deploy' | 'dp')
    deploy "${@:2}"
    ;;
  'db-add' | 'dba')
    db-add "${@:2}"
    ;;
  'db-bump' | 'dbb')
    db-bump "${@:2}"
    ;;
  'db-rebuild')
    db-rebuild "${@:2}"
    ;;
  'remove' | 'rm')
    remove "${@:2}"
    ;;
  'aur-download' | 'get')
    aur-download "${@:2}"
    ;;
  'cleanup' | 'cl')
    for f in "${@:2}"; do cleanup "$f"; done
    ;;
  'cleanpwd' | 'cld')
    cleanpwd "${@:2}"
    ;;
  'help' | '?')
    help-mirror "${@:2}"
    ;;
  'routine')
    for f in "${@:2}"; do routine "$f"; done
    ;;
  'clean-logs' | 'clg')
    clean-logs "${@:2}"
    ;;
  'clean-srccache' | 'cls')
    clean-srccache "${@:2}"
    ;;
  'reset-fakeroot-chown' | 'rfc')
    for f in "${@:2}"; do reset-fakeroot-chown "$f"; done
    ;;
  'send-group' | 'ag')
    send-group "${@:2}"
    ;;
  'send-log' | 'al')
    send-log "${@:2}"
    ;;
  'sort-logs' | 'srt')
    sort-logs "${@:2}"
    ;;
  'find-discarded')
    find-discarded "${@:2}"
    ;;
  'whoami')
    echo "#$UID or ${USER:-$(whoami)}, identified as ${CAUR_MAINTAINER} at \"$CAUR_DEPLOY_LABEL\"."
    ;;
  *)
    echo 'Wrong usage, check https://github.com/chaotic-aur/toolbox/blob/main/README.md for details on how to use.'
    return 254
    ;;
  esac
}

main "$@"
