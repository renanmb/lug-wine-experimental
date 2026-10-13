# LUG Helper Runner Deployment & Execution Guide

This document explains how to deploy custom-compiled **LUG Wine runners** (such as our GLIBC 2.35-compatible builds) into the **LUG Helper** environment and how to execute Star Citizen with the new runner.

---

## 1. Deploying the Runner into LUG Helper

### Manual Deployment Steps

To manually deploy the compiled Wine runner archive into the local `lug-helper` repository, run the following commands on your system:

```bash
# 1. Create the destination directory inside lug-helper's runners folder
mkdir -p /home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/lug-wine-tkg-custom-2.35

# 2. Extract the compiled build artifact into the runners folder
tar -xzf /workspaces/lug-wine-experimental/output/lug-wine-*.tar.gz \
    -C /home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/lug-wine-tkg-custom-2.35 \
    --strip-components=1
```

> [!NOTE]
> If extracting an archive that already contains a top-level directory (e.g. `lug-wine-tkg-staging-experimental-git-11.19-1/`), you can extract directly into `runners/`:
> ```bash
> tar -xzf /workspaces/lug-wine-experimental/output/lug-wine-*.tar.gz \
>     -C /home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/
> ```

### Additional Game & Lutris Destinations

LUG Helper and Lutris search specific standard directories for installed runners. To ensure seamless detection across all tools:

```bash
# Deploy to Star Citizen game prefix runners directory
mkdir -p ~/Games/star-citizen/runners
tar -xzf /workspaces/lug-wine-experimental/output/lug-wine-*.tar.gz \
    -C ~/Games/star-citizen/runners/

# Deploy to Lutris Wine runners directory
mkdir -p ~/.local/share/lutris/runners/wine
tar -xzf /workspaces/lug-wine-experimental/output/lug-wine-*.tar.gz \
    -C ~/.local/share/lutris/runners/wine/
```

### Automated Deployment Script

An automated script is provided in this repository:
[`deploy-to-lug-helper.sh`](file:///workspaces/lug-wine-experimental/deploy-to-lug-helper.sh)

Run it from the workspace root:
```bash
./deploy-to-lug-helper.sh
```
This script:
1. Validates the SHA256 checksum of the latest archive in [`output/`](file:///workspaces/lug-wine-experimental/output/).
2. Deploys the runner into `/home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/`.
3. Deploys to `~/Games/star-citizen/runners/` and `~/.local/share/lutris/runners/wine/`.
4. Updates `wine_path` in `~/Games/star-citizen/sc-launch.sh`.
5. Verifies binary execution (`wine --version`).

---

## 2. Running the New Runner via LUG Helper

### Method 1: Interactive LUG Helper Menu (GUI or Terminal)

From the `lug-helper` repository directory:

```bash
cd /home/tarfy/Documents/GitHub/renanmb/lug-helper
./lug-helper.sh
```

1. **Verify / Select Active Runner**:
   - Select **Manage Wine Runners** (`-m`).
   - The deployed runner will be listed among installed runners (and marked as `[in-use]`).
2. **Test Wine Configuration**:
   - Select **Open Wine prefix configuration** (`-c`) to launch `winecfg` using this runner.
3. **Launch the Game / RSI Launcher**:
   - Select **Install / Update RSI Launcher** or launch directly via your desktop shortcut created by LUG Helper.

> [!IMPORTANT]
> In [`lug-helper.sh`](file:///home/tarfy/Documents/GitHub/renanmb/lug-helper/lug-helper.sh), ensure `LUG Experimental` is configured with `required_glibc="2.35"` (lines 1388–1390) so that Ubuntu 22.04 systems pass the GLIBC verification checks without warnings or blocks.

---

### Method 2: Direct Execution via `sc-launch.sh` (Recommended)

LUG Helper configures and maintains the launch script at [`~/Games/star-citizen/sc-launch.sh`](file:///home/tarfy/Games/star-citizen/sc-launch.sh).

#### 1. Verify Active Runner in Launch Script
Inspect line 49 of `sc-launch.sh`:
```bash
export wine_path="/home/tarfy/Games/star-citizen/runners/lug-wine-tkg-staging-experimental-git-11.19-1/bin"
```

To test the runner environment interactively:
```bash
~/Games/star-citizen/sc-launch.sh shell
```
Inside the subshell:
```bash
wine --version
# Output: wine-11.19.r0.g766285c4 ( TkG Staging )
exit
```

#### 2. Open Wine Configuration
```bash
~/Games/star-citizen/sc-launch.sh config
```

#### 3. Open Controller / Joystick Configuration
```bash
~/Games/star-citizen/sc-launch.sh controllers
```

#### 4. Launch Star Citizen
```bash
~/Games/star-citizen/sc-launch.sh
```

---

### Method 3: Lutris Launcher Integration

If launching Star Citizen through Lutris:
1. Open **Lutris**.
2. Right-click the **Star Citizen** game banner → Select **Configure**.
3. Navigate to **Runner options**.
4. In **Wine version**, select:
   `lug-wine-tkg-staging-experimental-git-11.19-1` (or your custom runner folder name).
5. Save and launch.

---

## 3. Verification & Troubleshooting

- **Check GLIBC compatibility of deployed runner**:
  ```bash
  .agents/skills/glibc-compatibility-auditor/scripts/audit_glibc.sh \
      /home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/lug-wine-tkg-custom-2.35
  ```
- **Check Wine prefix bootstrap & Star Citizen patches**:
  ```bash
  .agents/skills/eac-and-prefix-verifier/scripts/verify_prefix.sh \
      /home/tarfy/Documents/GitHub/renanmb/lug-helper/runners/lug-wine-tkg-custom-2.35
  ```
