#!/usr/bin/env bash

function routine-tkg() {
  set -euo pipefail
  local _ORG
  iterfere-sync
  push-routine-dir 'tkg' || return 12

  _ORG='https://github.com/Frogging-Family'
  git clone "$_ORG/vulkan-headers-git.git" 'vulkan-headers-tkg-git'
  git clone "$_ORG/llvm-git.git" 'llvm-tkg-git'
  git clone "$_ORG/mesa-git.git" 'mesa-tkg-git'
  git clone "$_ORG/spirv-tools-git.git" 'spirv-tools-tkg-git'
  git clone "$_ORG/gamescope-git.git" 'gamescope-tkg-git'
  git clone "$_ORG/vulkan-icd-loader-git.git" 'vulkan-icd-loader-tkg-git'
  git clone "$_ORG/amdvlk-opt.git" 'amdvlk-tkg'
  git clone "$_ORG/vkd3d-git.git" 'vkd3d-tkg-git'
  git clone "$_ORG/faudio-git.git" 'faudio-tkg-git'
  git clone "$_ORG/neofrog-git.git" 'neofrog-git'

  makepwd
  clean-logs
  pop-routine-dir
  return 0
}
