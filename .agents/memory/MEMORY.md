# Agent Session Memory

This document stores persistent context, key decisions, ongoing progress, and notes across sessions.

---

## Repository Context Summary
- **Project**: LUG-Wine-Experimental (`starcitizen-lug`)
- **Host OS**: Ubuntu 22.04.5 LTS (Jammy Jellyfish)
- **Host Kernel**: `7.2.9-zabbly+ #ubuntu22.04 SMP PREEMPT_DYNAMIC` (Custom Zabbly mainline kernel)
- **Host GLIBC**: **2.35** (`Ubuntu GLIBC 2.35-0ubuntu3.14`)
- **Host Toolchain**: GCC 11.4.0
- **Runner Requirement**: Upstream CI builds on Ubuntu 24.04 targeting `glibc >= 2.39`; local native builds link against host `glibc 2.35`.
- **Core Technology**: Wine-TKG (`Frogging-Family/wine-tkg-git`), VKD3D-Proton, Star Citizen community patches (`starcitizen-lug/patches`).
- **Primary Deliverables**: Standalone Wine runners (`lug-wine-tkg-*`) for use with LUG Helper and Lutris.

---

## Session History

### Session 1 — 2026-10-13
- **User Request**: 
  - Analyze repository contents and explain project purpose.
  - Explain what the TKG wine runner is.
  - Establish `.agents/` structure containing `skills/`, `references/`, `memory/`, and `rules/`.
  - Document project overview in `references/README.md`.
  - Establish strict rules (never commit/push without user approval).
- **Actions Taken**:
  - Investigated [`build-lug-wine.sh`](../../build-lug-wine.sh), [`config/`](../../config/lug-wine-tkg-staging-default.cfg), [`patches/`](../../patches/README.md), and `.github/workflows/`.
  - Created `.agents/references/README.md` containing detailed technical documentation of the project and TKG Wine runners.
  - Created `.agents/rules/rules.md` enforcing git protection (no commits/pushes without permission) and build safety rules.
  - Created `.agents/memory/MEMORY.md` to persist cross-session context.
  - Created `.agents/skills/README.md` to outline agent skills.
- **Current State**:
  - Environment and agent directories are initialized. Submodules and build configurations are intact.

### Session 2 — 2026-10-13
- **User Request**:
  - Create a `plans` folder inside `.agents/references`.
  - Formulate a plan to identify all necessary skills and MCP servers required for Wine-TKG runner tasks.
- **Actions Taken**:
  - Created [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](../references/plans/wine_tkg_skills_and_mcp_plan.md) with an analysis of Wine-TKG workloads, 5 essential MCP servers, 5 custom agent skills, and a 4-phase rollout roadmap.
  - Created [`.agents/references/plans/README.md`](../references/plans/README.md) as the plans index.
- **Current State**:
  - All requested directory structures and plan documents are in place. Rules against unauthorized git commit/push remain strictly active.

### Session 3 — 2026-10-13
- **User Query**: Why were there no MCP servers recommended for dealing with C code, build errors, or runtime debugging?
- **Actions Taken**:
  - Recognized that Wine is an immense C/C++ codebase with unique MinGW/PE and Wine `.spec` conventions where C code intelligence and crash diagnosis are paramount.
  - Expanded [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](../references/plans/wine_tkg_skills_and_mcp_plan.md) to add:
    - **Clangd C/C++ Code Intelligence MCP Server** (`clangd-mcp-server`) for semantic AST analysis and header navigation.
    - **GDB/LLDB Debugger MCP Server** (`smadi0x86/MDB-MCP`) for core dump inspection and crash analysis.
    - **Compiler Diagnostics & Build Log Parser MCP** for isolating GCC/MinGW build failures.
    - **Skills**: `c-build-and-patch-debugger` and `wine-crash-trace-analyzer`.

