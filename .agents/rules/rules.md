# Agent Rules & Guidelines

These rules are mandatory for all AI agents working within this repository.

---

## 1. Git & Version Control Rules (CRITICAL)

> [!CAUTION]
> **NEVER COMMIT OR PUSH WITHOUT EXPLICIT PERMISSION.**

1. **No Automated Commits**:
   - The agent MUST NEVER run `git commit` unless the user explicitly requests or confirms a commit.
2. **No Automated Pushes**:
   - The agent MUST NEVER run `git push` under any circumstances unless explicitly ordered to push by the user.
3. **Branch & Remote Protection**:
   - Never switch, delete, or create git branches without user instruction.
   - Never change git remote URLs or configuration.
   - Never perform destructive Git operations (`git reset --hard`, `git clean -fd`, `git rebase`, force-pushing) without explicit consent.
4. **Git Submodule Care**:
   - This repository relies on submodules (`patches` and `wine-tkg-git`). Do not alter submodule pointers, HEAD commits, or uncommitted submodule states unless specifically asked.

---

## 2. Build & Execution Rules

1. **Resource-Intensive Builds**:
   - Compiling Wine from source (`build-lug-wine.sh`) is compute- and time-intensive (requires compiling hundreds of megabytes of C/C++ code and takes significant CPU time).
   - Never initiate full Wine compilation in background tasks or interactive shells without user confirmation.
2. **Directory Sanitation**:
   - Temporary build directories (`wine-tkg-build-tmp-*`) should be cleaned up according to the script's traps. Avoid creating temporary files outside designated build/artifact paths.
3. **Preserve Configuration Integrity**:
   - Do not overwrite configuration profiles in [`config/`](file:///workspaces/lug-wine-experimental/config) unless implementing a specifically requested feature or fix.

---

## 3. Code Modification & Quality

1. **Comments and Documentation**:
   - Preserve existing comments and docstrings.
   - Keep scripts portable and aligned with Bash best practices (`set -e`, proper quotation of variables).
2. **Link Transparency**:
   - Always provide direct clickable file links when referencing project paths or code symbols.
