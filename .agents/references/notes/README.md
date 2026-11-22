# Reference Notes Index

This directory contains technical notes, operational guides, and deployment workflows for LUG Wine and LUG Helper integration.

---

## Available Notes

1. [**`lug_helper_runner_deployment_and_execution.md`**](./lug_helper_runner_deployment_and_execution.md):
   - Instructions for deploying custom-compiled LUG Wine runners into `lug-helper/runners/`, `~/Games/star-citizen/runners/`, and Lutris.
   - Exact extraction and directory setup commands.
   - Guide on executing and testing the runner through LUG Helper (`lug-helper.sh`), `sc-launch.sh`, and Lutris.

2. [**`star_citizen_graphics_vulkan_and_launch_troubleshooting.md`**](./star_citizen_graphics_vulkan_and_launch_troubleshooting.md):
   - Troubleshooting for `sc-launch.sh` launch failures and DXVK device filtering.
   - Explanation and resolution of Star Citizen native Vulkan vs DirectX 11 (DXVK) crashes (`Vulkan API version < 1.2`).
   - Resolution for settings reset crash loops (`GraphicsSettings.json` vs `attributes.xml`).
   - Configuration steps for custom resolutions (e.g., 2560×1440 Windowed mode).
   - Mouse capture behavior and optional confinement configuration in Wine.
   - Screenshot-based visual glitch debugging workflow and target folder (`/home/tarfy/Games/star-citizen/screenshots/`).

3. [**`repository_structure_and_submodules.md`**](./repository_structure_and_submodules.md):
   - Overview of the repository architecture, build presets, and fork purpose (Ubuntu 22.04 / GLIBC 2.35 support).
   - Detailed breakdown of `patches/`, `vkd3d-proton/`, and `wine-tkg-git/`.
   - Explanation of how Git submodules (`patches`, `wine-tkg-git`) and Git-ignored clones (`vkd3d-proton`) are tracked, synced, and handled in GitHub.
