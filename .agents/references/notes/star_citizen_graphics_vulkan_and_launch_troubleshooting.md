# Star Citizen Graphics, Vulkan, and Launch Troubleshooting Guide

This guide documents the root causes, diagnostic logs, and solutions for the common launch failures, Vulkan API version crashes, and graphics configuration issues encountered when running Star Citizen on Linux via Wine-TkG / LUG Helper.

---

## 1. Overview of Issues Encountered

| Issue | Manifestation / Error Message | Root Cause | Solution |
| :--- | :--- | :--- | :--- |
| **`sc-launch.sh` Silent Exit** | Launcher window does not open; log says `DXVK: No adapters found. Please check your device filter settings` | Restrictive `DXVK_FILTER_DEVICE_NAME` + laptop Optimus variables breaking desktop GLX | Set `DXVK_FILTER_DEVICE_NAME="NVIDIA RTX PRO 6000"` and remove Optimus offload variables |
| **RSI Launcher Black Screen** | Launcher window opens and resizes (`1440×900`) with working background logs, but renders solid black | `winex11.so` compiled without `libxcomposite-dev` (`SONAME_LIBXCOMPOSITE`), leaving Electron child-HWND Vulkan surfaces unredirected | Build with `libxcomposite-dev` and `--with-xcomposite` (`11.22-2+`); verified by `verify_prefix.sh` |
| **Vulkan API Version Crash (Historical `< 11.22-1`)** | Pop-up: `Vulkan API version for chosen GPU Device is less than Vulkan 1.2...`; `Fatal Error Thrown: Required Vulkan API Version not available` | Uninitialized `VkPhysicalDeviceLayeredDriverPropertiesMSFT` memory in `winevulkan` (`< 11.22-1`) disqualifying discrete GPUs | Resolved in `11.22-2+` via [`winevulkan-zero-conversion-context.patch`](../../../custom-patches/wine/winevulkan-zero-conversion-context.patch) and [`d3dkmt-sync-getfd.patch`](../../../patches/wine/d3dkmt-sync-getfd.patch); **Vulkan (`1`) is now the standard startup renderer** |
| **DirectX 11 Broken on `4.10.3+`** | Game fails to work properly when started in DX11 (`Feature level: DX11.1`) | Star Citizen `4.10.3+` (`Build 13220821+`) expects Vulkan (`GraphicsRenderer: 1`); legacy `r.GraphicsRenderer = 0` in `user.cfg` forced DX11 on first boot | Enforce `r.GraphicsRenderer = 1` in `LIVE/user.cfg` and `"GraphicsRenderer": 1` in `GraphicsSettings.json` via `sc-launch.sh` and [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh) |
| **Renderer Reset / Ping-Pong** | Game switches renderers or writes malformed `GraphicsSettings.json` across patches | Mismatch between `LIVE/user.cfg` and new `starcitizen_(sc-alpha-*)` `GraphicsSettings.json` folders | `sc-launch.sh` (`ensure_vulkan_renderer`) automatically enforces `GraphicsRenderer = 1` in both files before every launch |
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

## 3. Standard Renderer Configuration: Native Vulkan (`GraphicsRenderer = 1`)

### Background
- In Star Citizen `4.10.3+` (`Build 13220821+`), DirectX 11 (`GraphicsRenderer: 0`) no longer works reliably, whereas **Native Vulkan (`GraphicsRenderer: 1`)** runs stably on `LUG Wine 11.22-2+` (`Vulkan 1.4.329` on `NVIDIA RTX PRO 6000 Blackwell`) thanks to [`winevulkan-zero-conversion-context.patch`](../../../custom-patches/wine/winevulkan-zero-conversion-context.patch) and [`d3dkmt-sync-getfd.patch`](../../../patches/wine/d3dkmt-sync-getfd.patch).
- Earlier builds (`< 11.22-1`) suffered from an uninitialized `VkPhysicalDeviceLayeredDriverPropertiesMSFT` memory bug in `winevulkan` (`[VK] No valid Discrete GPU found`), which had temporarily required `r.GraphicsRenderer = 0` as a workaround. Leaving `r.GraphicsRenderer = 0` in `LIVE/user.cfg` caused new Star Citizen builds to boot into broken DX11 whenever a fresh `AppData` profile directory was created.

### Standard Vulkan Startup Configuration (Automated in `sc-launch.sh` & [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh))
Both `~/Games/star-citizen/sc-launch.sh` (`ensure_vulkan_renderer`) and [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh) now automatically enforce Native Vulkan (`1`) at startup across all installed channels (`LIVE`, `PTU`, `EPTU`, `TECH-PREVIEW`) and `AppData` profile folders while preserving all other graphics settings:

#### 1. In `LIVE/user.cfg`:
`~/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user.cfg`:
```text
r.GraphicsRenderer = 1
```

