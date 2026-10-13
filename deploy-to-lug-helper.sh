#!/usr/bin/env bash
# deploy-to-lug-helper.sh
# Deploys the built LUG Wine runner to the local lug-helper repository,
# Star Citizen prefix, and Lutris runner directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TARGET_TARBALL="${1:-$(find "${OUTPUT_DIR}" -name "lug-wine-*.tar.gz" -type f | sort -V | tail -n 1)}"

LUG_HELPER_DIR="${2:-/home/tarfy/Documents/GitHub/renanmb/lug-helper}"
if [ ! -d "${LUG_HELPER_DIR}" ] && [ -d "${HOME}/Documents/GitHub/renanmb/lug-helper" ]; then
    LUG_HELPER_DIR="${HOME}/Documents/GitHub/renanmb/lug-helper"
elif [ ! -d "${LUG_HELPER_DIR}" ] && [ -d "/lug-helper" ]; then
    LUG_HELPER_DIR="/lug-helper"
fi

SC_GAMES_DIR="${HOME}/Games/star-citizen"
LUTRIS_RUNNERS_DIR="${HOME}/.local/share/lutris/runners/wine"

echo "======================================================="
echo " Deploying LUG Wine Runner to LUG Helper"
echo " Tarball:    ${TARGET_TARBALL}"
echo " LUG Helper: ${LUG_HELPER_DIR}"
echo "======================================================="

if [ -z "${TARGET_TARBALL}" ] || [ ! -f "${TARGET_TARBALL}" ]; then
    echo "Error: Target runner tarball not found at ${TARGET_TARBALL}"
    exit 1
fi

# 1. Verify SHA256 checksum
SHA_FILE="${TARGET_TARBALL}.sha256sum"
if [ -f "${SHA_FILE}" ]; then
    echo "Verifying SHA256 checksum..."
    (cd "$(dirname "${TARGET_TARBALL}")" && sha256sum -c "$(basename "${SHA_FILE}")")
else
    echo "Warning: Checksum file ${SHA_FILE} not found. Generating..."
    sha256sum "${TARGET_TARBALL}" > "${SHA_FILE}"
fi

RUNNER_NAME="$(basename "${TARGET_TARBALL}" .tar.gz)"

# 2. Deploy to lug-helper/runners/
if [ -d "${LUG_HELPER_DIR}" ]; then
    echo "Deploying to LUG Helper runners directory..."
    mkdir -p "${LUG_HELPER_DIR}/runners/${RUNNER_NAME}"
    tar -xzf "${TARGET_TARBALL}" -C "${LUG_HELPER_DIR}/runners/"
    cp -f "${TARGET_TARBALL}" "${LUG_HELPER_DIR}/runners/"
    [ -f "${SHA_FILE}" ] && cp -f "${SHA_FILE}" "${LUG_HELPER_DIR}/runners/"
    echo "  [OK] Deployed to ${LUG_HELPER_DIR}/runners/${RUNNER_NAME}"
else
    echo "Note: LUG Helper repository directory not found at ${LUG_HELPER_DIR}. Skipping copy to repository."
fi

# 3. Deploy to Star Citizen prefix runners
echo "Deploying to Star Citizen prefix (${SC_GAMES_DIR}/runners)..."
mkdir -p "${SC_GAMES_DIR}/runners"
tar -xzf "${TARGET_TARBALL}" -C "${SC_GAMES_DIR}/runners/"
echo "  [OK] Deployed to ${SC_GAMES_DIR}/runners/${RUNNER_NAME}"

# 4. Deploy to Lutris wine runners
echo "Deploying to Lutris Wine runners (${LUTRIS_RUNNERS_DIR})..."
mkdir -p "${LUTRIS_RUNNERS_DIR}"
tar -xzf "${TARGET_TARBALL}" -C "${LUTRIS_RUNNERS_DIR}/"
echo "  [OK] Deployed to ${LUTRIS_RUNNERS_DIR}/${RUNNER_NAME}"

# 5. Configure sc-launch.sh if present
SC_LAUNCH="${SC_GAMES_DIR}/sc-launch.sh"
if [ -f "${SC_LAUNCH}" ]; then
    echo "Updating wine_path in ${SC_LAUNCH}..."
    sed -i "s|^export wine_path=.*|export wine_path=\"${SC_GAMES_DIR}/runners/${RUNNER_NAME}/bin\"|" "${SC_LAUNCH}"
    echo "  [OK] Updated sc-launch.sh to target ${RUNNER_NAME}"
fi

# 6. Verify runner execution
DEPLOYED_WINE="${SC_GAMES_DIR}/runners/${RUNNER_NAME}/bin/wine"
if [ -x "${DEPLOYED_WINE}" ]; then
    echo "Verifying deployed runner execution..."
    RUNNER_VER="$("${DEPLOYED_WINE}" --version)"
    echo "  [OK] Successfully executed: ${RUNNER_VER}"
fi

echo "======================================================="
echo " Deployment Complete!"
echo "======================================================="
