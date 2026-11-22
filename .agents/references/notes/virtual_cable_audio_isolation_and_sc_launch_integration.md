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
