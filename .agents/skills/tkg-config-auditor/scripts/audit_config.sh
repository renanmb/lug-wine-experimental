#!/usr/bin/env bash
# audit_config.sh
# Audits LUG-Wine configuration files against upstream sample configuration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SAMPLE_CFG="$WORKSPACE_ROOT/wine-tkg-git/wine-tkg-git/wine-tkg-profiles/sample-external-config.cfg"
CONFIG_DIR="$WORKSPACE_ROOT/config"

echo "======================================================="
echo " Wine-TKG Configuration Auditor"
echo " Comparing local configs with upstream sample template"
echo "======================================================="

if [ ! -f "$SAMPLE_CFG" ]; then
  echo "Notice: Sample config $SAMPLE_CFG not found. Check wine-tkg-git submodule."
  exit 1
fi

# Extract variable names from sample config
upstream_vars=$(grep -oE '^(_[a-zA-Z0-9_]+|CUSTOM_[a-zA-Z0-9_]+)=' "$SAMPLE_CFG" | tr -d '=' | sort -u)

for cfg in "$CONFIG_DIR"/*.cfg; do
  [ -e "$cfg" ] || continue
  cfg_name=$(basename "$cfg")
  echo ""
  echo "--- Auditing $cfg_name ---"
  
  # Check key WoW64 setting for Ubuntu 22.04
  nolib32_val=$(grep -E '^_NOLIB32=' "$cfg" || true)
  echo "  WoW64 Setting: $nolib32_val"
  if [[ "$nolib32_val" != *"wow64"* ]]; then
    echo "  [WARN] _NOLIB32 is not set to 'wow64'! For Ubuntu 22.04 with glibc 2.35, WoW64 is recommended to avoid 32-bit multilib issues."
  fi
  
  # Check if any variables in cfg are missing from upstream
  local_vars=$(grep -oE '^(_[a-zA-Z0-9_]+|CUSTOM_[a-zA-Z0-9_]+)=' "$cfg" | tr -d '=' | sort -u)
  unknown_vars=0
  for v in $local_vars; do
    if ! echo "$upstream_vars" | grep -qx "$v"; then
      echo "  [INFO] Custom / non-upstream variable: $v"
      unknown_vars=$((unknown_vars + 1))
    fi
  done
  echo "  Audited: $(echo "$local_vars" | wc -l) variables checked."
done

echo ""
echo "======================================================="
echo "Config Audit Complete."
echo "======================================================="