### Session 4 — 2026-10-13
- **User Query**: Confirm custom Ubuntu 22.04 with custom kernel and verify glibc version; add this crucial system info to the plan.
- **Actions Taken**:
  - Ran system diagnostics confirming:
    - **OS**: Ubuntu 22.04.5 LTS (Jammy Jellyfish).
    - **Kernel**: `7.2.9-zabbly+ #ubuntu22.04 SMP PREEMPT_DYNAMIC` (Custom Zabbly mainline kernel).
    - **GLIBC Version**: **2.35** (`Ubuntu GLIBC 2.35-0ubuntu3.14`).
    - **Compiler**: GCC 11.4.0.
  - Identified critical compatibility constraint: Upstream pre-built CI runners require `glibc >= 2.39`, meaning pre-compiled releases cannot run directly on this host without containerization, while local compiles with `build-lug-wine.sh` link against `glibc 2.35`.
  - Updated [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](../references/plans/wine_tkg_skills_and_mcp_plan.md) with Section 1: "Host System Profile & Compatibility Analysis".

### Session 5 — 2026-10-13
- **User Goal**: Obtain all skills and MCPs necessary to aid the agent in creating a version of the software in this repo supporting GLIBC 2.35 on the current system.
- **Actions Taken**:
  - Authored dedicated skills with automation scripts:
    - [`.agents/skills/glibc-compatibility-auditor/`](../skills/glibc-compatibility-auditor/SKILL.md) containing [`audit_glibc.sh`](../skills/glibc-compatibility-auditor/scripts/audit_glibc.sh).
    - [`.agents/skills/ubuntu-2204-build-environment-provisioner/`](../skills/ubuntu-2204-build-environment-provisioner/SKILL.md) containing [`check_deps.sh`](../skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh).
    - [`.agents/skills/vkd3d-proton-glibc235-builder/`](../skills/vkd3d-proton-glibc235-builder/SKILL.md).
    - [`.agents/skills/c-build-and-patch-debugger/`](../skills/c-build-and-patch-debugger/SKILL.md).
  - Authored a dedicated technical plan: [`.agents/references/plans/glibc_235_compatibility_plan.md`](../references/plans/glibc_235_compatibility_plan.md).
  - Executed initial dependency check via `check_deps.sh`, verifying that gcc/g++/flex/bison/make/git are installed, while `mingw-w64` and `ntsync.h` remain to be provisioned before compiling.

### Session 6 — 2026-10-13
- **User Query**: Should we modify the Dockerfile to install the MCPs and skills? What is the best course of action here?
- **Actions Taken**:
  - Defined the architecture division:
    - **Skills** remain in repository version control ([`.agents/skills/`](../skills/README.md)) so they are tracked by git and auto-discovered without container rebuilds.
    - **Toolchains & MCP Runtime** are placed into [`.devcontainer/Dockerfile`](../../.devcontainer/Dockerfile) and [`.devcontainer/devcontainer.json`](../../.devcontainer/devcontainer.json) for 100% build reproducibility.
  - Installed `clangd`, `gdb`, `mingw-w64`, `meson`, `ninja-build`, `ntsync.h`, and built `/opt/clangd-mcp-server`.
  - Configured active MCP servers in `/root/.gemini/config/mcp_config.json` and committed a template to [`.agents/mcp_config.json`](../mcp_config.json).
  - Authored and verified two additional skills:
    - [`.agents/skills/wine-patch-validator/`](../skills/wine-patch-validator/SKILL.md) with [`validate_patches.sh`](../skills/wine-patch-validator/scripts/validate_patches.sh).
    - [`.agents/skills/tkg-config-auditor/`](../skills/tkg-config-auditor/SKILL.md) with [`audit_config.sh`](../skills/tkg-config-auditor/scripts/audit_config.sh).
  - Re-ran `check_deps.sh` and confirmed all host dependencies for Wine-TKG WoW64 build pass.

### Session 7 — 2026-10-13
- **User Request**:
  - Test all skills and MCPs, report what is running, compare to `.agents/references/plans`.
  - Check submodule readiness.
  - In-depth review of `glibc_235_compatibility_plan.md` to ensure zero gaps and complete build viability on GLIBC 2.35, Ubuntu 22.04, and kernel `7.2.9-zabbly+`.
