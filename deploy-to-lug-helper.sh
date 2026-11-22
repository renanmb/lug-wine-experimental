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

HOST_USER="tarfy"
HOST_HOME="/home/${HOST_USER}"
if [ -d "${HOST_HOME}/Games/star-citizen" ]; then
    SC_GAMES_DIR="${HOST_HOME}/Games/star-citizen"
else
    SC_GAMES_DIR="${HOME}/Games/star-citizen"
fi
HOST_GAMES_DIR="${HOST_HOME}/Games/star-citizen"
if [ -d "${HOST_HOME}" ]; then
    LUTRIS_RUNNERS_DIR="${HOST_HOME}/.local/share/lutris/runners/wine"
else
    LUTRIS_RUNNERS_DIR="${HOME}/.local/share/lutris/runners/wine"
fi

fix_ownership() {
    local target="$1"
    if [ "$(id -u)" -eq 0 ] && [ -e "${target}" ]; then
        if id "${HOST_USER}" &>/dev/null; then
            chown -R "${HOST_USER}:${HOST_USER}" "${target}"
        elif [ -d "${SC_GAMES_DIR}" ]; then
            chown -R "$(stat -c '%u:%g' "${SC_GAMES_DIR}")" "${target}"
        else
            chown -R 1000:1000 "${target}"
        fi
    fi
}

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
    (cd "$(dirname "${TARGET_TARBALL}")" && sha256sum "$(basename "${TARGET_TARBALL}")" > "$(basename "${SHA_FILE}")")
fi

RUNNER_NAME="$(basename "${TARGET_TARBALL}" .tar.gz)"

# 2. Deploy to lug-helper/runners/
if [ -d "${LUG_HELPER_DIR}" ]; then
    echo "Deploying to LUG Helper runners directory..."
    mkdir -p "${LUG_HELPER_DIR}/runners/${RUNNER_NAME}"
    tar --no-same-owner -xzf "${TARGET_TARBALL}" -C "${LUG_HELPER_DIR}/runners/"
    cp -f "${TARGET_TARBALL}" "${LUG_HELPER_DIR}/runners/"
    [ -f "${SHA_FILE}" ] && cp -f "${SHA_FILE}" "${LUG_HELPER_DIR}/runners/"
    fix_ownership "${LUG_HELPER_DIR}/runners/${RUNNER_NAME}"
    fix_ownership "${LUG_HELPER_DIR}/runners/$(basename "${TARGET_TARBALL}")"
    [ -f "${SHA_FILE}" ] && fix_ownership "${LUG_HELPER_DIR}/runners/$(basename "${SHA_FILE}")"
    echo "  [OK] Deployed to ${LUG_HELPER_DIR}/runners/${RUNNER_NAME}"
else
    echo "Note: LUG Helper repository directory not found at ${LUG_HELPER_DIR}. Skipping copy to repository."
fi

# 3. Deploy to Star Citizen prefix runners
echo "Deploying to Star Citizen prefix (${SC_GAMES_DIR}/runners)..."
mkdir -p "${SC_GAMES_DIR}/runners"
tar --no-same-owner -xzf "${TARGET_TARBALL}" -C "${SC_GAMES_DIR}/runners/"
fix_ownership "${SC_GAMES_DIR}/runners/${RUNNER_NAME}"
echo "  [OK] Deployed to ${SC_GAMES_DIR}/runners/${RUNNER_NAME}"

# 4. Deploy to Lutris wine runners
echo "Deploying to Lutris Wine runners (${LUTRIS_RUNNERS_DIR})..."
mkdir -p "${LUTRIS_RUNNERS_DIR}"
tar --no-same-owner -xzf "${TARGET_TARBALL}" -C "${LUTRIS_RUNNERS_DIR}/"
fix_ownership "${LUTRIS_RUNNERS_DIR}"
echo "  [OK] Deployed to ${LUTRIS_RUNNERS_DIR}/${RUNNER_NAME}"

