# Custom Wine Patches (`custom-patches/wine/`)

This directory holds fork-specific `.patch` files tracked directly in the `renanmb/lug-wine-experimental` repository, separate from the upstream [`patches/`](../../patches/README.md) Git submodule (`starcitizen-lug/patches`).

---

## Why This Directory Exists

Because [`patches/`](../../patches/README.md) is a Git submodule pointing to `https://github.com/starcitizen-lug/patches`, modifying or adding files directly inside `patches/` would create local submodule commits that do not exist on upstream `starcitizen-lug/patches` and would not be pushed when pushing `renanmb/lug-wine-experimental`.

By placing your own `.patch` files in `custom-patches/wine/`, they are:
1. **Tracked directly by Git** in `renanmb/lug-wine-experimental`.
2. **Kept conflict-free** when syncing the `patches/` submodule with upstream `starcitizen-lug/patches`.
3. **Automatically applied** by [`build-lug-wine.sh`](../../build-lug-wine.sh) during runner compilation.

---

## How [`build-lug-wine.sh`](../../build-lug-wine.sh) Applies Custom Patches

During `prepare_preset()`:
1. **Upstream Patch List + Override Support:**
   - For every patch listed in the `patches=(...)` array (or passed via `-a` / `--adhoc`), `build-lug-wine.sh` checks `custom-patches/wine/<name>.patch` **first** before falling back to `patches/wine/<name>.patch`.
   - This means placing a file in `custom-patches/wine/` with the **same name** as an upstream patch (e.g., `custom-patches/wine/sc_gpumem.patch`) cleanly overrides that upstream patch without modifying the `patches/` submodule.
2. **Automatic Injection of New Custom Patches:**
   - Any additional `*.patch` files placed in `custom-patches/wine/` are automatically copied into the temporary build directory as `./wine-tkg-userpatches/<name>.mypatch` after the upstream patch list so Wine-TKG applies them automatically.

---

## Validating Custom Patches Before Building

Before running a full Wine build, validate the syntax of your custom patches using the `wine-patch-validator` skill script:

```bash
git apply --check custom-patches/wine/<your-patch>.patch
# Or validate all patches:
.agents/skills/wine-patch-validator/scripts/validate_patches.sh
```
