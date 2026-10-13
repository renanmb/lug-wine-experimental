#!/usr/bin/env bash
# check_deps.sh
# Verifies presence of required build tools and libraries on Ubuntu 22.04 for Wine-TKG WoW64 compilation.

set -euo pipefail

echo "======================================================="
echo " Ubuntu 22.04 Build Environment Dependency Checker"
echo " Target: Wine-TKG WoW64 on GLIBC 2.35"
echo "======================================================="

missing_pkgs=()

check_cmd() {
  local cmd="$1"
  local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_pkgs+=("$pkg")
  fi
}

check_header() {
  local header="$1"
  local pkg="$2"
  if ! gcc -E -xc "$header" >/dev/null 2>&1 <<<"#include <$header>"; then
    missing_pkgs+=("$pkg")
  fi
}

# Core build tools & Cross compilers
check_cmd gcc "build-essential"
check_cmd g++ "build-essential"
check_cmd make "build-essential"
check_cmd x86_64-w64-mingw32-gcc "mingw-w64"
check_cmd i686-w64-mingw32-gcc "mingw-w64"
check_cmd flex "flex"
check_cmd bison "bison"
check_cmd git "git"
check_cmd curl "curl"
check_cmd pkg-config "pkg-config"
check_cmd glslangValidator "glslang-tools"
check_cmd meson "meson"
check_cmd ninja "ninja-build"

# Pkg-config library checks
check_pc() {
  local mod="$1"
  local pkg="$2"
  if ! pkg-config --exists "$mod" >/dev/null 2>&1; then
    missing_pkgs+=("$pkg")
  fi
}

check_pc "gstreamer-1.0" "libgstreamer1.0-dev"
check_pc "gstreamer-plugins-base-1.0" "libgstreamer-plugins-base1.0-dev"
check_pc "vulkan" "libvulkan-dev"
check_pc "openxr" "libopenxr-dev"
check_pc "wayland-client" "libwayland-dev"
check_pc "xkbcommon" "libxkbcommon-dev"
check_pc "alsa" "libasound2-dev"
check_pc "libpulse" "libpulse-dev"

# Headers
if [ ! -f /usr/local/include/linux/ntsync.h ] && [ ! -f /usr/include/linux/ntsync.h ]; then
  echo "[WARN] ntsync.h header missing in /usr/local/include/linux/ntsync.h"
  echo "       Run: sudo mkdir -p /usr/local/include/linux && sudo curl -o /usr/local/include/linux/ntsync.h https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/uapi/linux/ntsync.h"
fi

if [ ${#missing_pkgs[@]} -gt 0 ]; then
  echo ""
  echo "[!] Missing packages detected:"
  # deduplicate
  mapfile -t unique_pkgs < <(printf "%s\n" "${missing_pkgs[@]}" | sort -u)
  for p in "${unique_pkgs[@]}"; do
    echo "  - $p"
  done
  echo ""
  echo "Suggested install command:"
  echo "  sudo apt-get update && sudo apt-get install -y ${unique_pkgs[*]}"
  exit 1
else
  echo "[PASS] Core build tools and MinGW-w64 cross compiler are available."
  exit 0
fi
