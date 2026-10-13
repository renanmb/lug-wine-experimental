---
name: wine-patch-validator
description: Validates syntax and application of LUG community patches against a target Wine source repository to identify rejects and conflicts.
---

# Skill: Wine Patch Validator

## Purpose
Tests community patch files in `patches/wine/` against a target Wine git tree to detect merge conflicts, hunk rejections, or offset drift prior to starting a multi-hour build.

## Instructions
1. Run the validator against the target Wine repository:
   ```bash
   .agents/skills/wine-patch-validator/scripts/validate_patches.sh [path_to_wine_repo]
   ```
2. For any rejected patches:
   - Examine the patch with `git apply --verbose --reject <patch_file>`.
   - Use the `c-build-and-patch-debugger` skill to adapt the patch hunks to the target Wine commit.
