# Repository Structure, Core Directories, and Submodule Management

This document explains the directory layout of `lug-wine-experimental`, the roles of `patches/`, `vkd3d-proton/`, and `wine-tkg-git/`, how the end-to-end build and deployment pipeline works, and how Git submodules and external repositories are tracked.

---

## 1. Repository Overview & Fork Purpose

- **Upstream Repository:** `https://github.com/starcitizen-lug/lug-wine-experimental.git` (`upstream` remote)
- **Fork Repository:** `https://github.com/renanmb/lug-wine-experimental.git` (`origin` remote)
- **Why this Fork Exists:**
  - Upstream builds runners inside Ubuntu 24.04 containers ([`.github/workflows/build-artifacts.yml`](../../../.github/workflows/build-artifacts.yml)), which links binaries against **`glibc >= 2.39`**.
  - This fork adds an **Ubuntu 22.04 LTS (`glibc 2.35`)** build environment ([`.devcontainer/Dockerfile`](../../../.devcontainer/Dockerfile)) and local deployment automation ([`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh)) so runners run natively on Ubuntu 22.04 hosts and deploy directly into `lug-helper`, Lutris, and the Star Citizen Wine prefix.

### Directory Layout

```text
lug-wine-experimental/
├── build-lug-wine.sh          # Main orchestrator: ensures vkd3d-proton, stages wine-tkg, injects patches, packages tarball
├── deploy-to-lug-helper.sh    # Deploys built runner tarball into lug-helper, SC prefix, Lutris, and sc-launch.sh
├── config/                    # 4 Wine-TKG preset configs (default, staging-default, wayland, staging-wayland)
├── custom-patches/            # [Git-tracked] Custom fork patches (wine/*.patch) that add to or override patches/wine/
├── patches/                   # [Git submodule] starcitizen-lug/patches — Upstream Star Citizen & Wine patches
├── wine-tkg-git/              # [Git submodule] Frogging-Family/wine-tkg-git — Upstream Wine-TKG build framework
├── vkd3d-proton/              # [Git-ignored clone] HansKristian-Work/vkd3d-proton (v3.0.1) — Auto-cloned & built by build-lug-wine.sh
├── output/                    # [Git-ignored] Built runner .tar.gz archives, .sha256sum, and RELEASE_NOTES.md
├── .github/workflows/         # Upstream CI workflows (build-vkd3d-proton.yml, build-artifacts.yml, release-artifacts.yml)
├── .devcontainer/             # Ubuntu 22.04 (GLIBC 2.35) build container & multilib/MinGW toolchain setup
└── .agents/                   # Agent rules, skills, memory, plans, docs, and reference notes
```

---

## 2. Deep Dive: `patches/`, `vkd3d-proton/`, and `wine-tkg-git/`

### A. `patches/` — LUG Community Patch Repository
- **Tracking:** Git submodule pointing to `https://github.com/starcitizen-lug/patches` ([`.gitmodules`](../../../.gitmodules#L1-L3), pinned at commit `e5e2dd9`).
- **Contents:**
  - [`patches/wine/`](../../../patches/README.md): 38 `.patch` files targeting Wine / Wine-Staging.
  - Other subdirectories (`mesa/`, `proton/`, `vkd3d-proton/`, `xorg/`): Reference community patches for other Linux stack components (not automatically applied by `build-lug-wine.sh`).
- **How `build-lug-wine.sh` Uses It (Together with [`custom-patches/wine/`](../../../custom-patches/wine/README.md)):**
  - [`build-lug-wine.sh`](../../../build-lug-wine.sh#L24-L46) defines an array of **22 active Wine patches** (plus `default-to-wayland` when building `wayland` or `staging-wayland` presets).
  - During `prepare_preset()`, for each patch in that array, `build-lug-wine.sh` checks [`custom-patches/wine/<name>.patch`](../../../custom-patches/wine/README.md) **first** (allowing clean overrides of upstream patches) before falling back to `patches/wine/<name>.patch`.
  - Next, any additional `*.patch` files in `custom-patches/wine/` are automatically copied into `./wine-tkg-userpatches/<name>.mypatch` ([lines 136–157](../../../build-lug-wine.sh#L136-L157)) so Wine-TKG applies them alongside the upstream patches.
- **Active Patch Categories (see [`patches/README.md`](../../../patches/README.md)):**
  1. **Easy Anti-Cheat (EAC) Compatibility:**
     - `10.2+_eac_fix.patch`: Provides separate 32-bit and 64-bit Wine loaders required by EAC on New-WoW64 builds.
     - `disable_syscall_dispatch.patch`: Avoids EAC failures on Wine 11.5+ caused by `syscall_dispatch`.
     - `eac_locale.patch`: Forces `en-US` locale specifically for EAC to avoid missing-font errors.
     - `eac_60101_timeout.patch`: Prevents EAC error `60101` when waiting on `eac_wine_pid`.
  2. **Star Citizen Performance, Vulkan & Crash Fixes:**
     - `d3dkmt-sync-getfd.patch`: Adds `d3dkmt_sync_get_fd` to `server/d3dkmt.c` (`d3dkmt_sync_ops`), required by Star Citizen 4.10.3's Vulkan display/presentation path.
     - `cache-committed-size.patch`: Caches committed memory lookups (queried thousands of times per second by Star Citizen).
     - `sc_gpumem.patch`: Implements `NtGdiDdDDIQueryStatistics` GPU memory reporting expected by Star Citizen.
     - `silence-sc-unsupported-os.patch`: Automatically dismisses the blocking "Unsupported OS" popup.
  3. **VKD3D-Proton / DirectX 12 Presentation:**
     - `hidewineexports.patch` & `reg_hide_wine.patch`: Fixes and enables Wine's `HideWineExports` registry setting so Star Citizen uses VKD3D-Proton for DX12 presentation (preventing Vulkan initialization failures on NVIDIA).
  4. **NVIDIA DLSS (`ngx`) & VR (`OpenXR`):**
     - `dummy_dlls.patch`, `enables_dxvk-nvapi.patch`, `nvngx_dlls.patch`: Generates dummy DLLs (`cryptbase.dll`, `devobj.dll`, `drvstore.dll`), enables `dxvk-nvapi` by default, and automates `nvngx` DLL setup for DLSS.
     - `0001-wineopenxr_add.patch` & `0002-wineopenxr_enable.patch`: Backports and enables Valve Proton's `wineopenxr`.
  5. **Wayland & RSI Launcher Fixes:**
     - `append_cmd.patch`: Appends `--in-process-gpu --disable-gpu --no-deprecation` to the RSI Launcher (CEF/Electron) under `winewayland`.
     - `systray-title.patch`, `winewayland-prefer-relative-pointer.patch`, `winewayland-guess-primary-output.patch`, `winewayland-fullscreen-idle-inhibit.patch`, `winewayland-systray.patch`, `winewayland-disable-ime.patch`.

---

### B. `vkd3d-proton/` — DirectX 12 to Vulkan Translation Layer
- **Tracking:** **Git-ignored** local clone ([`.gitignore`](../../../.gitignore#L10-L11)) of `https://github.com/HansKristian-Work/vkd3d-proton.git` checked out at tag **`v3.0.1`** (`3b10bd7a`), with its own 3 nested submodules (`subprojects/dxil-spirv`, `khronos/Vulkan-Headers`, `khronos/SPIRV-Headers`).
- **Why It Is Needed:** Star Citizen (when `HideWineExports` triggers DX12 presentation) relies on VKD3D-Proton's `d3d12.dll` and `d3d12core.dll` instead of upstream Wine's built-in `vkd3d`.
- **Contents:**
  - Full `vkd3d-proton` `v3.0.1` source tree and Meson cross-build files (`build-win64.txt`, `build-win32.txt`, `package-release.sh`).
  - Compiled Windows PE DLLs in `vkd3d-proton/build/vkd3d-proton-master/`:
    - `x64/d3d12.dll` & `x64/d3d12core.dll` (64-bit)
    - `x86/d3d12.dll` & `x86/d3d12core.dll` (32-bit)
- **How `build-lug-wine.sh` Uses It:**
  - `ensure_vkd3d_proton()` ([`build-lug-wine.sh` lines 59–79](../../../build-lug-wine.sh#L59-L79)) verifies whether `vkd3d-proton/build/vkd3d-proton-master/{x64,x86}/d3d12.dll` exist. On a fresh clone where `vkd3d-proton/` is not yet present, it automatically clones `HansKristian-Work/vkd3d-proton` (`v3.0.1` with `--recursive`), applies the MinGW 8.0 `PATHCCH_NONE -> 0` fix in `libs/vkd3d-common/platform.c`, and runs `./package-release.sh master build --no-package`.
  - After Wine finishes compiling, `override_to_vkd3d_proton()` ([`build-lug-wine.sh` lines 81–103](../../../build-lug-wine.sh#L81-L103)) runs the newly compiled `winebuild <dll> --builtin` on each DLL in `x64/` and `x86/` and copies them into `lib/wine/x86_64-windows/` and `lib/wine/i386-windows/` inside the runner tree.

---

### C. `wine-tkg-git/` — Frogging-Family Wine-TKG Build System
- **Tracking:** Git submodule pointing to `https://github.com/Frogging-Family/wine-tkg-git` ([`.gitmodules`](../../../.gitmodules#L4-L6), pinned at commit `65d846c8` for Wine 11.21).
- **Contents:**
  - [`wine-tkg-git/wine-tkg-git/`](../../../wine-tkg-git/README.md): Portable Linux Wine build scripts (`non-makepkg-build.sh`, `wine-tkg-scripts/`, protonification/hotfix patchsets, Fsync/Esync/Ntsync patches).
  - [`wine-tkg-git/proton-tkg/`](../../../wine-tkg-git/README.md): Proton-TKG scripts (not used by `build-lug-wine.sh`).
- **How `build-lug-wine.sh` Uses It:**
  - Kept clean as a read-only template.
  - `prepare_preset()` copies `wine-tkg-git/wine-tkg-git` into an ephemeral directory `wine-tkg-build-tmp-XXXXXX/` ([line 102](../../../build-lug-wine.sh#L102)), copies the selected preset from [`config/`](../../../config/lug-wine-tkg-staging-default.cfg), pins `_staging_version` / `_plain_version` if `-v <version>` is provided, and invokes `./non-makepkg-build.sh --config ...` ([line 123](../../../build-lug-wine.sh#L123)).
  - An `EXIT` trap removes `wine-tkg-build-tmp-XXXXXX/` automatically after packaging ([lines 45–49](../../../build-lug-wine.sh#L45-L49)).

---

## 3. Submodule Architecture & How Git Tracks Them

### How Git Submodules Work in This Repository

Git **does not store the source files** of `patches/` or `wine-tkg-git/` directly inside `renanmb/lug-wine-experimental`. Instead, Git stores two pieces of metadata:

1. **[`.gitmodules`](../../../.gitmodules):** Maps each submodule path to its upstream repository URL:
   - `patches` $\rightarrow$ `https://github.com/starcitizen-lug/patches`
   - `wine-tkg-git` $\rightarrow$ `https://github.com/Frogging-Family/wine-tkg-git`
2. **Gitlink Entries (`mode 160000`) in the Parent Commit Tree:** Stores the exact **40-character commit SHA** that each submodule directory is pinned to:
   - `patches` $\rightarrow$ `e5e2dd96c5be30e2f066f49fc07a1a39b5f13a71` (on `starcitizen-lug/patches` `origin/main`)
   - `wine-tkg-git` $\rightarrow$ `65d846c85c986be4b1353b6df9baeebe2153f633` (on `Frogging-Family/wine-tkg-git` `origin/master`)

### Summary of External / Sub-Repository Tracking

| Directory | Git Tracking Method | Upstream URL | Current Pinned Ref | Stored in `renanmb/lug-wine-experimental`? |
| :--- | :--- | :--- | :--- | :--- |
| [`custom-patches/wine/`](../../../custom-patches/wine/README.md) | **Direct Git Directory** | `https://github.com/renanmb/lug-wine-experimental` | `HEAD` (`main`) | **Yes — 100% of files tracked directly in this repo** |
| [`patches/`](../../../patches/README.md) | **Git Submodule** (`160000` gitlink) | `https://github.com/starcitizen-lug/patches` | `e5e2dd9` (`origin/main`) | **Pointer only** (files fetched from upstream via `git submodule update --init`) |
| [`wine-tkg-git/`](../../../wine-tkg-git/README.md) | **Git Submodule** (`160000` gitlink) | `https://github.com/Frogging-Family/wine-tkg-git` | `65d846c8` (`origin/master`) | **Pointer only** (files fetched from upstream via `git submodule update --init`) |
| [`vkd3d-proton/`](../../../vkd3d-proton/README.md) | **Git-ignored directory** ([`.gitignore`](../../../.gitignore#L10-L11)) | `https://github.com/HansKristian-Work/vkd3d-proton.git` | Tag `v3.0.1` (`3b10bd7a`) | **Not tracked in Git** (auto-cloned & compiled by `ensure_vkd3d_proton()` in [`build-lug-wine.sh`](../../../build-lug-wine.sh#L59-L79)) |

### Operational Rules for Submodules

1. **Unmodified Upstream Commits (Current State):**
   - Both `patches` (`e5e2dd9`) and `wine-tkg-git` (`65d846c8`) currently point to public commits that exist on their respective upstream repositories (`starcitizen-lug/patches` and `Frogging-Family/wine-tkg-git`), with **zero uncommitted local modifications**.
   - Anyone (or any GitHub Actions workflow using `submodules: true`) cloning `renanmb/lug-wine-experimental` with `git clone --recurse-submodules` will fetch the exact same `patches/` and `wine-tkg-git/` trees automatically.
2. **Updating a Submodule to a Newer Upstream Commit:**
   - Fetch and checkout the new upstream commit inside `patches/` or `wine-tkg-git/`, then stage the updated gitlink pointer in the parent repository (`git add patches wine-tkg-git`).
3. **If You Ever Modify Files Inside `patches/` or `wine-tkg-git/`:**
   - Because `.gitmodules` points to `starcitizen-lug/patches` and `Frogging-Family/wine-tkg-git` (which you do not push to directly), **committing inside a submodule locally and pushing only the parent repo will break clones** (the commit SHA wouldn't exist on the upstream remote).
   - If custom changes are ever needed inside `patches/` or `wine-tkg-git/`, either:
     - Keep custom patches in the parent repo (or fork the submodule under `renanmb/*` and update `.gitmodules`), **or**
     - Only advance submodule pointers to commits that already exist upstream.
