---
name: glibc-compatibility-auditor
description: Inspects ELF binaries and shared libraries (.so) in Wine build artifacts to verify they do not exceed GLIBC 2.35 requirements.
---

# Skill: GLIBC Compatibility Auditor

## Purpose
Ensures that compiled Wine runners, loader binaries, and companion libraries (`vkd3d-proton`, `wineopenxr`, etc.) are 100% compatible with the host system running **GLIBC 2.35 (Ubuntu 22.04)**.

## When to Use
- After performing a local compilation or downloading pre-built packages.
- Prior to running smoke tests or packaging artifacts for Ubuntu 22.04.
- When inspecting third-party binary dependencies.

## Instructions
1. Run the audit script against a specific binary or directory:
   ```bash
   .agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh <target_path> 2.35
   ```
2. If failures are detected:
   - Identify which shared library or translation unit introduced the forward glibc symbol (e.g. `GLIBC_2.38` features like `strerrorname_np` or newer math symbols).
   - Recompile the offending component natively on Ubuntu 22.04 or provide fallback C implementation stubs.
