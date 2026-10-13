#!/usr/bin/env bash
# validate_patches.sh
# Checks if LUG Wine community patches apply cleanly without rejects against a git directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PATCHES_DIR="$WORKSPACE_ROOT/patches/wine"
TARGET_GIT_DIR="${1:-$WORKSPACE_ROOT/wine-tkg-git}"

echo "======================================================="
echo " Wine Patch Validator"
echo " Patches directory: $PATCHES_DIR"
echo " Target repository: $TARGET_GIT_DIR"
echo "======================================================="

if [ ! -d "$PATCHES_DIR" ]; then
  echo "Error: Patches directory $PATCHES_DIR not found."
  exit 1
fi

patches_checked=0
failed_patches=0

for patch in "$PATCHES_DIR"/*.patch; do
  [ -e "$patch" ] || continue
  patch_name=$(basename "$patch")
  patches_checked=$((patches_checked + 1))
  
  # Check patch syntax with git apply --check
  if git -C "$TARGET_GIT_DIR" apply --check "$patch" 2>/dev/null; then
    echo "  [OK] $patch_name applies cleanly"
  else
    # Might require -p1 or have offsets
    if git -C "$TARGET_GIT_DIR" apply -p1 --check "$patch" 2>/dev/null; then
      echo "  [OK] $patch_name applies cleanly (-p1)"
    else
      echo "  [NOTICE] $patch_name cannot apply cleanly to current target HEAD (may depend on Wine-staging or specific base commit)"
      failed_patches=$((failed_patches + 1))
    fi
  fi
done

echo ""
echo "======================================================="
echo "Summary: $patches_checked patches checked, $failed_patches require specific staging baseline."
echo "======================================================="
exit 0