# 5. Configure sc-launch.sh (wine_path, virtual cable audio isolation, and Vulkan renderer)
SC_LAUNCH="${SC_GAMES_DIR}/sc-launch.sh"
if [ -f "${SC_LAUNCH}" ]; then
    echo "Updating wine_path and audio isolation config in ${SC_LAUNCH}..."
    sed -i "s|^export wine_path=.*|export wine_path=\"${HOST_GAMES_DIR}/runners/${RUNNER_NAME}/bin\"|" "${SC_LAUNCH}"
    if ! grep -q 'SC_VIRTUAL_CABLE' "${SC_LAUNCH}"; then
        python3 - "${SC_LAUNCH}" <<'PY'
import sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
block = """# Virtual audio cable isolation for OBS / streaming (1 = route game audio to Virtual_Speaker / virtspk, 0 = normal desktop audio)
export SC_VIRTUAL_CABLE="${SC_VIRTUAL_CABLE:-1}"
if [ "${SC_VIRTUAL_CABLE}" = "1" ] && command -v pactl >/dev/null 2>&1; then
    VIRTUAL_CABLE_SCRIPT="/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh"
    if ! pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -qx "virtspk"; then
        if [ -f "${VIRTUAL_CABLE_SCRIPT}" ]; then
            bash "${VIRTUAL_CABLE_SCRIPT}" >/dev/null 2>&1 || true
        fi
    fi
    if pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -qx "virtspk"; then
        export PULSE_SINK="virtspk"
    fi
    unset VIRTUAL_CABLE_SCRIPT
fi

"""
anchor = "############################################################################\n# END ENVIRONMENT VARIABLES"
if anchor in content:
    content = content.replace(anchor, block + anchor, 1)
else:
    anchor2 = "##################\n# Wine binary path"
    if anchor2 in content:
        content = content.replace(anchor2, block + anchor2, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
    fi
    fix_ownership "${SC_LAUNCH}"
    echo "  [OK] Updated sc-launch.sh to target ${RUNNER_NAME} (with SC_VIRTUAL_CABLE support)"
fi

SC_INSTALL_ROOT="${SC_GAMES_DIR}/drive_c/Program Files/Roberts Space Industries/StarCitizen"
for channel_dir in "${SC_INSTALL_ROOT}"/LIVE "${SC_INSTALL_ROOT}"/PTU "${SC_INSTALL_ROOT}"/EPTU "${SC_INSTALL_ROOT}"/TECH-PREVIEW; do
    [ -d "${channel_dir}" ] || continue
    cfg_file="${channel_dir}/user.cfg"
    if [ -f "${cfg_file}" ]; then
        if grep -qE '^[[:space:]]*r\.GraphicsRenderer[[:space:]]*=' "${cfg_file}"; then
            sed -i -E 's|^[[:space:]]*r\.GraphicsRenderer[[:space:]]*=.*|r.GraphicsRenderer = 1|' "${cfg_file}"
        else
            printf '\nr.GraphicsRenderer = 1\n' >> "${cfg_file}"
        fi
    else
        printf 'r.GraphicsRenderer = 1\n' > "${cfg_file}"
    fi
    fix_ownership "${cfg_file}"
done

if command -v python3 >/dev/null 2>&1; then
    python3 - "${SC_GAMES_DIR}" <<'PY'
import glob, json, os, sys
prefix = sys.argv[1]
for sc_dir in glob.glob(os.path.join(prefix, "drive_c", "users", "*", "AppData", "Local", "star citizen", "starcitizen_*")):
    if not os.path.isdir(sc_dir):
        continue
    gs_dir = os.path.join(sc_dir, "GraphicsSettings")
    os.makedirs(gs_dir, exist_ok=True)
    gs_file = os.path.join(gs_dir, "GraphicsSettings.json")
    data = {}
    if os.path.isfile(gs_file):
        try:
            with open(gs_file, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                data = loaded
        except Exception:
            data = {}
    gs = data.get("GraphicsSettings")
    if not isinstance(gs, dict):
        gs = {}
    gs["SettingsVersion"] = 1
    gs["GraphicsRenderer"] = 1
    data["GraphicsSettings"] = gs
    with open(gs_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
    for gs_dir in "${SC_GAMES_DIR}"/drive_c/users/*/AppData/Local/"star citizen"/starcitizen_*/GraphicsSettings; do
        [ -d "${gs_dir}" ] && fix_ownership "${gs_dir}"
    done
fi
echo "  [OK] Configured Vulkan (GraphicsRenderer = 1) as standard startup renderer"

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
