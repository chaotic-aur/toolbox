#!/usr/bin/env bash

function tkg-kernel-variate() {
  set -euo pipefail

  local _VER _SCHED _YIELD _MARCH _PKGBASE _TIMER_FREQ _RQ

  if [ ${#@} -ne 4 ]; then
    echo 'Invalid variate parameters'
    return 23
  fi

  _VER="$1"
  _SCHED="$2"
  _YIELD="$3"
  _MARCH="$4"

  _PKGBASE="linux-tkg-${_SCHED}-${_MARCH}"
  if [ "${_MARCH}" == 'generic' ]; then
    _PKGBASE="linux-tkg-${_SCHED}"
  elif [ "${_MARCH}" == 'lts' ]; then # LTS is generic-only
    _PKGBASE="linux-lts-tkg-${_SCHED}"
  fi

  _TIMER_FREQ=750
  if [ "${_SCHED}" == 'muqss' ]; then
    _TIMER_FREQ=100
  fi

  _RQ='none'
  if [ "${_MARCH}" == 'zen' ]; then
    _RQ='mc-llc'
  fi

  sed -i'' "
  s/_distro=\"[^\"]*\"/_distro=\"Arch\"/g
  s/_version=\"[^\"]*\"/_version=\"${_VER}\"/g
  s/_NUKR=\"[^\"]*\"/_NUKR=\"false\"/g
  s/_OPTIPROFILE=\"[^\"]*\"/_OPTIPROFILE=\"1\"/g
  s/_modprobeddb=\"[^\"]*\"/_modprobeddb=\"false\"/g
  s/_menunconfig=\"[^\"]*\"/_menunconfig=\"false\"/g
  s/_diffconfig=\"[^\"]*\"/_diffconfig=\"false\"/g
  s/_configfile=\"[^\"]*\"/_configfile=\"config.x86_64\"/g
  s/_cpusched=\"[^\"]*\"/_cpusched=\"${_SCHED}\"/g
  s/_compiler=\"[^\"]*\"/_compiler=\"gcc\"/g
  s/_rr_interval=\"[^\"]*\"/_rr_interval=\"default\"/g
  s/_sched_yield_type=\"[^\"]*\"/_sched_yield_type=\"${_YIELD}\"/g
  s/_ftracedisable=\"[^\"]*\"/_ftracedisable=\"true\"/g
  s/_numadisable=\"[^\"]*\"/_numadisable=\"false\"/g
  s/_tickless=\"[^\"]*\"/_tickless=\"2\"/g
  s/_voluntary_preempt=\"[^\"]*\"/_voluntary_preempt=\"false\"/g
  s/_acs_override=\"[^\"]*\"/_acs_override=\"true\"/g
  s/_ksm_uksm=\"[^\"]*\"/_ksm_uksm=\"true\"/g
  s/_bcachefs=\"[^\"]*\"/_bcachefs=\"true\"/g
  s/_bfqmq=\"[^\"]*\"/_bfqmq=\"true\"/g
  s/_zfsfix=\"[^\"]*\"/_zfsfix=\"true\"/g
  s/_fsync=\"[^\"]*\"/_fsync=\"true\"/g
  s/_anbox=\"[^\"]*\"/_anbox=\"true\"/g
  s/_processor_opt=\"[^\"]*\"/_processor_opt=\"${_MARCH}\"/g
  s/_smt_nice=\"[^\"]*\"/_smt_nice=\"true\"/g
  s/_random_trust_cpu=\"[^\"]*\"/_random_trust_cpu=\"true\"/g
  s/_runqueue_sharing=\"[^\"]*\"/_runqueue_sharing=\"${_RQ}\"/g
  s/_timer_freq=\"[^\"]*\"/_timer_freq=\"${_TIMER_FREQ}\"/g
  s/_user_patches=\"[^\"]*\"/_user_patches=\"false\"/g
  s/_custom_pkgbase=\"[^\"]*\"/_custom_pkgbase=\"${_PKGBASE}\"/g
  s/_misc_adds=\"[^\"]*\"/_misc_adds=\"true\"/g
  " customization.cfg

  echo '_nofallback="true"' >>customization.cfg

  return 0
}

function tkg-kernels-variations() {
  set -euo pipefail

  local _LINUX_LTS _LINUX_STABLE _LINUX_MARCH _VAR_SCHED _VAR_SCHED

  _LINUX_LTS='5.4'
  _LINUX_STABLE='5.10'

  _LINUX_SCHED=(
    'bmq 1'
    'pds 0'
    'cfs 0'
    'muqss 0'
  )

  readonly _LINUX_MARCH=('generic'
    'atom' 'barcelona' 'bobcat' 'broadwell'
    'bulldozer' {cannon,cascade,cooper}'lake'
    'core2' 'excavator' 'goldmont'{,plus}
    'haswell' 'icelake' 'ivybridge' 'jaguar'
    'k10' 'k8' 'k8sse3' 'mpsc' 'nehalem'
    'piledriver' 'sandybridge' 'silvermont'
    'skylake' 'skylakex' 'steamroller'
    'westmere' 'zen' 'zen2'
  )

  # lts
  for _VAR_SCHED in "${_LINUX_SCHED[@]}" 'muqss 0'; do
    echo "$_LINUX_LTS" "$_VAR_SCHED" 'lts'
  done

  # stable
  for _VAR_SCHED in "${_LINUX_SCHED[@]}"; do
    for _VAR_MARCH in "${_LINUX_MARCH[@]}"; do
      echo "$_LINUX_STABLE" "$_VAR_SCHED" "$_VAR_MARCH"
    done
  done

  return 0
}

function routine-tkg-kernels() {
  set -euo pipefail
  iterfere-sync
  push-routine-dir 'tkg.kernels' || return 12

  git clone 'https://github.com/Frogging-Family/linux-tkg.git' 'linux-tkg'

  local _VARIATIONS _VARIATION _i _DEST

  mapfile -t _VARIATIONS < <(tkg-kernels-variations)

  _i=0
  for _VARIATION in "${_VARIATIONS[@]}"; do
    _i=$((_i + 1))
    _DEST="linux-tkg.$(printf '%04d' $_i)"

    mkdir "$_DEST"
    cp -r 'linux-tkg'/* "$_DEST/"

    pushd "$_DEST"
    # shellcheck disable=SC2086
    tkg-kernel-variate $_VARIATION
    popd
  done

  rm -rf --one-file-system 'linux-tkg' || true

  (makepwd) || true
  clean-logs
  pop-routine-dir
  return 0
}
