# 3. Replication & Clean OS Install Guide

Follow this step-by-step runbook to reproduce this entire Star Citizen LUG Wine build and runtime environment on **another Linux machine** or after performing a **clean OS install** on your current workstation.

---

## Phase 1: Host Prerequisites & Cloning Repositories

On your fresh Linux host (e.g., Ubuntu 22.04 LTS):

### 1. Install Git, GitHub CLI (`gh`), Docker, and VS Code / Antigravity
Ensure Docker (for Dev Containers), `git`, and `gh` are installed on the host, and authenticate `gh` with your **`renanmb`** account:

```bash
gh auth login -h github.com -p https -w
gh auth status
```

### 2. Clone Both Fork Repositories (With Submodules!)
Create your GitHub directory structure matching the devcontainer mounts (`/home/tarfy/Documents/GitHub/renanmb/`):

```bash
mkdir -p ~/Documents/GitHub/renanmb ~/Games/star-citizen
cd ~/Documents/GitHub/renanmb

# 1. Clone lug-wine-experimental WITH submodules (patches & wine-tkg-git)
git clone --recurse-submodules https://github.com/renanmb/lug-wine-experimental.git
cd lug-wine-experimental
git remote add upstream https://github.com/starcitizen-lug/lug-wine-experimental.git

# 2. Clone lug-helper and checkout the GLIBC 2.35 branch
cd ~/Documents/GitHub/renanmb
git clone https://github.com/renanmb/lug-helper.git
cd lug-helper
git remote add upstream https://github.com/starcitizen-lug/lug-helper.git
git checkout feature/glibc-2.35-and-runner-selector
```

> [!IMPORTANT]
> If you ever cloned `lug-wine-experimental` without `--recurse-submodules`, initialize the `patches/` and `wine-tkg-git/` submodules before building:
> ```bash
> git submodule update --init --recursive
> ```

---

## Phase 2: Open the Devcontainer & Verify the Build Environment

1. Open `~/Documents/GitHub/renanmb/lug-wine-experimental` in VS Code / Antigravity and choose **"Reopen in Container"**.
   - Docker will build [`.devcontainer/Dockerfile`](../../../.devcontainer/Dockerfile) (Ubuntu 22.04 Jammy, GCC 11.4, MinGW-w64 8.0, `ntsync.h`, `libpathcch.a` import libs, Meson, and MCP servers) and bind-mount `/lug-helper` and `/home/tarfy/Games`.
2. Inside the devcontainer terminal, authenticate `gh` (persisted in the `gh-config` Docker volume):
   ```bash
   gh auth login -h github.com -p https -w
   ```
3. Run the dependency provisioner check to confirm all 19 build tools and libraries pass:
   ```bash
   .agents/skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh
   ```

---

## Phase 3: Obtain the Runner (Download OR Compile From Source)

You have two choices on a fresh machine:

### Option A (Fastest — ~30 Seconds): Download Pre-Built Runner From Your GitHub Release
If you uploaded your runner to GitHub Releases on `renanmb/lug-wine-experimental`:
```bash
mkdir -p ./output
gh release download 11.21-2 --repo renanmb/lug-wine-experimental --dir ./output
```

### Option B (Full Build — ~10 Minutes on 32 Cores): Compile From Source in One Command
Run [`build-lug-wine.sh`](../../../build-lug-wine.sh):
```bash
./build-lug-wine.sh --preset staging-default --version 11.21 --revision 2
```
What happens automatically:
1. `ensure_vkd3d_proton()` sees `vkd3d-proton/` is not built yet, clones `HansKristian-Work/vkd3d-proton` (`v3.0.1` with submodules), applies the `PATHCCH_NONE -> 0` fix, and compiles `x64` and `x86` `d3d12.dll` and `d3d12core.dll`.
2. `prepare_preset()` copies `wine-tkg-git` to a temporary directory, loads [`config/lug-wine-tkg-staging-default.cfg`](../../../config/lug-wine-tkg-staging-default.cfg), and injects all 22 patches from `patches/wine/` plus any custom patches in [`custom-patches/wine/`](../../../custom-patches/wine/README.md).
3. `build_lug_wine()` compiles Wine 11.21 (WoW64, linked against container `glibc 2.35`).
4. `post_build_add_overrides()` stamps the VKD3D-Proton DLLs with `winebuild --builtin` and installs them into the runner.
5. `package_artifact()` writes `./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz`.

---

## Phase 4: Verify GLIBC 2.35 Compliance & Prefix Readiness

Run the two automated verification scripts against the built/downloaded archive:

```bash
# 1. Verify all 48 ELF binaries require <= GLIBC 2.35
.agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh \
  ./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz 2.35

# 2. Smoke-test WoW64 prefix bootstrap, HideWineExports registry, EAC dummy DLLs, and VKD3D-Proton DLLs
.agents/skills/eac-and-prefix-verifier/scripts/verify_prefix.sh \
  ./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz
```

---

## Phase 5: Deploy & Configure Star Citizen

### 1. Run One-Command Deployment
Execute [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh):
```bash
./deploy-to-lug-helper.sh ./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz
```
This automatically:
- Verifies/generates the `.sha256sum` file,
- Extracts the runner into `/lug-helper/runners/`, `/home/tarfy/Games/star-citizen/runners/`, and `~/.local/share/lutris/runners/wine/`,
- Updates `export wine_path=...` in `/home/tarfy/Games/star-citizen/sc-launch.sh`,
- Restores `tarfy:tarfy` file ownership across all deployed directories.

### 2. Multi-GPU `sc-launch.sh` Configuration (Workstations With Multiple GPUs / iGPU)
On a multi-GPU system (e.g., `NVIDIA RTX PRO 6000` + headless `NVIDIA-G0` + AMD CPU iGPU), ensure `/home/tarfy/Games/star-citizen/sc-launch.sh` includes the NVIDIA Vulkan ICD isolation and device name filters in its `ENVIRONMENT VARIABLES` section:

```bash
# GPU selection: restrict Vulkan ICD to NVIDIA (hides AMD CPU iGPU & llvmpipe)
# and filter DXVK/VKD3D-Proton specifically to the display-connected GPU
for _nv_icd in /usr/share/vulkan/icd.d/nvidia_icd.json /etc/vulkan/icd.d/nvidia_icd.json /usr/share/vulkan/icd.d/nvidia_icd.x86_64.json; do
    if [ -f "$_nv_icd" ]; then
        export VK_DRIVER_FILES="$_nv_icd"
        export VK_ICD_FILENAMES="$_nv_icd"
        break
    fi
done
unset _nv_icd
export DXVK_FILTER_DEVICE_NAME="NVIDIA RTX PRO 6000"
export VKD3D_FILTER_DEVICE_NAME="NVIDIA RTX PRO 6000"
```

### 3. Refresh the Prefix & Launch
On the **host** terminal (as user `tarfy`):
```bash
# Refresh prefix built-in DLLs (d3d12.dll, d3d12core.dll, EAC dummy DLLs)
WINEPREFIX="/home/tarfy/Games/star-citizen" \
  /home/tarfy/Games/star-citizen/runners/lug-wine-tkg-staging-experimental-git-11.21-2/bin/wineboot -u

# Launch Star Citizen via LUG Helper or directly via sc-launch.sh
/home/tarfy/Games/star-citizen/sc-launch.sh
```
