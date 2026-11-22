# Project Documentation (`docs/`)

This directory provides complete, end-to-end documentation for the **`renanmb/lug-wine-experimental`** project: what we built, how the components and Git repositories are tracked, and how to replicate the entire setup on another Linux machine or after a clean OS install.

---

## Documentation Guides

1. [**`01_architecture_and_what_we_built.md`** — What & How We Built It](./01_architecture_and_what_we_built.md)
   - Why this fork was created (Ubuntu 22.04 LTS / GLIBC 2.35 compatibility vs. upstream GLIBC 2.39).
   - How the Devcontainer, New-WoW64 Wine-TKG architecture, VKD3D-Proton `v3.0.1`, and 22+ Star Citizen patches work together.
   - How automated validation (`check_deps.sh`, `audit_glibc.sh`, `verify_prefix.sh`) and deployment (`deploy-to-lug-helper.sh`) work.

2. [**`02_git_tracking_and_version_control_strategy.md`** — How We Keep Track of the Project](./02_git_tracking_and_version_control_strategy.md)
   - Complete map of repositories (`renanmb/lug-wine-experimental` and `renanmb/lug-helper`), remotes (`origin` vs `upstream`), and branches.
   - How Git submodules (`patches/`, `wine-tkg-git/`), custom patches ([`custom-patches/wine/`](../../../custom-patches/wine/README.md)), and `vkd3d-proton/` are managed.
   - Workflow for syncing upstream Star Citizen updates and publishing runner tarballs to GitHub Releases.

3. [**`03_replication_and_clean_install_guide.md`** — How to Replicate on a Clean OS Install or New Machine](./03_replication_and_clean_install_guide.md)
   - Step-by-step runbook to reproduce this entire setup from scratch after wiping your OS or moving to a new Linux workstation.
   - Covers cloning with submodules, launching the devcontainer, one-command runner compilation (or downloading from GitHub Releases), deploying to LUG Helper / Lutris / Star Citizen prefix, and configuring multi-GPU Vulkan/DXVK settings.

4. [**`04_audio_isolation_and_obs_streaming_guide.md`** — Audio Configuration, Virtual Cable Isolation & OBS Streaming Guide](./04_audio_isolation_and_obs_streaming_guide.md)
   - End-to-end PulseAudio virtual-cable routing (`PULSE_SINK=virtspk` via `winepulse.so`) for isolating Star Citizen audio in OBS Studio and Discord while keeping in-game VOIP on your physical microphone.
   - How to configure `sc-launch.sh` (`SC_VIRTUAL_CABLE`), Lutris, OBS Studio (`Audio Output Capture` vs `Desktop Audio`), and `lug-wine-experimental` `winepulse.so` build/smoke-test guardrails.
   - Step-by-step instructions for listening on physical speakers vs. headphones both while streaming (via `Virtual_Speaker_Loopback` / `pavucontrol`) and during normal non-streaming play.

---

## Related Directories in `.agents/references/`

- [**`notes/`**](../notes/README.md): Operational notes, troubleshooting guides, and submodule reference details.
- [**`plans/`**](../plans/README.md): Architectural plans for GLIBC 2.35 compatibility, skills, and MCP server integration.
