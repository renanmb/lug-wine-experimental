# Star Citizen Graphics, Vulkan, and Launch Troubleshooting Guide

This guide documents the root causes, diagnostic logs, and solutions for the common launch failures, Vulkan API version crashes, and graphics configuration issues encountered when running Star Citizen on Linux via Wine-TkG / LUG Helper.

---

## 1. Overview of Issues Encountered

| Issue | Manifestation / Error Message | Root Cause | Solution |
| :--- | :--- | :--- | :--- |
| **`sc-launch.sh` Silent Exit** | Launcher window does not open; log says `DXVK: No adapters found. Please check your device filter settings` | Restrictive `DXVK_FILTER_DEVICE_NAME` + laptop Optimus variables breaking desktop GLX | Set `DXVK_FILTER_DEVICE_NAME="NVIDIA"` and remove Optimus offload variables |
| **Vulkan API Version Crash** | Pop-up: `Vulkan API version for chosen GPU Device is less than Vulkan 1.2...`; `Fatal Error Thrown: Required Vulkan API Version not available` | In-game native Vulkan renderer fails device selection under `winevulkan` | Force DirectX 11 (DXVK) via `user.cfg` and `GraphicsSettings.json` |
| **Crash Loop After Changing Settings** | Game crashes on boot after changing resolution or window mode in the options menu | The in-game Graphics menu saves `GraphicsRenderer: 1` upon applying changes, taking precedence on next launch | Reset `GraphicsRenderer: 0` in `GraphicsSettings.json` |
| **Mouse Escaping in Windowed Mode** | Cursor drifts out of the window when navigating menus (Mobiglas, inventory) | Windowed mode (`WindowMode = 1`) unclips cursor during UI interaction | Rely on in-game auto-lock during gameplay, or enable Wine's `GrabPointer` registry setting |

---

## 2. Issue: `sc-launch.sh` Fails to Launch (DXVK Adapter Not Found)

### Diagnostic Symptoms
When running `~/Games/star-citizen/sc-launch.sh`, the process exits immediately with no terminal output. Inspecting `~/Games/star-citizen/sc-launch.log` shows:

```text
info:  Game: RSI Launcher.exe
info:  DXVK: v3.1.1
info:  Found device: NVIDIA RTX PRO 6000 Blackwell Workstation Edition (NVIDIA 595.99.2)
info:    Skipping: Device filter
info:  Found device: NVIDIA-G0 (NVIDIA 595.99.2)
info:    Skipping: Device filter
warn:  DXVK: No adapters found. Please check your device filter settings
warn:  and Vulkan drivers. A Vulkan 1.3 capable setup is required.
err:   Failed to initialize DXVK.
```

### Root Cause
1. **Device Filter Mismatch:** Setting `DXVK_FILTER_DEVICE_NAME="RTX 5090"` caused DXVK to skip both available GPUs because Wine/driver named them `NVIDIA RTX PRO 6000 Blackwell Workstation Edition` (primary display adapter) and `NVIDIA-G0` (secondary headless adapter). Neither contains `"RTX 5090"`.
2. **Optimus Laptop Flags on Desktop:** Environment variables like `__NV_PRIME_RENDER_OFFLOAD=1` and `__GLX_VENDOR_LIBRARY_NAME=nvidia` are meant exclusively for hybrid-GPU laptops. On desktop workstations where monitors connect directly to the NVIDIA card, these variables break X11/EGL/GLX initialization (`failed to create dri2 screen`).

### Fix in `~/Games/star-citizen/sc-launch.sh`
Remove all Optimus and hardcoded `VK_ICD_FILENAMES` lines, and configure DXVK to filter on `"NVIDIA"`:

```bash
# In ~/Games/star-citizen/sc-launch.sh:

# Nvidia cache options
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# GPU selection: filter for NVIDIA discrete GPU (prevents selecting AMD CPU iGPU or llvmpipe)
export DXVK_FILTER_DEVICE_NAME="NVIDIA"
```

> [!TIP]
> `DXVK_FILTER_DEVICE_NAME="NVIDIA"` matches both `NVIDIA RTX PRO 6000...` and `NVIDIA-G0` while excluding CPU integrated graphics (`RADV RAPHAEL_MENDOCINO`) and `llvmpipe`. DXVK automatically picks the GPU connected to the active display output.

---

## 3. Issue: Star Citizen Native Vulkan Crash (`Vulkan API Version < 1.2`)

### Diagnostic Symptoms
When launching the game, Star Citizen displays a dialog:
> *Vulkan API version for chosen GPU Device is less than Vulkan 1.2. At least version 1.2 is required to run the game... Reverting to Direct3D 11 Renderer.*

Following this, the game crashes immediately. Inspecting `LIVE/Game.log` reveals:

