# Virtual Cable Audio Isolation & `sc-launch.sh` Integration Handoff

- **Date**: 2026-11-22
- **Source Workspace**: `/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux`
- **Target Workspace**: `/home/tarfy/Documents/GitHub/renanmb/lug-wine-experimental` (and host `/home/tarfy/Games/star-citizen/sc-launch.sh`)
- **Purpose**: Cross-repository technical specification and implementation handoff so the agent operating inside `lug-wine-experimental` can integrate PulseAudio virtual-cable game audio isolation (`PULSE_SINK=virtspk`), optional `sc-launch.sh` / deployment automation, and `winepulse.so` build guardrails.

---

## 1. Verified Host & Runner Audio Architecture

1. **Host Audio Server (Ubuntu 22.04.5 LTS)**:
   - Active audio server is **PulseAudio** (`pactl info` -> `Server Name: pulseaudio`), with physical default output `alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo`.
   - `pipewire.service` runs only for desktop Wayland screen-sharing portals (`pipewire-pulse` is `inactive`), so `/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh` is the active host virtual-cable manager.
2. **Active `lug-wine-experimental` Runner (`11.22-2`)**:
   - `/home/tarfy/Games/star-citizen/sc-launch.sh` targets `lug-wine-tkg-staging-experimental-git-11.22-2`.
   - `lib/wine/x86_64-unix/winepulse.so` (`winepulse.drv`) is compiled and dynamically linked against host `/lib/x86_64-linux-gnu/libpulse.so.0`.
   - `/home/tarfy/Games/star-citizen/user.reg` confirms `winepulse.drv` is the active audio driver (`[Software\\Wine\\Drivers\\winepulse.drv\\devices\\...]`).
3. **Signal Flow**:
   ```text
   [lug-wine Game] ──(PULSE_SINK=virtspk)──► Virtual_Speaker (virtspk) ──┬──► Virtual_Microphone (virtmic) ──► [OBS / Discord / Zoom]
                                                                         └──► Virtual_Speaker_Loopback     ──► [Physical USB Headset]
   ```
   - Why `PULSE_SINK=virtspk` beats manual `pavucontrol` routing for Wine: PulseAudio's `module-stream-restore` keys off generic binary names like `wine64-preloader` and can unintentionally drag unrelated Wine prefixes into `Virtual_Speaker`. Exporting `PULSE_SINK=virtspk` scopes routing strictly to the launched `RSI Launcher.exe` + `StarCitizen.exe` process tree from millisecond zero.

---

## 2. Launching `lug-wine-experimental` Isolated onto `virtspk`

Run these commands **on the Linux host** (never inside an isolated devcontainer without the host PulseAudio socket):

### Option A: One-off Host Terminal Launch (No File Edits)

```bash
/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh >/dev/null && \
  PULSE_SINK=virtspk /home/tarfy/Games/star-citizen/sc-launch.sh
```

### Option B: Automatic on Every Launch via `sc-launch.sh`

Add the idempotent virtual-cable startup check inside the `# ENVIRONMENT VARIABLES` block of `/home/tarfy/Games/star-citizen/sc-launch.sh` (lines 19–54):

```bash
if /home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh >/dev/null 2>&1; then
    export PULSE_SINK="virtspk"
fi
```

#### Recommended Toggleable Pattern for `sc-launch.sh`
To match the existing `SC_DEFAULT_RENDERER="${SC_DEFAULT_RENDERER:-1}"` convention in `sc-launch.sh` (allowing `SC_VIRTUAL_CABLE=0 ./sc-launch.sh` to bypass virtual-cable isolation on demand while gracefully falling back to physical audio if the script is unavailable):

```bash
# Virtual audio cable isolation (1 = route game audio to Virtual_Speaker / virtspk, 0 = normal desktop audio)
export SC_VIRTUAL_CABLE="${SC_VIRTUAL_CABLE:-1}"
VIRTUAL_CABLE_SCRIPT="/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh"
if [ "${SC_VIRTUAL_CABLE}" = "1" ] && [ -x "${VIRTUAL_CABLE_SCRIPT}" ]; then
    if "${VIRTUAL_CABLE_SCRIPT}" >/dev/null 2>&1; then
        export PULSE_SINK="virtspk"
    fi
fi
unset VIRTUAL_CABLE_SCRIPT
```

