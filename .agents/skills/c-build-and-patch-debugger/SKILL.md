---
name: c-build-and-patch-debugger
description: Diagnoses and resolves C/C++ compilation errors, GCC 11 compatibility issues, and Wine patch conflicts.
---

# Skill: C Build and Patch Debugger

## Purpose
Triages and fixes C language errors, preprocessor conflicts, and compiler incompatibilities when compiling Wine-TKG with GCC 11 on Ubuntu 22.04 with GLIBC 2.35.

## Common Ubuntu 22.04 / GCC 11 Specific Issues
1. **Implicit Function Declarations**:
   - GCC 11 is slightly more forgiving than GCC 14, but strict flags like `-Werror=implicit-function-declaration` may fail if modern C library headers omit functions.
   - Config files in `config/lug-wine-tkg-*.cfg` already include:
     `_GCC_FLAGS="-O2 -ftree-vectorize -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"`
2. **Missing Kernel UAPI Headers**:
   - `ntsync.h`: Present in Linux 6.13+/custom kernels, but older Ubuntu 22.04 headers in `/usr/include/linux` lack it.
   - Solution: Use the upstream UAPI header in `/usr/local/include/linux/ntsync.h`.
3. **Wine DLL `.spec` and PE Export Mismatches**:
   - If a patch adds or alters an exported function, the corresponding `.spec` file in the Wine module must match the signature.

## Workflow
1. When a build error occurs in `./non-makepkg-builds/` or compilation logs:
   - Identify the source file and line from compiler output (`error:` lines).
   - Check if the failure originated from a community patch in `patches/wine/`.
2. Inspect header inclusions and data structures using Clangd or grep.
3. Test a minimal patch edit in `patches/wine/<patch-name>.patch`.
4. Re-run patch check:
   ```bash
   git apply --check --verbose "patches/wine/<patch-name>.patch"
   ```
