#!/bin/bash
set -xeuo pipefail

mkdir -p "${HOME}/.chaotic"
cat >"${HOME}/.chaotic/chaotic.conf" <<'EOF'
#!/bin/bash
CAUR_DB_NAME='chaotic-aur'                                 # hardcoded in Singularity engine
CAUR_CLUSTER_NAME='ufscar-hpc'
CAUR_INTERFERE="${HOME}/chaotic/interfere"
CAUR_PACKAGE_LISTS="${HOME}/chaotic/packages"

CAUR_ENGINE="singularity"
CAUR_DEPLOY_HOST='builds.garudalinux.org'
CAUR_DEPLOY_PATH='/srv/http/repos/chaotic-aur/x86_64/'
CAUR_SCP_STREAMS=2
CAUR_BASH_WIZARD='wizard.sh'
CAUR_CACHE="/tmp/chaotic"
CAUR_CACHE_CC="${CAUR_CACHE}/cc"
CAUR_CACHE_PKG="${CAUR_CACHE}/packages"
CAUR_CACHE_SRC="${CAUR_CACHE}/sources"
CAUR_DB_EXT='tar.zst'
#CAUR_DB_LOCK='/var/cache/chaotic/db.lock'                 # not used in cluster mode
#CAUR_DEST_LAST="/srv/http/chaotic-aur/lastupdate"         # not used in cluster mode
#CAUR_DEST_PKG="/srv/http/${CAUR_DB_NAME}/x86_64"          # not used in cluster mode
CAUR_GUEST="${HOME}/chaotic/toolbox/guest"
CAUR_LIB="${HOME}/chaotic/toolbox/src/lib"
CAUR_LOWER_DIR="${HOME}/chaotic/cache/lower"
CAUR_LOWER_PKGS=(base base-devel)                          # hardcoded in Singularity engine
CAUR_SANDBOX='/scratch/chaotic/sandbox'
CAUR_ROUTINES="${CAUR_CACHE}/routines"
CAUR_SIGN_KEY='EF925EA60F33D0CB85C44AD13056513887B78AEB'
CAUR_SIGN_USER=''     # leave empty to run as current user
CAUR_TYPE='cluster'   # only the primary cluster manages the database.
CAUR_URL="https://builds.garudalinux.org/repos/${CAUR_DB_NAME}/x86_64"   # hardcoded in Singularity engine
CAUR_GPG_PATH="${HOME}/chaotic/toolbox/wrappers/gpg"

CAUR_REPOCTL_DB_URL='https://builds.garudalinux.org/repos/chaotic-aur/x86_64/chaotic-aur.db.tar.zst'
CAUR_REPOCTL_DB_FILE="${CAUR_CACHE}/chaotic-aur.db.tar.zst"
EOF

mkdir -p "${HOME}/chaotic"
for repo in toolbox interfere packages; do
  [[ -d "${HOME}/chaotic/${repo}" ]] || git clone "https://github.com/chaotic-aur/${repo}.git" "${HOME}/chaotic/${repo}"
done

pushd "${HOME}/chaotic/toolbox/src"
ln -sf "./chaotic.sh" "./chaotic"
popd

FILE="${HOME}/.bashrc"
# shellcheck disable=SC2016
LINE='export PATH="$PATH:$HOME/chaotic/toolbox/src:$HOME/chaotic/toolbox/wrappers"'
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

"${HOME}/chaotic/toolbox/wrappers/pacman" -Syu

echo 'Now set up ~/.config/telegram*.conf and GnuPG key'