```text
VulkanMetric - Device (NVIDIA RTX PRO 6000 Blackwell Workstation Edition) [GPU (Discrete)] ID:11185
VulkanMetric -     Driver 595.99.2.0
VulkanMetric -     VulkanAPI 1.4.329
[VK] No valid Discrete GPU found, searching for potential Integrated GPU
[VK] Chosen Vulkan GPU Device () Driver Version (0.0.0) Vulkan API (0.0.0) 
[VK] Selected Physical Device does not support Vulkan Version 1.3 or higher!
Fatal Error Thrown: Required Vulkan API Version not available.
```

### Root Cause
- Star Citizen Alpha 3.23+ and 4.x include an experimental **native Vulkan renderer** (`GraphicsRenderer: 1`).
- On Wine/Linux, Star Citizen's native device selection logic fails to properly map Windows DXGI adapter LUIDs to `winevulkan` devices. It rejects the discrete GPU, falls back to `(0.0.0)`, and crashes.
- **On Linux, DirectX 11 IS Vulkan:** When Star Citizen is set to **DirectX 11** (`GraphicsRenderer: 0`), Wine routes calls through **DXVK**. DXVK translates D3D11 directly into native Vulkan calls on the host, delivering full Vulkan performance, multi-threaded shader compiling, and rock-solid stability.

### Fix
Force the engine to use DirectX 11 via DXVK in both configuration files:

#### 1. In `LIVE/user.cfg`:
Create or edit `~/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user.cfg`:
```text
r.GraphicsRenderer = 0
```

#### 2. In `GraphicsSettings.json`:
Edit `~/Games/star-citizen/drive_c/users/tarfy/AppData/Local/star citizen/starcitizen_(sc-alpha-4.10.2)_ot8f6_0/GraphicsSettings/GraphicsSettings.json`:
```json
{
  "GraphicsSettings": {
    "SettingsVersion": 1,
    "GraphicsRenderer": 0
  }
}
```

> [!IMPORTANT]
> If `GraphicsSettings.json` has `"GraphicsRenderer": 1`, it **overrides** `user.cfg`. Both files must be set to `0`.

---

## 4. Configuring Resolution & Windowed Mode (e.g. 2560×1440 Windowed)

Changing resolution or display mode inside the in-game menu can trigger a crash loop because hitting **Apply** in that menu also re-saves the active renderer as Vulkan. To configure resolution and window mode safely without touching the in-game menu:

### Step 1: Update `LIVE/user.cfg`
Add CryEngine resolution and display mode parameters to `~/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user.cfg`:

```text
r.GraphicsRenderer = 0
r_Width = 2560
r_Height = 1440
r_Fullscreen = 0
r_FullscreenWindow = 0
```

### Step 2: Update `attributes.xml`
Edit `~/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user/client/0/Profiles/default/attributes.xml`:

```xml
 <Attr name="Height" value="1440"/>
 <Attr name="Width" value="2560"/>
 <Attr name="WindowMode" value="1"/>
```

* **WindowMode reference values:**
  * `0` = Fullscreen Exclusive
  * `1` = Windowed
  * `2` = Borderless Windowed (Fullscreen Windowed)

---

## 5. Mouse Confinement in Windowed Mode

### Expected Behavior
- **During Gameplay (Flight, FPS, Combat, Steering):** Star Citizen locks the mouse using raw input (`ClipCursor`), and Wine's X11 driver grabs the pointer (`XGrabPointer`). The cursor cannot leave the game window.
- **In Menus / UI (Mobiglas `F1`, Inventory `I`, Interaction `F`, ESC):** Star Citizen intentionally releases the pointer to let the player click interface buttons. Moving the mouse outside the window boundaries and clicking will unfocus the game.

### Optional: Force-Confine Mouse at All Times
If you want Wine to strictly trap the mouse inside the game window even when menus are open:

```bash
# Set Wine X11 Driver GrabPointer registry flag
/home/tarfy/Games/star-citizen/runners/lug-wine-tkg-custom-2.35/bin/wine reg add "HKCU\\Software\\Wine\\X11 Driver" /v GrabPointer /t REG_SZ /d Y /f
```

---

## 6. Quick Verification Checklist

When diagnosing game startup or graphics issues, check these files in order:

1. **Launcher & DXVK Log:**
   ```bash
   cat ~/Games/star-citizen/sc-launch.log | tail -n 40
   ```
   *Look for:* `D3D11InternalCreateDevice`, `Using feature level D3D_FEATURE_LEVEL_11_0`.

2. **Game Engine Log:**
   ```bash
   tail -n 60 ~/Games/star-citizen/drive_c/Program\ Files/Roberts\ Space\ Industries/StarCitizen/LIVE/Game.log
   ```
   *Look for:* Renderer initialization, active adapter index, and resolution changes.

3. **Active Renderer Setting:**
   ```bash
   cat ~/Games/star-citizen/drive_c/users/tarfy/AppData/Local/star\ citizen/*/GraphicsSettings/GraphicsSettings.json
   ```
   *Ensure:* `"GraphicsRenderer": 0`.
