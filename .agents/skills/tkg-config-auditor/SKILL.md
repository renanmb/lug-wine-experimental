---
name: tkg-config-auditor
description: Audits LUG Wine configuration files against upstream Wine-TKG templates to verify option compatibility and WoW64 settings.
---

# Skill: Wine-TKG Configuration Auditor

## Purpose
Compares local configuration profiles in `config/` against upstream `wine-tkg-git` sample templates to ensure valid syntax and appropriate WoW64 / multilib settings for Ubuntu 22.04 with GLIBC 2.35.

## When to Use
- Before launching builds.
- When updating or modifying configuration presets in `config/`.

## Workflow
1. Run the audit script:
   ```bash
   .agents/skills/tkg-config-auditor/scripts/audit_config.sh
   ```
2. Check the output for any warnings regarding `_NOLIB32` (should remain `"wow64"`).
