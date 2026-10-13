# Project Reference: LUG-Wine-Experimental

## Overview

**LUG-Wine-Experimental** is a specialized build environment and repository maintained by the **Star Citizen LUG (Linux Users Group)** community (`starcitizen-lug`). Its mission is to produce custom, optimized, and experimental **Wine runners** specifically engineered to run **Star Citizen** on Linux with maximum compatibility, performance, and stability.

The runners are distributed primarily through the community's [**LUG Helper**](https://github.com/starcitizen-lug/lug-helper) tool and GitHub Releases, targeted at compatibility managers such as **Lutris**.

---

## What is a "TKG Wine Runner"?

### 1. `wine-tkg`
- **Origin**: Created by **Tk-Glitch** (Étienne Sallaberry) under the **[Frogging-Family](https://github.com/Frogging-Family/wine-tkg-git)** project.
- **Role**: `wine-tkg-git` is a modular, highly customizable build-system for compiling Wine (and Proton) from source. Rather than using fixed distributions, it allows fine-grained customization of:
  - Synchronization primitives (Fsync, Esync, Ntsync).
  - Staging patchsets and Valve Proton backports.
  - Compiler toolchains (GCC / MinGW / Clang) and optimization flags (`-O2`, `-O3`, `-march=native`).
  - Automated injection of custom user patches (`wine-tkg-userpatches/`).

### 2. Wine "Runners"
- In Linux gaming frontends like **Lutris**, **Heroic Games Launcher**, and **Bottles**, a **runner** is the specific runtime execution backend used to execute Windows applications in isolated prefixes.
- Rather than relying on the operating system's system-wide Wine (`/usr/bin/wine`), game managers store standalone Wine directory structures (with their own `bin/`, `lib/`, `lib64/`, etc.) in directories like `~/.local/share/lutris/runners/wine/`.

### 3. TKG Wine Runner in this Project
A **TKG Wine Runner** in this project refers to a standalone, portable Wine build compiled using `wine-tkg-git` as the core build engine, customized with Star Citizen specific presets and community patches, and packaged into ready-to-extract tarballs (`lug-wine-*.tar.gz`).

---

## Project Structure & Architecture

```
lug-wine-experimental/
├── build-lug-wine.sh              # Core build orchestration script
├── config/                        # Wine-TKG configuration files for presets
│   ├── lug-wine-tkg-default.cfg
│   ├── lug-wine-tkg-staging-default.cfg
│   ├── lug-wine-tkg-staging-wayland.cfg
│   └── lug-wine-tkg-wayland.cfg
├── patches/                       # Git submodule: starcitizen-lug/patches
│   └── wine/                      # Custom Wine patches for Star Citizen
├── wine-tkg-git/                  # Git submodule: Frogging-Family/wine-tkg-git
├── .github/workflows/             # CI workflows for containerized builds
│   ├── build-artifacts.yml
│   ├── build-vkd3d-proton.yml
│   └── release-artifacts.yml
└── README.md                      # Quick overview & runner list
```

---

## Key Modules & Components

### 1. Build Orchestration (`build-lug-wine.sh`)
- Manages the lifecycle of a build from source configuration to packaged tarball:
  1. **Preset Preparation (`prepare_preset`)**: Selects the appropriate config (`default`, `staging-default`, `staging-wayland`, `wayland`), copies the `wine-tkg-git` source into a temporary isolated build directory, and loads community patches into `wine-tkg-userpatches/`.
  2. **Compilation (`build_lug_wine`)**: Executes `wine-tkg`'s `non-makepkg-build.sh` using the preset configuration.
  3. **VKD3D-Proton Override (`override_to_vkd3d_proton`)**: Builds and injects pre-compiled VKD3D-Proton libraries directly into the built Wine tree (`lib/wine/x86_64-windows/` and `lib/wine/i386-windows/`).
  4. **Packaging (`package_artifact`)**: Gathers the built directory, renames it to the standardized LUG naming convention (`lug-wine-<version>-<rev>`), and compresses it into `/tmp/lug-wine-tkg/lug-wine-*.tar.gz` (moved to `output/`).

### 2. Community Patches (`patches/wine/`)
These patches address specific quirks, bottlenecks, and anti-cheat requirements of Star Citizen:

- **Easy Anti-Cheat (EAC) Compatibility**:
  - `10.2+_eac_fix.patch`: Ensures separate 32-bit and 64-bit loaders exist for EAC.
  - `eac_locale.patch`: Overrides locale to `en-US` specifically for EAC to prevent missing font crashes in non-English locales.
  - `disable_syscall_dispatch.patch`: Workaround for Wine 11.5+ syscall dispatch incompatibility with EAC.
  - `eac_60101_timeout.patch`: Prevents EAC error 60101 by preventing timeouts while waiting for `eac_wine_pid`.

- **Performance & Game Fixes**:
  - `cache-committed-size.patch`: Star Citizen queries memory committed size thousands of times per second. Caching this avoids high CPU latency.
  - `sc_gpumem.patch`: Emulates `NtGdiDdDDIQueryStatistics` memory queries expected by Star Citizen.
  - `silence-sc-unsupported-os.patch`: Suppresses the "Unsupported Operating System" blocking dialog.
  - `unopenable-device-is-bad.patch`: Fixes RSI launcher issues when accessing game installations outside `C:`.

- **Wayland Enhancements**:
  - `winewayland-prefer-relative-pointer.patch`: Smooths cursor/interaction mode in Wayland.
  - `winewayland-guess-primary-output.patch`: Ensures the game launches on the primary display.
  - `winewayland-fullscreen-idle-inhibit.patch`: Prevents screen sleep when using joysticks/HOTAS/controllers.
  - `systray-title.patch` & `winewayland-systray.patch`: Fixes system tray identification.

- **Graphics & Upscaling**:
  - `dummy_dlls.patch` & `nvngx_dlls.patch`: Dummy libraries (`cryptbase.dll`, `devobj.dll`, `drvstore.dll`) required by Nvidia NGX to initialize DLSS.
  - `enables_dxvk-nvapi.patch`: Automatically enables DXVK-NVAPI.
  - `hidewineexports.patch` & `reg_hide_wine.patch`: Fixes and enables Wine's `HideWineExports` to trigger DirectX 12 presentation via VKD3D-Proton.

- **VR Support**:
  - `0001-wineopenxr_add.patch` & `0002-wineopenxr_enable.patch`: Backports WineOpenXR support from Valve Proton.

---

## Runner Variants

| Runner Name | Description |
| --- | --- |
| `lug-wine-tkg-experimental-git` | Standard Wine built with LUG patches for compatibility. |
| `lug-wine-tkg-staging-experimental-git` | Wine with Wine-Staging patchset plus LUG patches. |
| `lug-wine-tkg-staging-experimental-wayland-git` | Wine-Staging with forced native Wine Wayland driver enabled. |