> [!NOTE]
> [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh#L98-L105) currently only rewrites the `^export wine_path=.*` line via `sed -i`, so custom environment variables in `/home/tarfy/Games/star-citizen/sc-launch.sh` survive runner redeployments. However, if `lug-helper.sh` ever regenerates `sc-launch.sh` from `/home/tarfy/Documents/GitHub/renanmb/lug-helper/lib/sc-launch.sh`, having [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh) also seed this block (just as it enforces `GraphicsRenderer = 1`) guarantees full persistence.

### Option C: Lutris Integration (`~/.local/share/lutris/runners/wine`)

1. **System options -> Pre-launch script**: `/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh` (enable *Wait for pre-launch script completion*).
2. **System options -> Environment variables**: `PULSE_SINK` = `virtspk`.

---

## 3. Three Mandatory Audio Invariants

1. **Never export `PULSE_SINK=virtspk` without ensuring `virtspk` exists first**:
   - PulseAudio virtual modules are session-ephemeral and reset on reboot. If `PULSE_SINK=virtspk` is set when `virtspk` is absent, `libpulse` fails `pa_stream_connect_playback()` with `No such entity` and Star Citizen launches **completely silent**. Guarding `export PULSE_SINK="virtspk"` behind `virtual-cables-pulseaudio.sh` (which exits `0` immediately when `virtspk` is already loaded) prevents silent launches even inside containers or headless shells where `pactl` cannot reach the host server.
2. **Always leave `PULSE_SOURCE` unset**:
   - Never set `PULSE_SOURCE=virtmic` in `sc-launch.sh`. Leaving `PULSE_SOURCE` unset preserves the user's real physical microphone for Star Citizen in-game VOIP (proximity/party voice chat) instead of feeding game audio back into the game's mic input.
3. **Keep Host Global Output & In-Game Audio Output on Default**:
   - Keep Ubuntu Sound Settings global output on the physical headset/speakers so incoming Discord/Zoom voices and desktop alerts never enter `virtspk`.
   - Keep Star Citizen's internal Audio Output setting on **Default / System Default** (`winepulse.drv` passes `dev=NULL` to `libpulse`, which automatically honors `PULSE_SINK=virtspk`).

---

## 4. Recommended Implementation Tasks for the `lug-wine-experimental` Agent

When implementing this handoff from inside `/home/tarfy/Documents/GitHub/renanmb/lug-wine-experimental`, execute in clean slices (respecting [`.agents/rules/rules.md`](../../rules/rules.md) — no `git commit` or `git push` without explicit user permission):

1. **`sc-launch.sh` & [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh) Integration**:
   - Add the guarded `SC_VIRTUAL_CABLE` + `PULSE_SINK="virtspk"` block (or CLI subcommand/flag if preferred) to `/home/tarfy/Games/star-citizen/sc-launch.sh` (preserving `tarfy:tarfy` / `1000:1000` ownership).
   - Optionally teach [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh) (around lines 98–106) to idempotently ensure the `SC_VIRTUAL_CABLE` block exists in `sc-launch.sh` alongside the existing Vulkan renderer enforcement, and document it in [`lug_helper_runner_deployment_and_execution.md`](./lug_helper_runner_deployment_and_execution.md) and [`star_citizen_graphics_vulkan_and_launch_troubleshooting.md`](./star_citizen_graphics_vulkan_and_launch_troubleshooting.md).
2. **Fail-Fast `winepulse.so` Build & Smoke-Test Guardrails** (mirroring Session 14's `winex11.so` / `XComposite` guardrails):
   - [`build-lug-wine.sh`](../../../build-lug-wine.sh) & [`check_deps.sh`](../../skills/ubuntu-2204-build-environment-provisioner/scripts/check_deps.sh): verify `libpulse-dev` (`pkg-config --exists libpulse`) at preflight so `winepulse.so` is never silently skipped during `./configure`.
   - [`config/lug-wine-tkg-staging-default.cfg`](../../../config/lug-wine-tkg-staging-default.cfg#L158-L160) (and sibling presets in `config/`): append `--with-pulse` to `_configure_userargs64` and `_configure_userargs32`.
   - [`verify_prefix.sh`](../../skills/eac-and-prefix-verifier/scripts/verify_prefix.sh#L132-L147): add a smoke check confirming `lib/wine/x86_64-unix/winepulse.so` exists and references `libpulse.so.0`.
3. **Optional `.agents` Multi-Assistant Workspace Alignment**:
   - `/home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux` uses the standardized multi-assistant `.agents` layout (`AGENTS.md` canonical root rules + `CLAUDE.md` containing `@AGENTS.md` + relative `.agent -> .agents` and `.claude/skills -> ../.agents/skills` symlinks + `skills/{developer,user}/` + `.agents/memory/INDEX.md` & `sessions/`).
   - If aligning `lug-wine-experimental` to the same multi-agent layout, preserve all 7 existing Wine/GLIBC/VKD3D skills under `.agents/skills/` and existing `.agents/references/` docs/notes/plans while adding root `AGENTS.md` / `CLAUDE.md` and relative discovery symlinks.

---

## 5. Host Verification Checklist (OBS, Discord, `pavucontrol`)

1. Launch the game on the host (`SC_VIRTUAL_CABLE=1 /home/tarfy/Games/star-citizen/sc-launch.sh`) and check active modules:
   ```bash
   /home/tarfy/Documents/GitHub/renanmb/Virtual-Cables-Linux/virtual-cables-pulseaudio.sh status
   ```
2. Open `pavucontrol` on the host:
   - **Playback** tab (*Show: Applications*) -> confirm `StarCitizen.exe` / `RSI Launcher.exe` outputs to **`Virtual_Speaker`** while other desktop apps remain on the physical USB headset.
   - **Input Devices** tab (*Show: All Input Devices*) -> confirm **`Virtual_Microphone`** level meter bounces with game audio.
3. Consume the isolated feed:
   - **OBS Studio**: Mute/disable `Desktop Audio` and add **Audio Output Capture (PulseAudio)** -> **`Virtual_Speaker`** (or **Audio Input Capture** -> **`Virtual_Microphone`**). Run `virtual-cables-pulseaudio.sh restart --no-loopback` if monitoring via OBS to avoid double local playback.
   - **Discord / Zoom / Jitsi**: Set **Input Device / Microphone** to **`Virtual_Microphone`**.

---

## 6. Live Session Diagnosis, Workaround & Sink-Management Roadmap (2026-11-22)

### 6.1 What Was Implemented
1. **Launch & Deployment Integration**:
   - Added the `pactl`-guarded `SC_VIRTUAL_CABLE` (`PULSE_SINK="virtspk"`) block and `[sc-launch] SC_VIRTUAL_CABLE=... PULSE_SINK=...` log header to `/home/tarfy/Games/star-citizen/sc-launch.sh` (`1000:1000`).
   - Updated [`deploy-to-lug-helper.sh`](../../../deploy-to-lug-helper.sh#L98-L136) to idempotently preserve/seed `SC_VIRTUAL_CABLE` across runner deployments.
2. **Build & Smoke-Test Guardrails**:
   - Added `libpulse` and `alsa` preflight checks to [`build-lug-wine.sh`](../../../build-lug-wine.sh#L59-L73), `--with-pulse` across all 4 presets in [`config/lug-wine-tkg-staging-default.cfg`](../../../config/lug-wine-tkg-staging-default.cfg#L158-L160) (and sibling `.cfg` files), and `winepulse.so` (`libpulse.so.0` / `pa_stream_connect_playback`) verification to [`verify_prefix.sh`](../../skills/eac-and-prefix-verifier/scripts/verify_prefix.sh#L149-L164).
   - Authored end-to-end audio & OBS documentation in [`04_audio_isolation_and_obs_streaming_guide.md`](../docs/04_audio_isolation_and_obs_streaming_guide.md).

### 6.2 What Happened During Live Testing (Why Audio Stayed on `Sink: 2` Initially)
When inspecting the live host PulseAudio state while Star Citizen was running:

```text
1  alsa_output.usb-Generic_USB_Audio-00.iec958-stereo                       IDLE
2  alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo RUNNING
3  alsa_output.pci-0000_01_00.1.hdmi-stereo                                 IDLE
4  virtspk (module-null-sink.c)                                             IDLE
---
Sink Input #17   -> Sink: 2   (Virtual_Speaker_Loopback; has media.name, no application.name)
Sink Input #104  -> Sink: 2   (application.name = "Star Citizen", binary = "wine64-preloader")
```

- **Immediate Live Fix Applied**:
  Moving the active `Star Citizen` stream (`Sink Input #104`) onto `virtspk` (`Sink: 4`) immediately isolated game audio without restarting the game:
  ```bash
  pactl move-sink-input 104 virtspk
  ```
  Post-move verification confirmed clean three-way separation:
  - `Sink Input #104` (`Star Citizen`) $\rightarrow$ `Sink: 4` (`virtspk`, captured exclusively by OBS `Virtual_Speaker`).
  - `Sink Input #107` (`Chromium`) $\rightarrow$ `Sink: 2` (`USB_Audio_Device`, excluded from OBS).
  - `Sink Input #17` (`Virtual_Speaker_Loopback`) $\rightarrow$ `Sink: 2` (`USB_Audio_Device`, local headphone monitoring).

- **Reusable One-Liner (No Need to Look Up `#104` Manually)**:
  Because PulseAudio sink-input numbers change every session, use this command to move an already-running Star Citizen stream onto `virtspk` by name:
  ```bash
  pactl list sink-inputs | awk '/Sink Input #/{id=substr($3,2)} /application\.name = "Star Citizen"/{print id}' | xargs -r -n1 -I{} pactl move-sink-input {} virtspk
  ```
  And to inspect all active streams **including** loopback names (`media.name`):
  ```bash
  pactl list short sinks && echo "---" && pactl list sink-inputs | grep -E "Sink Input|Sink:|flags:|media\.name|application\.name|application\.process\.binary"
  ```

### 6.3 Root Causes in How Audio Sinks Are Currently Managed
1. **`PULSE_SINK` Is Launch-Time Only (Does Not Retroactively Move Running Processes)**:
   - `PULSE_SINK=virtspk` is only read when `RSI Launcher.exe` / `wineserver` starts. If RSI Launcher or Star Citizen was started before `virtspk` / `sc-launch.sh` had `PULSE_SINK=virtspk` (or if clicking *Launch Game* from an older backgrounded RSI Launcher instance), `StarCitizen.exe` inherits the old environment and attaches to the host default sink (`Sink: 2`).
2. **Ephemeral Numeric Sink & Sink-Input IDs + Blank `application.name` on Loopbacks**:
   - PulseAudio sink indices (`2`, `4`) and sink-input IDs (`#17`, `#104`) change across reboots and stream restarts, and `module-loopback` (`Sink Input #17`) only populates `media.name` (not `application.name`), making raw `pactl` checks harder to read at a glance.
3. **`winepulse.so` `PA_STREAM_DONT_MOVE` (`0x0200`) Trap on Non-Default In-Game Devices**:
   - Disassembly of `11.22-2` `winepulse.so` (`get_endpoint_ids` at `0x3e30` and `pulse_stream_connect` at `0x81ba`) confirmed:
     - When Star Citizen is left on **Default** (`[0,]` `"Speakers (PulseAudio Output)"`), `winepulse.so` passes `dev = NULL` with flags `0x12001` (no `DONT_MOVE`), so **both** `PULSE_SINK=virtspk` and `pactl move-sink-input` work.
     - If a specific hardware output is ever chosen inside Star Citizen's in-game Audio menu, `winepulse.so` passes that explicit ALSA sink name with `0x12201` (`PA_STREAM_DONT_MOVE`), which overrides `PULSE_SINK` and causes `pactl move-sink-input` to fail with `Failure: Invalid argument`.
4. **Static `module-loopback` Target Sink When Switching Headset $\leftrightarrow$ Speakers**:
   - `Virtual_Speaker_Loopback` (`Sink Input #17`) stays pinned to whichever physical sink was default when `virtual-cables-pulseaudio.sh` initialized, requiring either `virtual-cables-pulseaudio.sh restart` or moving the loopback sink-input when switching between USB headset and desk/HDMI speakers.

### 6.4 How to Fix Sink Management Cleanly Later
When revisiting sink management (in `Virtual-Cables-Linux` and/or `sc-launch.sh` subcommands), implement a dedicated sink-routing controller:
1. **Event-Driven / Post-Launch Auto-Mover (`pactl subscribe` or `sc-launch.sh audio-isolate`)**:
   - Automatically detect `Star Citizen` (`application.name = "Star Citizen"`) sink-inputs on creation (or on demand) and move them to `virtspk` by sink name, so audio isolation works even if Star Citizen was launched from an already-open RSI Launcher or Lutris without restarting the game.
2. **Human-Readable `audio-status` Command**:
   - Resolve numeric `Sink: <N>` IDs directly to sink names (`virtspk` vs `USB_Audio_Device` vs `HDMI`) and print both `application.name` and `media.name` so `Star Citizen`, `Virtual_Speaker_Loopback`, and desktop apps (`Chromium`, `Discord`) are unmistakable.
3. **One-Command Local Monitor Target Switcher (`audio-listen <headset|speakers|off>`)**:
   - Move only the `module-loopback` (`source=virtspk.monitor`) sink-input between physical sinks (USB headset, USB speakers, HDMI) without disturbing `virtspk` or OBS Studio.