- **Actions Taken**:
  - Validated live operation of all 4 MCP servers (`clangd`, `debugger`, `git`, `filesystem`) and executed tools on each.
  - Validated all 6 workspace skills via test script executions.
  - Confirmed submodules `patches` and `wine-tkg-git` are fully cloned, clean, and checked out to required commits.
  - Uncovered missing configure dependencies: `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev` (required by `--with-gstreamer`) and `glslang-tools` (`glslangValidator`). Installed them and updated `.devcontainer/Dockerfile` and `check_deps.sh`.
  - Expanded `check_deps.sh` to comprehensively audit 19 critical build tools, cross-compilers, and pkg-config packages.
  - Conducted deep review of `glibc_235_compatibility_plan.md`, adding host kernel 7.2.9 analysis (Fsync `futex_waitv` support vs Ntsync device absence), WoW64 multiarch isolation benefits, MinGW 8.0 `PATHCCH_NONE` VKD3D-Proton workaround, and Wine version alignment (11.19).

### Session 8 — 2026-10-13
- **User Request**:
  - Proceed with building VKD3D-Proton first to include DirectX 12 PE DLLs, followed by the Wine runner with preset `staging-default`.
- **Actions Taken**:
  - Cloned and built VKD3D-Proton for both 64-bit and 32-bit architectures:
    - Resolved MinGW 8.0 missing `libpathcch.a` by generating stdcall import libraries via `dlltool` for both x86_64 and i686.
    - Updated Meson to 1.12.1 via pip to support dictionary `default_options` in subprojects.
    - Successfully produced `d3d12.dll` and `d3d12core.dll` for both `x64` and `x86`.
  - Executed `./build-lug-wine.sh --preset staging-default --version 11.19 --revision 1`.
  - Full compilation of Wine 11.19 with Wine-Staging and 21 LUG patches completed in ~10 minutes using all 32 cores.
  - Injected VKD3D-Proton PE DLLs (`d3d12.dll`, `d3d12core.dll`) marked as Wine builtins into the runner.
  - Packaged final release archive: [`output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz`](../../output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz) (149 MB).
  - Executed [`audit_glibc.sh`](../skills/glibc-compatibility-auditor/scripts/audit_glibc.sh): 48 ELF files checked, 0 exceeding GLIBC 2.35 (**100% PASS**).
  - Fixed relative path bug for `--vkd3d-proton-dir` in [`build-lug-wine.sh`](../../build-lug-wine.sh) using `realpath`.

### Session 9 — 2026-10-13
- **User Request**:
  - Proceed with Option 1: Ephemeral prefix smoke testing (`eac-and-prefix-verifier`) to verify runtime prefix initialization and registry keys.
- **Actions Taken**:
  - Authored and refined [`.agents/skills/eac-and-prefix-verifier/`](../skills/eac-and-prefix-verifier/SKILL.md) containing [`verify_prefix.sh`](../skills/eac-and-prefix-verifier/scripts/verify_prefix.sh).
  - Resolved headless prefix bootstrap roadblock:
    - Root cause: Missing `=d` in `WINEDLLOVERRIDES="mscoree,mshtml="` combined with active `DISPLAY=:0` caused Wine to pop up an interactive Mono/Gecko download dialog, timing out after 5 minutes with `boot event wait timed out` (c0000135).
    - Resolution: Set `WINEDLLOVERRIDES="mscoree,mshtml=d"`, `DISPLAY=""`, and `WAYLAND_DISPLAY=""` for automated test execution.
  - Successfully executed `verify_prefix.sh` against [`output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz`](../../output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz):
    - Prefix directories: `system32` and `syswow64` created (WoW64 active).
    - Registry: `user.reg` confirmed containing `[Software\Wine\AppDefaults\starcitizen.exe]` with `"HideWineExports"="Y"`.
    - EAC dummy DLLs: `devobj.dll` and `drvstore.dll` verified in `system32`.
    - VKD3D-Proton integration: `d3d12.dll` and `d3d12core.dll` verified in both `system32` (64-bit) and `syswow64` (32-bit).
    - Runtime execution: Both 32-bit `wine` and 64-bit `wine64` executed `cmd /c` successfully.
    - Test execution finished cleanly in < 8 seconds (**100% PASS**).