#### 2. In `GraphicsSettings.json`:
`~/Games/star-citizen/drive_c/users/tarfy/AppData/Local/star citizen/starcitizen_*/GraphicsSettings/GraphicsSettings.json`:
```json
{
  "GraphicsSettings": {
    "SettingsVersion": 1,
    "GraphicsRenderer": 1
  }
}
```

> [!IMPORTANT]
> Both `LIVE/user.cfg` and `GraphicsSettings.json` are kept at `1` (Vulkan) so first-boot after game updates and subsequent launches always start directly in Vulkan.

---

## 4. Configuring Resolution & Windowed Mode (e.g. 2560×1440 Windowed)

To configure resolution and window mode cleanly alongside the Vulkan renderer default:

### Step 1: Update `LIVE/user.cfg`
Add CryEngine resolution and display mode parameters to `~/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user.cfg`:

```text
r.GraphicsRenderer = 1
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
   *Ensure:* `"GraphicsRenderer": 1` (Native Vulkan, standard default).

---

## 7. Debugging Visual Glitches Using Screenshots

When reporting in-game rendering bugs, shader artifacts, missing textures, or UI glitches to the AI agent, providing screenshots allows the agent to visually inspect the artifact and correlate it against engine and Vulkan logs.

### Why `PrintScreen` Files Need to Be Copied
On Ubuntu/GNOME, pressing `PrintScreen` in-game is intercepted by the host desktop environment and saved to:
- **Host Capture Path:** `/home/tarfy/Pictures/Screenshots/`

Because [`.devcontainer/devcontainer.json`](../../../.devcontainer/devcontainer.json) only bind-mounts `/home/tarfy/Games` and `/lug-helper` (and not `/home/tarfy/Pictures`), files left in `/home/tarfy/Pictures/Screenshots/` are not visible inside the devcontainer.

### Recommended Screenshot Folder
Copy screenshots into:
- **Primary Folder:** `/home/tarfy/Games/star-citizen/screenshots/`
  - Easily accessible in Ubuntu Files (`Home` $\rightarrow$ `Games` $\rightarrow$ `star-citizen` $\rightarrow$ `screenshots`).
  - Automatically visible inside the devcontainer at the exact same path (`/home/tarfy/Games/star-citizen/screenshots/`).
  - Outside the Git repository, so screenshots never clutter `git status` or risk being committed.
- **Alternative (VS Code Explorer Drag-and-Drop):** `/home/tarfy/Documents/GitHub/renanmb/lug-wine-experimental/output/screenshots/`
  - Already ignored by Git via `output/` in [`.gitignore`](../../../.gitignore).
- **Direct Chat Upload:** You can also paste (`Ctrl+V`) or drag-and-drop images directly into the chat prompt.

### Step-by-Step Workflow for Debugging Visual Glitches

1. **(Optional) Enable In-Game Renderer Overlay Before Capturing:**
   Open the Star Citizen console (`~`) and run:
   ```text
   r_DisplayInfo = 3
   ```
   This stamps the active renderer (`Vulkan` vs `D3D11`), GPU memory, frame timings, and build info directly into the corner of the screenshot.

2. **Capture and Copy the Screenshot:**
   Press `PrintScreen`, then either copy-paste the image in Ubuntu Files from `~/Pictures/Screenshots/` into `~/Games/star-citizen/screenshots/`, or run on the host:
   ```bash
   mkdir -p /home/tarfy/Games/star-citizen/screenshots
   cp -p /home/tarfy/Pictures/Screenshots/* /home/tarfy/Games/star-citizen/screenshots/
   ```
   > [!TIP]
   > Using `cp -p` (or GUI copy-paste) preserves the file's timestamp so the agent can match the exact second the screenshot was taken against `<YYYY-MM-DDTHH:MM:SSZ>` entries in `LIVE/Game.log`.

3. **Prompt the Agent:**
   Tell the agent to check `/home/tarfy/Games/star-citizen/screenshots/` (or specify the filename) and briefly note what was happening (e.g., *"flickering volumetric clouds on Vulkan"*, *"black MFD panels"*, *"corrupted shadows"*).

4. **What the Agent Checks Automatically:**
   - Reads the image(s) in `/home/tarfy/Games/star-citizen/screenshots/` to classify the failure mode (e.g., descriptor/UBO corruption, NaN shader bloom, depth/stencil precision, X11/Wayland compositing, or stale shader cache).
   - Cross-references `/home/tarfy/Games/star-citizen/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/Game.log` and `/home/tarfy/Games/star-citizen/sc-launch.log` around the screenshot timestamp.
   - Checks active `GraphicsSettings.json`, `LIVE/user.cfg`, `winevulkan` / DXVK / VKD3D-Proton behavior, and shader caches (`/home/tarfy/Games/star-citizen/GLCache` and `AppData/Local/star citizen/*/shaders/`).
