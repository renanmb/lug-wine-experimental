#!/usr/bin/env bash
# audit_glibc.sh
# Analyzes ELF binaries and shared objects (.so) to verify that GLIBC symbol requirements do not exceed 2.35.

set -euo pipefail

TARGET_PATH="${1:-}"
MAX_ALLOWED_GLIBC="2.35"

if [ -z "$TARGET_PATH" ]; then
  echo "Usage: $0 <path_to_binary_or_directory> [max_glibc_version (default: 2.35)]"
  exit 1
fi

if [ "$#" -ge 2 ]; then
  MAX_ALLOWED_GLIBC="$2"
fi

echo "======================================================="
echo " GLIBC Compatibility Audit (Target: <= $MAX_ALLOWED_GLIBC)"
echo " Target: $TARGET_PATH"
echo "======================================================="

found_issues=0
checked_files=0

# Extract major and minor
max_major=$(echo "$MAX_ALLOWED_GLIBC" | cut -d. -f1)
max_minor=$(echo "$MAX_ALLOWED_GLIBC" | cut -d. -f2)

check_file() {
  local file="$1"
  # Follow symlink and check if ELF binary
  if ! file -bL "$file" 2>/dev/null | grep -q "ELF"; then
    return 0
  fi

  checked_files=$((checked_files + 1))
  
  # Find all GLIBC version symbols in the file
  local glibc_symbols
  glibc_symbols=$(readelf -V "$file" 2>/dev/null | grep -o 'GLIBC_[0-9]\+\.[0-9]\+' | sort -u || true)

  if [ -z "$glibc_symbols" ]; then
    return 0
  fi

  local file_has_issue=0
  for ver in $glibc_symbols; do
    local v_clean=${ver#GLIBC_}
    local v_major=$(echo "$v_clean" | cut -d. -f1)
    local v_minor=$(echo "$v_clean" | cut -d. -f2)

    if [ "$v_major" -gt "$max_major" ] || ([ "$v_major" -eq "$max_major" ] && [ "$v_minor" -gt "$max_minor" ]); then
      if [ "$file_has_issue" -eq 0 ]; then
        echo -e "\n[FAIL] $file requires unsupported GLIBC versions:"
        file_has_issue=1
        found_issues=$((found_issues + 1))
      fi
      echo "       - Requires $ver (Maximum allowed: GLIBC_$MAX_ALLOWED_GLIBC)"
    fi
  done
}

if [ -f "$TARGET_PATH" ]; then
  check_file "$TARGET_PATH"
elif [ -d "$TARGET_PATH" ]; then
  while IFS= read -r -d '' f; do
    check_file "$f"
  done < <(find "$TARGET_PATH" -type f \( -name "*.so*" -o -perm /111 \) -print0)
else
  echo "Error: Target $TARGET_PATH not found."
  exit 1
fi

echo ""
echo "======================================================="
echo "Audit Summary:"
echo "  Files checked: $checked_files"
echo "  Files exceeding GLIBC $MAX_ALLOWED_GLIBC: $found_issues"
echo "======================================================="

if [ "$found_issues" -gt 0 ]; then
  exit 1
else
  echo "[PASS] All checked ELF files are compatible with GLIBC <= $MAX_ALLOWED_GLIBC."
  exit 0
fi
