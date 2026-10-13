---
name: vkd3d-proton-glibc235-builder
description: Builds and packages VKD3D-Proton on Ubuntu 22.04 (GLIBC 2.35) for integration into LUG Wine runners.
---

# Skill: VKD3D-Proton GLIBC 2.35 Builder

## Purpose
Builds VKD3D-Proton PE binaries on Ubuntu 22.04 so they can be injected into the Wine runner output directory via `build-lug-wine.sh`.

## Prerequisites
- `meson`
- `ninja-build`
- `glslang-tools`
- `mingw-w64`

## Workflow
1. Check that build prerequisites exist:
   ```bash
   command -v meson ninja x86_64-w64-mingw32-gcc glslangValidator
   ```
2. Clone VKD3D-Proton repository:
   ```bash
   git clone --depth 1 --recursive https://github.com/HansKristian-Work/vkd3d-proton.git
   cd vkd3d-proton
   ```
3. Apply compatibility fixes:
   ```bash
   sed -i 's/PATHCCH_NONE/0/g' libs/vkd3d-common/platform.c
   ```
4. Run cross-compilation:
   ```bash
   ./package-release.sh master build --no-package
   ```
5. Verify output files (`build/vkd3d-proton-master/x64/d3d12.dll` and `x86/d3d12.dll`).
6. Point `build-lug-wine.sh` to this directory using `-d /path/to/vkd3d-proton/build/vkd3d-proton-master`.
