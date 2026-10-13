---
name: ubuntu-2204-build-environment-provisioner
description: Diagnoses and provisions the required build toolchain, kernel headers, and libraries for compiling Wine-TKG WoW64 under Ubuntu 22.04 with GLIBC 2.35.
---

# Skill: Ubuntu 22.04 Build Environment Provisioner

## Purpose
Ensures that the host Ubuntu 22.04 environment is fully equipped with required C compilers, MinGW cross-compilers, and kernel synchronization headers needed to compile Wine-TKG with WoW64 without multilib breakage.

## When to Use
- Before running `./build-lug-wine.sh` locally.
- When configuring a new devcontainer or CI runner based on Ubuntu 22.04.

## Workflow
1. Execute the dependency checker:
   ```bash
   .agents/skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh
   ```
2. If `ntsync.h` is missing, fetch the kernel UAPI header:
   ```bash
   sudo mkdir -p /usr/local/include/linux && sudo curl -o /usr/local/include/linux/ntsync.h -fs --retry 5 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/uapi/linux/ntsync.h
   ```
3. Install any missing build packages reported by the script:
   ```bash
   sudo apt-get update && sudo apt-get install -y mingw-w64
   ```