### Session 10 — 2026-10-13
- **User Request**:
  - Proceed to generate the release.
  - Deploy into `lug-helper` located at `/home/tarfy/Documents/GitHub/renanmb/lug-helper`.
  - Read that repository and make sure the runner can run there.
- **Actions Taken**:
  - **Release Artifacts Generated**:
    - Computed and saved [`output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz.sha256sum`](../../output/lug-wine-tkg-staging-experimental-git-11.19-1.tar.gz.sha256sum).
    - Authored [`output/RELEASE_NOTES.md`](../../output/RELEASE_NOTES.md) documenting release metadata, GLIBC 2.35 verification, and bundled components.
  - **LUG Helper Analysis & Deployment**:
    - Inspected `/home/tarfy/Documents/GitHub/renanmb/lug-helper`:
      - Discovered commit `1fc05b0` ("need to update the glibc, cooking new lug") where Renan encountered GLIBC 2.39 incompatibility on host Ubuntu 22.04 with upstream runners.
      - Discovered `lug-helper.sh` hardcoded `required_glibc="2.39"` for `LUG Experimental`.
    - Patched `lug-helper.sh` and `lug-helper-v4.16/lug-helper.sh` in `renanmb/lug-helper` to recognize `required_glibc="2.35"` for `LUG Experimental`.
    - Deployed runner `lug-wine-tkg-staging-experimental-git-11.19-1` to:
      1. `/home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/`
      2. `/home/tarfy/Games/star-citizen/runners/`
      3. `/home/tarfy/.local/share/lutris/runners/wine/`
    - Configured Star Citizen launch script `/home/tarfy/Games/star-citizen/sc-launch.sh` with `export wine_path="..."`.
    - Created [`deploy-to-lug-helper.sh`](../../deploy-to-lug-helper.sh) for one-command automated deployment across host/container environments.
    - Verified execution as user `tarfy`:
      - `lug-helper.sh --version`, `--show-directories`, and `--about` ran cleanly.
      - Executed `sc-launch.sh shell` and ran Wine commands inside the launch shell with zero GLIBC errors.
    - Created [`.agents/references/notes/`](../references/notes/README.md) and documented deployment and execution procedures in [`lug_helper_runner_deployment_and_execution.md`](../references/notes/lug_helper_runner_deployment_and_execution.md).


### Session 11 — 2026-11-08
- **User Request**:
  - Review repository and validate changes needed for Star Citizen.
  - Preserve previous Wine 11.19 `main` state in a reference branch (`wine-11.19-glibc-2.35`).
  - Sync `main` with upstream (`11.20` / `11.21`), update `patches` and `wine-tkg-git` submodules, rebuild `vkd3d-proton` (`v3.0.1`) and `staging-default` Wine runner for GLIBC 2.35, validate, and deploy via `deploy-to-lug-helper.sh`.
