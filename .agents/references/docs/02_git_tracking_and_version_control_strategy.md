# 2. Git Tracking & Version Control Strategy

This document explains how all code, submodules, custom patches, build environments, and release artifacts are tracked across GitHub so nothing is lost during upstream updates or an OS reinstall.

---

## 1. Repository & Submodule Map

Your Star Citizen Linux runner stack spans **two GitHub fork repositories** under the **`renanmb`** GitHub account:

| Repository | Local Path | `origin` Remote (Your Fork) | `upstream` Remote (LUG / Upstream) | Active Branch |
| :--- | :--- | :--- | :--- | :--- |
| **`lug-wine-experimental`** | `/home/tarfy/Documents/GitHub/renanmb/lug-wine-experimental` | `https://github.com/renanmb/lug-wine-experimental.git` | `https://github.com/starcitizen-lug/lug-wine-experimental.git` | `main`<br/>*(plus archive branch `wine-11.19-glibc-2.35`)* |
| **`lug-helper`** | `/home/tarfy/Documents/GitHub/renanmb/lug-helper` | `https://github.com/renanmb/lug-helper.git` | `https://github.com/starcitizen-lug/lug-helper.git` | `feature/glibc-2.35-and-runner-selector` |

### Submodules & External Repositories Inside `lug-wine-experimental`

| Path | How It Is Tracked | Upstream Repository | Current Pinned Ref | Why It Is Tracked This Way |
| :--- | :--- | :--- | :--- | :--- |
| **[`custom-patches/wine/`](../../../custom-patches/wine/README.md)** | **Direct Git Directory** in `renanmb/lug-wine-experimental` | `renanmb/lug-wine-experimental` | `HEAD` (`main`) | Stores your own custom `.patch` files directly in your repo; automatically applied (and can override upstream patches) via [`build-lug-wine.sh`](../../../build-lug-wine.sh#L136-L157). |
| **[`patches/`](../../../patches/README.md)** | **Git Submodule** ([`.gitmodules`](../../../.gitmodules#L1-L3)) | `https://github.com/starcitizen-lug/patches` | `e5e2dd9` (`origin/main`) | Tracks the official Star Citizen LUG patchset via an exact commit SHA pointer (`160000` gitlink) so you can pull upstream LUG fixes cleanly. |
| **[`wine-tkg-git/`](../../../wine-tkg-git/README.md)** | **Git Submodule** ([`.gitmodules`](../../../.gitmodules#L4-L6)) | `https://github.com/Frogging-Family/wine-tkg-git` | `65d846c8` (`origin/master`) | Tracks the upstream Wine-TKG build system via an exact commit SHA pointer; never modified in-place (`build-lug-wine.sh` copies it to a temp folder). |
| **[`vkd3d-proton/`](../../../vkd3d-proton/README.md)** | **Git-ignored** ([`.gitignore`](../../../.gitignore#L10-L11)) + **Auto-built** by [`build-lug-wine.sh`](../../../build-lug-wine.sh#L59-L79) | `https://github.com/HansKristian-Work/vkd3d-proton.git` | Tag `v3.0.1` (`3b10bd7a`) | `ensure_vkd3d_proton()` in `build-lug-wine.sh` automatically clones `v3.0.1` (`--recursive`), applies the MinGW 8.0 `PATHCCH_NONE -> 0` fix, and compiles the `x64`/`x86` DLLs whenever `vkd3d-proton/build/...` is missing. |

---

## 2. How Custom Patches Work (`Approach A`)

Never edit files directly inside the `patches/` submodule (since `patches/` points to `starcitizen-lug/patches`, local commits inside `patches/` are not pushed to `renanmb/lug-wine-experimental`).

Instead, place any custom Wine `.patch` files inside **[`custom-patches/wine/`](../../../custom-patches/wine/README.md)**:

1. **Adding a Brand-New Patch:**
   - Drop `custom-patches/wine/my-custom-fix.patch` into [`custom-patches/wine/`](../../../custom-patches/wine/README.md).
   - [`build-lug-wine.sh`](../../../build-lug-wine.sh#L146-L155) automatically detects every `*.patch` file in `custom-patches/wine/` and copies it into `./wine-tkg-userpatches/my-custom-fix.mypatch` during the build.
2. **Overriding an Existing Upstream Patch:**
   - If you want to customize an existing patch from `patches/wine/` (for example, `sc_gpumem.patch`), copy it to `custom-patches/wine/sc_gpumem.patch` and edit the copy in `custom-patches/wine/`.
   - [`build-lug-wine.sh`](../../../build-lug-wine.sh#L137-L144) checks `custom-patches/wine/<name>.patch` **first** before `patches/wine/<name>.patch`, logging:
     `Applied custom override patch: custom-patches/wine/sc_gpumem.patch`
3. **Committing Your Custom Patch:**
   - Because `custom-patches/wine/` is a normal directory in `renanmb/lug-wine-experimental`, simply `git add custom-patches/wine/` and commit/push to `origin`.

---

## 3. How to Sync With Upstream When Star Citizen Updates

When Star Citizen releases a new patch and `starcitizen-lug` updates `lug-wine-experimental` or `patches`:

```bash
# 1. Fetch upstream changes in lug-wine-experimental
git fetch upstream

# 2. Merge upstream/main into your main branch (preserving .devcontainer, .agents, deploy-to-lug-helper.sh, and custom-patches)
git merge upstream/main

# 3. Sync submodules to the commit pointers referenced by the merge (or latest upstream)
git submodule update --init --recursive

# Or to pull the very latest upstream commits in patches/ and wine-tkg-git/:
git -C patches fetch origin && git -C patches checkout origin/main
git -C wine-tkg-git fetch origin && git -C wine-tkg-git checkout origin/master
```

Then rebuild and validate the new runner:
```bash
./build-lug-wine.sh -p staging-default -v 11.21 -r 3
.agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh ./output/lug-wine-tkg-staging-experimental-git-11.21-3.tar.gz 2.35
.agents/skills/eac-and-prefix-verifier/scripts/verify_prefix.sh ./output/lug-wine-tkg-staging-experimental-git-11.21-3.tar.gz
./deploy-to-lug-helper.sh
```

---

## 4. Publishing Built Runners to GitHub Releases (`gh release`)

Because `output/*.tar.gz` archives are ~150 MB binary artifacts, they are ignored by `.gitignore` rather than committed into Git history. To back up your compiled GLIBC 2.35 runners onto GitHub so you can download them directly on any machine without recompiling:

```bash
# 1. Ensure gh is logged into your renanmb account
gh auth status

# 2. Create a GitHub Release on renanmb/lug-wine-experimental and upload the tarball + checksum
gh release create 11.21-2 \
  ./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz \
  ./output/lug-wine-tkg-staging-experimental-git-11.21-2.tar.gz.sha256sum \
  --repo renanmb/lug-wine-experimental \
  --title "LUG Wine Experimental 11.21-2 (Ubuntu 22.04 / GLIBC 2.35)" \
  --notes-file ./output/RELEASE_NOTES.md
```
