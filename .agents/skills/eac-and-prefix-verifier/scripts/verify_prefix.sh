#!/usr/bin/env bash
# verify_prefix.sh
# Creates an ephemeral WINEPREFIX with a built LUG Wine runner to verify boot, registry, and EAC patches.

set -euo pipefail

RUNNER_INPUT="${1:-/workspaces/lug-wine-experimental/output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz}"
TEMP_EXTRACT=""
CLEANUP_EXTRACT=0

echo "======================================================="
echo " LUG Wine Prefix & EAC Smoke Test"
echo " Target Runner: $RUNNER_INPUT"
echo "======================================================="

if [ ! -e "$RUNNER_INPUT" ]; then
  echo "Error: Target runner $RUNNER_INPUT does not exist."
  exit 1
fi

if [ -f "$RUNNER_INPUT" ]; then
  echo "Extracting runner archive to temporary directory..."
  TEMP_EXTRACT=$(mktemp -d /tmp/wine-runner-extract-XXXXXX)
  CLEANUP_EXTRACT=1
  tar -xzf "$RUNNER_INPUT" -C "$TEMP_EXTRACT"
  RUNNER_DIR=$(find "$TEMP_EXTRACT" -maxdepth 1 -mindepth 1 -type d | head -n 1)
else
  RUNNER_DIR="$RUNNER_INPUT"
fi

if [ ! -x "$RUNNER_DIR/bin/wine" ]; then
  echo "Error: $RUNNER_DIR/bin/wine not found or not executable."
  [ "$CLEANUP_EXTRACT" -eq 1 ] && rm -rf "$TEMP_EXTRACT"
  exit 1
fi

WINE_BIN="$RUNNER_DIR/bin/wine"
WINE64_BIN="$RUNNER_DIR/bin/wine64"
WINESERVER_BIN="$RUNNER_DIR/bin/wineserver"
TEST_PREFIX=$(mktemp -d /tmp/wine-prefix-test-XXXXXX)

cleanup() {
  echo ""
  echo "Shutting down wineserver and cleaning up..."
  WINEPREFIX="$TEST_PREFIX" "$WINESERVER_BIN" -k 2>/dev/null || true
  rm -rf "$TEST_PREFIX"
  if [ "$CLEANUP_EXTRACT" -eq 1 ] && [ -n "$TEMP_EXTRACT" ]; then
    rm -rf "$TEMP_EXTRACT"
  fi
}
trap cleanup EXIT

echo "Runner detected: $("$WINE_BIN" --version)"
echo "Initializing ephemeral prefix at: $TEST_PREFIX"

# Disable Mono and Gecko prompts and GUI popups during automated testing
export WINEPREFIX="$TEST_PREFIX"
export WINEDEBUG="-all"
export WINEDLLOVERRIDES="mscoree,mshtml=d"
export DISPLAY=""
export WAYLAND_DISPLAY=""
export WINEFSYNC=1

# Initialize prefix
"$WINE_BIN" wineboot -u
"$WINESERVER_BIN" -w

echo ""
echo "--- Verifying Prefix Architecture & Files ---"

test_passed=1

# 1. Drive C & System folders
if [ -d "$TEST_PREFIX/drive_c/windows/system32" ]; then
  echo "  [PASS] drive_c/windows/system32 exists"
else
  echo "  [FAIL] drive_c/windows/system32 missing"
  test_passed=0
fi

if [ -d "$TEST_PREFIX/drive_c/windows/syswow64" ]; then
  echo "  [PASS] drive_c/windows/syswow64 exists (WoW64 active)"
else
  echo "  [FAIL] drive_c/windows/syswow64 missing"
  test_passed=0
fi

# 2. Registry files
if [ -f "$TEST_PREFIX/system.reg" ] && [ -f "$TEST_PREFIX/user.reg" ]; then
  echo "  [PASS] system.reg and user.reg created successfully"
else
  echo "  [FAIL] Registry files missing"
  test_passed=0
fi

# 3. Check reg_hide_wine patch in user.reg
echo ""
echo "--- Verifying LUG Custom Patches in Prefix ---"

if grep -q "HideWineExports" "$TEST_PREFIX/user.reg" 2>/dev/null; then
  echo "  [PASS] reg_hide_wine.patch verified (HideWineExports active in user.reg)"
else
  echo "  [WARN] HideWineExports not found in user.reg"
fi

# 4. Check dummy dlls in system32
if [ -f "$TEST_PREFIX/drive_c/windows/system32/devobj.dll" ] || [ -f "$TEST_PREFIX/drive_c/windows/system32/drvstore.dll" ]; then
  echo "  [PASS] dummy_dlls.patch verified (devobj.dll/drvstore.dll present)"
else
  echo "  [WARN] dummy_dlls not present in system32"
fi

# 5. Check VKD3D-Proton DLLs
echo ""
echo "--- Verifying VKD3D-Proton Integration ---"
if [ -f "$TEST_PREFIX/drive_c/windows/system32/d3d12.dll" ] && [ -f "$TEST_PREFIX/drive_c/windows/system32/d3d12core.dll" ]; then
  echo "  [PASS] VKD3D-Proton 64-bit DLLs present in system32 (d3d12.dll, d3d12core.dll)"
else
  echo "  [FAIL] VKD3D-Proton 64-bit DLLs missing in system32"
  test_passed=0
fi

if [ -f "$TEST_PREFIX/drive_c/windows/syswow64/d3d12.dll" ] && [ -f "$TEST_PREFIX/drive_c/windows/syswow64/d3d12core.dll" ]; then
  echo "  [PASS] VKD3D-Proton 32-bit DLLs present in syswow64 (d3d12.dll, d3d12core.dll)"
else
  echo "  [FAIL] VKD3D-Proton 32-bit DLLs missing in syswow64"
  test_passed=0
fi

# 6. Check cmd execution
echo ""
echo "--- Testing Wine Command Execution ---"
cmd_out=$("$WINE_BIN" cmd /c "echo Wine Prefix Execution OK" 2>/dev/null | tr -d '\r')
if [[ "$cmd_out" == *"Wine Prefix Execution OK"* ]]; then
  echo "  [PASS] 32-bit loader cmd.exe test passed: '$cmd_out'"
else
  echo "  [FAIL] 32-bit loader execution failed: '$cmd_out'"
  test_passed=0
fi

if [ -x "$WINE64_BIN" ]; then
  cmd64_out=$("$WINE64_BIN" cmd /c "echo Wine64 Prefix Execution OK" 2>/dev/null | tr -d '\r')
  if [[ "$cmd64_out" == *"Wine64 Prefix Execution OK"* ]]; then
    echo "  [PASS] 64-bit loader cmd.exe test passed: '$cmd64_out'"
  else
    echo "  [FAIL] 64-bit loader execution failed: '$cmd64_out'"
    test_passed=0
  fi
fi

echo ""
echo "======================================================="
if [ "$test_passed" -eq 1 ]; then
  echo "[SUCCESS] Ephemeral prefix smoke test passed completely!"
  exit 0
else
  echo "[FAILURE] One or more prefix tests failed."
  exit 1
fi
echo "======================================================="
