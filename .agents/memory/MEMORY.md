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
  - Investigated [`build-lug-wine.sh`](file:///workspaces/lug-wine-experimental/build-lug-wine.sh), [`config/`](file:///workspaces/lug-wine-experimental/config), [`patches/`](file:///workspaces/lug-wine-experimental/patches), and `.github/workflows/`.
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
  - Created [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](file:///workspaces/lug-wine-experimental/.agents/references/plans/wine_tkg_skills_and_mcp_plan.md) with an analysis of Wine-TKG workloads, 5 essential MCP servers, 5 custom agent skills, and a 4-phase rollout roadmap.
  - Created [`.agents/references/plans/README.md`](file:///workspaces/lug-wine-experimental/.agents/references/plans/README.md) as the plans index.
- **Current State**:
  - All requested directory structures and plan documents are in place. Rules against unauthorized git commit/push remain strictly active.

### Session 3 — 2026-10-13
- **User Query**: Why were there no MCP servers recommended for dealing with C code, build errors, or runtime debugging?
- **Actions Taken**:
  - Recognized that Wine is an immense C/C++ codebase with unique MinGW/PE and Wine `.spec` conventions where C code intelligence and crash diagnosis are paramount.
  - Expanded [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](file:///workspaces/lug-wine-experimental/.agents/references/plans/wine_tkg_skills_and_mcp_plan.md) to add:
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
  - Updated [`.agents/references/plans/wine_tkg_skills_and_mcp_plan.md`](file:///workspaces/lug-wine-experimental/.agents/references/plans/wine_tkg_skills_and_mcp_plan.md) with Section 1: "Host System Profile & Compatibility Analysis".

### Session 5 — 2026-10-13
- **User Goal**: Obtain all skills and MCPs necessary to aid the agent in creating a version of the software in this repo supporting GLIBC 2.35 on the current system.
- **Actions Taken**:
  - Authored dedicated skills with automation scripts:
    - [`.agents/skills/glibc-compatibility-auditor/`](file:///workspaces/lug-wine-experimental/.agents/skills/glibc-compatibility-auditor/SKILL.md) containing [`audit_glibc.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh).
    - [`.agents/skills/ubuntu-2204-build-environment-provisioner/`](file:///workspaces/lug-wine-experimental/.agents/skills/ubuntu-2204-build-environment-provisioner/SKILL.md) containing [`check_deps.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh).
    - [`.agents/skills/vkd3d-proton-glibc235-builder/`](file:///workspaces/lug-wine-experimental/.agents/skills/vkd3d-proton-glibc235-builder/SKILL.md).
    - [`.agents/skills/c-build-and-patch-debugger/`](file:///workspaces/lug-wine-experimental/.agents/skills/c-build-and-patch-debugger/SKILL.md).
  - Authored a dedicated technical plan: [`.agents/references/plans/glibc_235_compatibility_plan.md`](file:///workspaces/lug-wine-experimental/.agents/references/plans/glibc_235_compatibility_plan.md).
  - Executed initial dependency check via `check_deps.sh`, verifying that gcc/g++/flex/bison/make/git are installed, while `mingw-w64` and `ntsync.h` remain to be provisioned before compiling.

### Session 6 — 2026-10-13
- **User Query**: Should we modify the Dockerfile to install the MCPs and skills? What is the best course of action here?
- **Actions Taken**:
  - Defined the architecture division:
    - **Skills** remain in repository version control ([`.agents/skills/`](file:///workspaces/lug-wine-experimental/.agents/skills/)) so they are tracked by git and auto-discovered without container rebuilds.
    - **Toolchains & MCP Runtime** are placed into [`.devcontainer/Dockerfile`](file:///workspaces/lug-wine-experimental/.devcontainer/Dockerfile) and [`.devcontainer/devcontainer.json`](file:///workspaces/lug-wine-experimental/.devcontainer/devcontainer.json) for 100% build reproducibility.
  - Installed `clangd`, `gdb`, `mingw-w64`, `meson`, `ninja-build`, `ntsync.h`, and built `/opt/clangd-mcp-server`.
  - Configured active MCP servers in `/root/.gemini/config/mcp_config.json` and committed a template to [`.agents/mcp_config.json`](file:///workspaces/lug-wine-experimental/.agents/mcp_config.json).
  - Authored and verified two additional skills:
    - [`.agents/skills/wine-patch-validator/`](file:///workspaces/lug-wine-experimental/.agents/skills/wine-patch-validator/SKILL.md) with [`validate_patches.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/wine-patch-validator/scripts/validate_patches.sh).
    - [`.agents/skills/tkg-config-auditor/`](file:///workspaces/lug-wine-experimental/.agents/skills/tkg-config-auditor/SKILL.md) with [`audit_config.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/tkg-config-auditor/scripts/audit_config.sh).
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