- **Actions Taken**:
  - Created reference branch `wine-11.19-glibc-2.35` at commit `a8a27e8`.
  - Merged `upstream/main` (`1109b79`) into `main` (without committing per git rules) and updated submodules:
    - `patches` -> `92a8eaf` (updated `sc_gpumem.patch`, `0002-wineopenxr_enable.patch`, added `winewayland-disable-ime.patch`).
    - `wine-tkg-git` -> `65d846c8` (Proton & LAA patches rebased against Wine 11.21).
  - Provisioned `mingw-w64-tools`, upgraded `meson` to 1.12.1, and generated `libpathcch.a` import libs; persisted these in `.devcontainer/Dockerfile` and `check_deps.sh`.
  - Built `vkd3d-proton` `v3.0.1` for 64-bit (`x64`) and 32-bit (`x86`).
  - Built `lug-wine-tkg-staging-experimental-git-11.21-1.tar.gz` (`staging-default`, Wine 11.21, WoW64, GLIBC 2.35).
  - Validated `11.21-1`:
    - `audit_glibc.sh`: 48 ELF binaries checked, 0 symbols > GLIBC 2.35 (**100% PASS**).
    - `verify_prefix.sh`: WoW64 `system32`/`syswow64`, `HideWineExports`, EAC dummy DLLs (`devobj.dll`, `drvstore.dll`), VKD3D-Proton DLLs, and `wine`/`wine64` execution (**100% PASS**).
  - Deployed `lug-wine-tkg-staging-experimental-git-11.21-1` via `deploy-to-lug-helper.sh` to `/lug-helper/runners/`, `/home/tarfy/Games/star-citizen/runners/`, and updated `wine_path` in `/home/tarfy/Games/star-citizen/sc-launch.sh`.


### Session 12 — 2026-11-13
- **User Request**:
  - Star Citizen updated (`4.10.3-live.13165946`) and the previous `11.21-1` build no longer worked (`Fatal Error Thrown: Required Vulkan API Version not available` / `[VK] No valid Discrete GPU found`). Rebuild a new runner and update LUG Helper integration.
- **Actions Taken**:
  - Diagnosed root causes from `Game.log`, `sc-launch.log`, upstream `lug-wine-experimental`, and `/lug-helper`:
    1. Upstream `starcitizen-lug/lug-wine-experimental` pushed `05de375` (`add d3dkmt-sync-getfd for vkd3d-proton vulkan display path`, `patches` `e5e2dd9`) after our Nov 8 `11.21-1` build. Without `d3dkmt_sync_get_fd` in `server/d3dkmt.c`, Star Citizen's Vulkan renderer (`GraphicsRenderer: 1`) failed VKD3D-Proton display path sync FD export.
    2. Multi-GPU host (`NVIDIA RTX PRO 6000 Blackwell`, headless `NVIDIA-G0`, `AMD RADV RAPHAEL_MENDOCINO`, `llvmpipe`) needed `VK_DRIVER_FILES` restricted to NVIDIA's ICD plus `DXVK_FILTER_DEVICE_NAME="NVIDIA RTX PRO 6000"` and `VKD3D_FILTER_DEVICE_NAME="NVIDIA RTX PRO 6000"` in `sc-launch.sh`.
    3. Upstream `starcitizen-lug/lug-helper` released `v4.18` (`dfea2c9`, excluding Wayland builds from default runner search).
  - Synced `patches` submodule to `e5e2dd9` and added `"d3dkmt-sync-getfd"` to `build-lug-wine.sh`.
  - Cleanly rebuilt `vkd3d-proton` `v3.0.1` (`x64` and `x86` `d3d12.dll` and `d3d12core.dll`).
  - Built `lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz` (`staging-default`, Wine 11.21, 22 LUG patches, WoW64, GLIBC 2.35).
  - Validated `11.21-2`:
    - `verify_prefix.sh`: WoW64, `HideWineExports`, EAC dummy DLLs, VKD3D-Proton DLLs, 32/64-bit `cmd.exe` (**100% PASS**).
    - `audit_glibc.sh`: 48 ELF files checked, 0 symbols > GLIBC 2.35 (**100% PASS**).
  - Merged upstream `lug-helper` `v4.18` (`dfea2c9`) into `/lug-helper` without committing (per git rules), hardened `deploy-to-lug-helper.sh` for container-to-host `/home/tarfy` paths and `tarfy:tarfy` ownership, deployed `11.21-2`, refreshed the live prefix via `wineboot -u`, and updated `sc-launch.sh` GPU filters.


