# Agent Skills

This directory contains specialized procedural skills, automation scripts, and workflow instructions for AI agents working in this repository.

---

## Directory Organization

Each skill should reside in its own subdirectory containing:
- `SKILL.md`: Detailed instructions, when to invoke the skill, arguments, and required tools.
- (Optional) `scripts/`: Supporting shell scripts or utilities.
- (Optional) `references/`: Supporting documentation or templates.

```
.agents/skills/
├── README.md               # This guide
└── <skill-name>/           # Individual skill directory
    ├── SKILL.md            # Skill instructions & metadata
    └── scripts/            # Helper scripts (optional)
```

---

## Equipped Active Skills

1. [**`glibc-compatibility-auditor`**](file:///workspaces/lug-wine-experimental/.agents/skills/glibc-compatibility-auditor/SKILL.md):
   - Inspects ELF binaries and `.so` files using [`audit_glibc.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh) to verify GLIBC symbol requirements do not exceed `2.35`.
2. [**`ubuntu-2204-build-environment-provisioner`**](file:///workspaces/lug-wine-experimental/.agents/skills/ubuntu-2204-build-environment-provisioner/SKILL.md):
   - Uses [`check_deps.sh`](file:///workspaces/lug-wine-experimental/.agents/skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh) to test and provision host tools (MinGW-w64 cross compiler, `ntsync.h` kernel header) on Ubuntu 22.04.
3. [**`vkd3d-proton-glibc235-builder`**](file:///workspaces/lug-wine-experimental/.agents/skills/vkd3d-proton-glibc235-builder/SKILL.md):
   - Instructions and workflow to build and bundle VKD3D-Proton DirectX 12 PE DLLs under Ubuntu 22.04.
4. [**`c-build-and-patch-debugger`**](file:///workspaces/lug-wine-experimental/.agents/skills/c-build-and-patch-debugger/SKILL.md):
   - Triages and resolves C compilation issues, GCC 11 flags, and Wine patch conflicts.
