---
name: eac-and-prefix-verifier
description: Executes smoke testing in an ephemeral Wine prefix to verify prefix initialization, registry configuration, and EAC loader compatibility.
---

# Skill: EAC and Prefix Verifier

## Purpose
Bootstraps an isolated temporary `WINEPREFIX` with a built LUG Wine runner to verify:
1. Wine prefix initialization (`wineboot -u`) executes cleanly without hangs or errors.
2. WoW64 architecture (`system32` and `syswow64`) initializes properly.
3. Custom LUG registry keys (`reg_hide_wine.patch`, `HideWineExports`) and dummy DLLs (`devobj.dll`, `drvstore.dll`) are created.
4. VKD3D-Proton DirectX 12 PE DLLs (`d3d12.dll`, `d3d12core.dll`) are properly present in both `system32` and `syswow64`.
5. Both `wine` and `wine64` loaders execute Windows commands (`cmd.exe`) successfully.

## When to Use
- Immediately after compiling or downloading a Wine runner package.
- Before distributing or releasing runner artifacts to users.
- When validating compatibility patches modifying `loader/wine.inf.in` or `server/main.c`.

## Instructions
1. Run the verification script against the built tarball or extracted runner directory:
   ```bash
   .agents/skills/eac-and-prefix-verifier/scripts/verify_prefix.sh [path_to_runner_or_tarball]
   ```
2. Inspect the output to ensure all checks pass:
   - Prefix directories created
   - Registry files populated
   - `HideWineExports` and `dummy_dlls` validated
   - VKD3D-Proton DLLs verified
   - Both 32-bit and 64-bit loaders functional