### Session 13 — 2026-11-17
- **User Request**:
  - Review the latest Star Citizen crash extensively (apparent DirectX 11 / Vulkan crash) and prepare/build a new runner.
- **Actions Taken**:
  - Conducted forensic analysis of `LIVE/Game.log`, `sc-launch.log`, `crashes/cvar.dump`, all six `4.10.3` (`13165946`) `logbackups/` sessions, and disassembled `StarCitizen.exe` + `winevulkan.so`, uncovering two interacting root causes:
    1. **Alternating-Launch Settings Ping-Pong (`sc-alpha-4.10.0`)**: Star Citizen `4.10.3` switched its AppData folder to `starcitizen_(sc-alpha-4.10.0)_ot8f6_0` and changed its default renderer to `1 = Vulkan (Default)`. When `GraphicsSettings.json` lacked `"SettingsVersion": 1`, SC used `r.GraphicsRenderer = 0` from `LIVE/user.cfg` (running DXVK `v3.1.1` stably for 4 hours / 619,313 frames) while writing `"SettingsVersion": 1, "GraphicsRenderer": 1` for the next launch; the next launch then forced Vulkan, failed GPU validation, wrote a malformed 61-byte `GraphicsSettings.json`, and crashed with `0x2BADF00D`.
    2. **Upstream Wine `winevulkan` Uninitialized Memory Bug**: In `StarCitizen.exe` (`CGPUPhysicalDeviceVulkan::GetPhysicalDeviceInfos` at `0x140973570`), SC chains a zeroed `VkPhysicalDeviceLayeredDriverPropertiesMSFT` (`sType = 1000530000`) struct to `vkGetPhysicalDeviceProperties2` and rejects any GPU where `underlyingAPI != 0`. In Wine 11.21/11.22 (`dlls/winevulkan/vulkan_private.h`), `conversion_context_alloc()` returned uninitialized stack/heap bytes for `returnedonly="true"` `pNext` structs; when Linux NVIDIA `595.99.2` ignored the unsupported Windows-only `VK_MSFT_layered_driver` struct, `winevulkan` copied stack garbage back into `underlyingAPI`, disqualifying `NVIDIA RTX PRO 6000 Blackwell` (`[VK] No valid Discrete GPU found`).
  - Authored [`custom-patches/wine/winevulkan-zero-conversion-context.patch`](../../custom-patches/wine/winevulkan-zero-conversion-context.patch) to zero-initialize `conversion_context_alloc()` (`memset` + `calloc`) and verified clean application and machine-code output (`mov QWORD PTR [rax+0x10], 0x0`).
  - Repaired `starcitizen_(sc-alpha-4.10.0)_ot8f6_0/GraphicsSettings/GraphicsSettings.json` with valid `"SettingsVersion": 1, "GraphicsRenderer": 0` (`1000:1000`).
  - Synced submodules to upstream `11.22-1` (`patches` -> `9e68ebb`, `wine-tkg-git` -> `27eb0894`), compiled `lug-wine-tkg-staging-experimental-git-11.22-1.tar.gz` (Wine 11.22 Staging, WoW64, GLIBC 2.35, 22 LUG patches + `winevulkan-zero-conversion-context.patch` + VKD3D-Proton `v3.0.1`).
  - Hardened [`audit_glibc.sh`](../skills/glibc-compatibility-auditor/scripts/audit_glibc.sh) to inspect `.tar.gz` archives directly (42 ELF files checked, 0 > GLIBC 2.35) and [`deploy-to-lug-helper.sh`](../../deploy-to-lug-helper.sh) for portable `.sha256sum` basenames and container numeric UID/GID (`1000:1000`) ownership.
  - Verified `11.22-1` via `audit_glibc.sh` (**100% PASS**) and `verify_prefix.sh` (**100% PASS**), deployed across `/lug-helper/runners/`, `/home/tarfy/Games/star-citizen/runners/`, Lutris, and `sc-launch.sh`, and refreshed `/home/tarfy/Games/star-citizen` via `wineboot -u` as UID `1000`.
