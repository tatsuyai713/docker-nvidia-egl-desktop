# docker-selkies-egl-desktop

**[日本語版 (Japanese)](README_ja.md)**

## Quick Start (Devcontainer)

Get up and running on your local workstation in minutes.  
This fork re-packages the original Selkies EGL Desktop (which targets Kubernetes clusters) into a friendly Devcontainer-style workflow for individual developers.

```bash
# 1) (Optional) pull prebuilt base image
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04

# 2) Build a user image (English)
./build-user-image.sh

# 2b) Build a user image (Japanese)
./build-user-image.sh JP

# 3) Start container (Selkies, software rendering)
./start-container.sh

# 4) Start container with NVIDIA GPUs (Selkies)
./start-container.sh --gpu nvidia --all

# 5) Start container with KasmVNC (NVIDIA, clipboard support)
./start-container.sh --gpu nvidia --all --vnc-type kasm

# 6) Start container with noVNC (NVIDIA, with clipboard support)
./start-container.sh --gpu nvidia --all --vnc-type novnc

# 7) Start container with noVNC using short option (Intel)
./start-container.sh --gpu intel -v novnc

# 8) Start container with Xorg (Intel, for Vulkan support)
./start-container.sh --gpu intel --xorg
```


Originally, Selkies EGL Desktop is a Kubernetes-centric remote desktop platform (multi-tenant, GPU scheduling, etc.).  
This fork focuses on *local* use: a reproducible Devcontainer that runs the same KDE desktop through Selkies/KasmVNC, with tooling and documentation tailored for single-user development machines.

---

## 🚀 Key Improvements in This Fork

This repository is an enhanced fork oriented around Devcontainer usage. We kept the upstream streaming stack, but streamlined everything needed to spin up the desktop quickly on your own PC (matching host UID/GID, local password prompts, multi-language docs, etc.).

### Architecture Improvements

- **🏗️ Two-Stage Build System:** Split into base (5-10 GB, pre-built) and user images (~100 MB, 1-2 min build)
  - Base image contains all system packages and desktop environment
  - User image adds your specific user with matching UID/GID
  - No more 30-60 minute builds for every user!

- **🔒 Non-Root Container Execution:** Containers run with user privileges by default
  - Removed all `fakeroot` hacks and privilege escalation workarounds
  - Proper permission separation between system and user operations
  - Sudo access available when needed for specific operations

- **📁 Automatic UID/GID Matching:** File permissions work seamlessly
  - User image matches your host UID/GID automatically
  - Mounted host directories have correct ownership
  - No more "permission denied" errors on shared folders

### User Experience Enhancements

- **🔐 Secure Password Management:** Interactive password input during build
  - Hidden password entry (no plain text in commands)
  - Confirmation prompt to prevent typos
  - Passwords stored securely in the image

- **💻 Ubuntu Desktop Standard Environment:** Full `.bashrc` configuration
  - Colored prompt with Git branch detection
  - History optimization (ignoredups, append mode, timestamps)
  - Useful aliases (ll, la, grep colors, etc.)
  - Matches Ubuntu Desktop terminal experience exactly

- **🎮 Flexible GPU Selection:** Required command argument for clarity
  - `all` - Use all available GPUs
  - `none` - Software rendering (no GPU)
  - `0,1` - Specific GPU devices
  - Prevents accidental GPU allocation

- **🖥️ Triple Display Modes:** Choose your streaming protocol
  - **Selkies GStreamer (default):** WebRTC with low latency, built-in audio/video streaming, better for gaming
  - **KasmVNC:** VNC over WebSocket with kclient audio support, better compatibility, works without GPU, clipboard and bidirectional audio (speaker/microphone) support
  - **noVNC:** Basic VNC with host audio passthrough (audio output only via host PulseAudio), clipboard support
  - Switch with `--vnc-type` or `-v` argument

- **🖥️ Dynamic Resolution Adjustment:** In Selkies and KasmVNC modes, resolution automatically adjusts to match the client browser size.

- **🖥️ X Server Options:** Choose X server type
  - **Xvfb (default):** Virtual X server with VirtualGL hardware acceleration, high compatibility
  - **Xorg:** Real X server with direct hardware acceleration (use `--xorg` option)
  - Both support hardware acceleration via VirtualGL or direct GPU access

- **🔐 SSL Certificate Management:** Automated HTTPS setup
  - Interactive certificate generation script
  - Auto-detection from `ssl/` folder
  - Priority system: ssl/ folder → environment variables → HTTP fallback

### Developer Experience

- **📦 Version Pinning:** Reproducible builds guaranteed
  - VirtualGL 3.1.4, KasmVNC 1.4.0, Selkies 1.6.2
  - NVIDIA VAAPI 0.0.14, RustDesk 1.4.4
  - No more "it worked yesterday" issues

- **🛠️ Complete Management Scripts:** Shell scripts for all operations
  - `build-user-image.sh` - Build with password prompt
  - `start-container.sh [--gpu <type>] [--vnc-type <type> | -v <type>]` - Start with GPU selection and VNC type
  - `stop/restart/logs/shell-container.sh` - Lifecycle management
  - `commit-container.sh` - Save your changes
  - `generate-ssl-cert.sh` - SSL certificate generator

- **👥 Multi-User Support:** Each user gets isolated environment
  - Image names include username: `devcontainer-ubuntu-egl-desktop-{username}:24.04`
  - Container names include username: `devcontainer-egl-desktop-{username}`
  - Each user builds their own image with their UID/GID
  - No conflicts when multiple users on same host

- **🔧 Quality of Life Features:**
  - KasmVNC auto-connects with scaling enabled by default
  - Host home mounted at `~/host_home` for easy access
  - Container hostname set to `$(hostname)-Container`
  - Detailed Japanese documentation (SCRIPTS.md)

- **🌐 Multi-Language Support:** Japanese language environment available
  - Pass `JP` argument during build for Japanese input (Mozc)
  - Automatic timezone (Asia/Tokyo) and locale (ja_JP.UTF-8) configuration
  - RIKEN mirror repository for faster downloads in Japan
  - fcitx input method framework included
  - US/English remains the default

- **⌨️ Automatic Keyboard Detection:** Host keyboard layout auto-configured
  - Reads from `/etc/default/keyboard` (system default)
  - Falls back to `setxkbmap -query` (current X session)
  - Supports Japanese (jp106), US, UK, German, French, and more
  - Works with both Selkies and KasmVNC modes
  - Manual override available with `KEYBOARD_LAYOUT` environment variable

- **🌐 Chrome Sandbox Permanent Fix:** Chrome runs properly in containers
  - Wrapper script in `/usr/local/bin` ensures `--no-sandbox` flag
  - Survives Chrome package updates without manual intervention
  - No need for user scripts or manual fixes

- **🖥️ Desktop Shortcuts:** Standard desktop environment experience
  - Home and Trash icons automatically created
  - XDG user directories configured (Desktop, Downloads, Documents, etc.)
  - Consistent experience across all language settings

### Why This Fork?

| Original Project | This Fork |
|-----------------|-----------|
| Pull-ready image | Local build (1-2 min) |
| Root container | User-privilege container |
| Manual UID/GID setup | Automatic matching |
| Password in command | Interactive secure input |
| Generic bash | Ubuntu Desktop bash |
| GPU auto-detected | GPU explicitly selected |
| Version drift | Version pinned |
| Manual SSL setup | Auto-detection + generator |
| Single user focused | Multi-user optimized |
| English only | Multi-language (EN/JP) |

---

## Quick Start

```bash
# 1. Build your user image (password will be prompted)
./build-user-image.sh              # English environment (default)
./build-user-image.sh JP           # Japanese environment with Mozc input

# 2. Generate SSL certificate (optional, for HTTPS)
./generate-ssl-cert.sh

# 3. Start the container
./start-container.sh                      # Software rendering (no GPU), Selkies mode
./start-container.sh --gpu nvidia --all   # With all GPUs (NVIDIA), Selkies mode
./start-container.sh --gpu intel          # With Intel integrated GPU, Selkies mode
./start-container.sh --gpu amd            # With AMD GPU, Selkies mode
./start-container.sh --gpu nvidia --all --vnc-type kasm      # KasmVNC mode with NVIDIA GPUs (clipboard supported)
./start-container.sh --gpu intel --vnc-type novnc    # noVNC mode with Intel GPU (clipboard supported)
./start-container.sh --gpu nvidia --num 0 --vnc-type kasm              # NVIDIA GPU 0 with KasmVNC (clipboard supported)
./start-container.sh --gpu nvidia --all --vnc-type novnc     # noVNC mode with NVIDIA GPUs (clipboard supported)
# Note: Default is software rendering if --gpu not specified
# Note: Keyboard layout is auto-detected from your host system

# 4. Access via browser
# → http://localhost:8080 (or https://localhost:8080 if HTTPS enabled)

# 5. Save your changes (IMPORTANT before removing container!)
./commit-container.sh              # Save container state to image
./commit-container.sh restart --gpu nvidia --all  # Save and restart with all GPUs

# 6. Stop the container
./stop-container.sh                # Stop (container persists, can restart)
./stop-container.sh rm             # Stop and remove (only after commit!)

# 7. Switch display mode (requires recreation)
./commit-container.sh              # Save changes first!
./stop-container.sh rm             # Remove container
./start-container.sh --gpu intel --vnc-type kasm # Recreate with KasmVNC mode
```

That's it! 🎉

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Two-Stage Build System](#two-stage-build-system)
- [Installation](#installation)
- [Usage](#usage)
- [Scripts Reference](#scripts-reference)
- [Configuration](#configuration)
- [HTTPS/SSL](#httpsssl)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## Prerequisites

- **Docker** 19.03 or later
- **GPU** (optional, for hardware acceleration)
  - **NVIDIA GPU** ✅ Tested
    - Driver version 450.80.02 or later
    - Maxwell generation or newer
    - NVIDIA Container Toolkit installed
  - **Intel GPU** ✅ Tested
    - Intel integrated graphics (HD Graphics, Iris, Arc)
    - Quick Sync Video support
    - VA-API drivers included in container
    - **Host setup required** (see below for details)
  - **AMD GPU** ⚠️ Partially Tested
    - Radeon graphics with VCE/VCN encoder
    - VA-API drivers included in container
    - **Host setup required** (see below for details)
- **Linux Host** (Ubuntu 20.04+ recommended)

---

## Two-Stage Build System

This project uses a two-stage build approach for fast setup and proper file permissions:

```
┌─────────────────────────┐
│   Base Image (5-10 GB)  │  ← Built by maintainers, pull from registry
│  • All system packages  │
│  • Desktop environment  │
│  • Pre-installed apps   │
└────────────┬────────────┘
             │
             ↓ builds from
┌────────────┴────────────┐
│ User Image (~100 MB)    │  ← You build this (1-2 minutes)
│  • Your username        │
│  • Your UID/GID         │
│  • Your password        │
└─────────────────────────┘
```

**Benefits:**

- ✅ **Fast Setup:** No 30-60 minute build wait
- ✅ **Proper Permissions:** Files match your host UID/GID
- ✅ **Multi-User:** Each user gets their own isolated environment
- ✅ **Easy Updates:** Pull new base image, rebuild user image

**Why UID/GID Matching Matters:**

- When you mount host directories (like `$HOME`), files need matching ownership
- Without matching UID/GID, you get permission errors
- The user image automatically matches your host credentials

---

## Intel/AMD GPU Host Setup

If you plan to use hardware encoding (VA-API) with Intel or AMD GPUs, host-side setup is required:

### 1. Add User to video/render Groups

For the container to access GPU devices (`/dev/dri/*`), the host user must be a member of the `video` and `render` groups:

```bash
# Add user to video/render groups
sudo usermod -aG video,render $USER

# Logout and re-login or reboot to apply group changes
# Verify:
groups
# Confirm output includes "video" and "render"
```

### 2. Install VA-API Drivers (Intel)

For Intel GPU hardware encoding:

```bash
# Install VA-API tools and Intel driver
sudo apt update
sudo apt install vainfo intel-media-va-driver-non-free

# Verify installation (check for H.264 encoding support):
vainfo
# Confirm output includes "VAProfileH264Main : VAEntrypointEncSlice" etc.
```

### 3. Install VA-API Drivers (AMD)

For AMD GPU hardware encoding:

```bash
# Install VA-API tools and AMD driver
sudo apt update
sudo apt install vainfo mesa-va-drivers

# Verify installation:
vainfo
# Confirm output includes "VAProfileH264Main : VAEntrypointEncSlice" etc.
```

**Notes:**
- NVIDIA GPUs do not require this setup
- If VA-API works correctly on the host, it will automatically work in the container
- Always logout/re-login or reboot after group changes

---

## Installation

### 1. Pull Base Image

The base image is pre-built and available from the registry:

```bash
# Automatically pulled when building user image
# Or pull manually:
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:latest
# Or specific version:
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04
```

### 2. Build User Image

This creates your personal image with matching UID/GID:

```bash
# English (default)
./build-user-image.sh
# Japanese
./build-user-image.sh JP
```

The build will prompt for a password (entered twice) and completes in about 1–2 minutes.

**Optional: automation / customization examples**

```bash
# Use a specific base image version
BASE_IMAGE_TAG=v1.0 ./build-user-image.sh

# Provide password via environment (automation)
USER_PASSWORD=mysecurepassword ./build-user-image.sh

# Build without cache
NO_CACHE=true ./build-user-image.sh
```

**Advanced: custom build for another user**

```bash
docker build \
  --build-arg BASE_IMAGE=ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04 \
  --build-arg USER_NAME=johndoe \
  --build-arg USER_UID=1001 \
  --build-arg USER_GID=1001 \
  --build-arg USER_PASSWORD=johnspassword \
  -f files/Dockerfile.user \
  -t devcontainer-ubuntu-egl-desktop-johndoe:24.04 \
  .
```

---

## Usage

### Starting the Container

The `start-container.sh` script uses optional arguments for GPU and display mode:

```bash
# Syntax: ./start-container.sh [--gpu <type>] [--vnc-type <type> | -v <type>]
# Default: Software rendering with Selkies if no options specified

# NVIDIA GPU options:
./start-container.sh --gpu nvidia --all            # Use all available NVIDIA GPUs
./start-container.sh --gpu nvidia --num 0                 # Use NVIDIA GPU 0 only
./start-container.sh --gpu nvidia --num 0,1            # Use NVIDIA GPU 0 and 1

# Intel/AMD GPU options:
./start-container.sh --gpu intel          # Use Intel integrated GPU (Quick Sync Video)
./start-container.sh --gpu amd               # Use AMD GPU (VCE/VCN)

# Software rendering:
./start-container.sh                      # No GPU (software rendering, default)
./start-container.sh --gpu none           # Explicitly specify no GPU

# Display mode options:
./start-container.sh --gpu nvidia --all            # Selkies GStreamer (WebRTC, default)
./start-container.sh --gpu intel --vnc-type kasm       # KasmVNC (VNC over WebSocket, clipboard support) with Intel GPU
./start-container.sh --gpu nvidia --all --vnc-type novnc         # noVNC (with clipboard support) with NVIDIA GPUs
./start-container.sh --vnc-type novnc                   # noVNC with software rendering

# Keyboard layout override (auto-detected by default):
KEYBOARD_LAYOUT=jp ./start-container.sh --gpu intel        # Japanese keyboard
KEYBOARD_LAYOUT=us ./start-container.sh --gpu intel    # US keyboard
KEYBOARD_LAYOUT=de KEYBOARD_MODEL=pc105 ./start-container.sh --gpu nvidia --all  # German keyboard
```

**UID-Based Port Assignment (Multi-User Support):**

Ports are automatically assigned based on your user ID to enable multiple users on the same host:

- **HTTPS Port**: `10000 + UID` (e.g., UID 1000 → port 11000)
- **TURN Port**: `13000 + UID` (e.g., UID 1000 → port 14000)
- **UDP Range**: `40000 + (UID - 1000) × 200` to `+100` (e.g., UID 1000 → 40000-40100)

Access via: `http://localhost:${HTTPS_PORT}` (e.g., `http://localhost:11000` for UID 1000)

**Remote Access (LAN/WAN):**

TURN server is **enabled by default** for Selkies mode, allowing remote access without additional options:

```bash
./start-container.sh --gpu intel          # TURN server automatically enabled
```

The TURN server enables WebRTC connection for remote access:
- **TURN Port**: UID-based (e.g., port 14000 for UID 1000)
- **UDP Range**: UID-based (e.g., 40000-40100 for UID 1000)
- Auto-detects LAN IP address for proper routing
- Not required for KasmVNC mode (VNC doesn't use WebRTC)

Access from remote PC: `https://<host-ip>:<https-port>` (e.g., `https://192.168.1.100:11000` for UID 1000)

⚠️ **Note:** Container startup may take longer due to UDP port range mapping (~100 ports per user).

**Multi-User Support:**

Multiple users can run containers simultaneously on the same host without port conflicts:
- Each user gets unique HTTPS, TURN, and UDP port ranges based on their UID
- Example: User A (UID 1000) uses ports 11000, 14000, 40000-40100
- Example: User B (UID 1001) uses ports 11001, 14001, 40200-40300

**Container Features:**

- **Container persistence:** Not removed when stopped (can restart or commit changes)
- **Hostname:** Set to `$(hostname)-Container`
- **Host home mount:** Available at `~/host_home`
- **Container name:** `devcontainer-egl-desktop-{username}`
- **GPU flexibility:** NVIDIA, Intel, AMD, or software rendering
- **Auto keyboard detection:** Host keyboard layout automatically applied

**Important: Display Mode Switching**

⚠️ **Display mode (Selkies/KasmVNC) is set at container creation and cannot be changed for existing containers.**

If you need to switch between Selkies and KasmVNC:

```bash
# Method 1: Delete and recreate
./stop-container.sh rm
./start-container.sh --gpu intel --vnc-type kasm # Switch to KasmVNC

# Method 2: Commit, delete, and recreate
./commit-container.sh              # Save changes first
./stop-container.sh rm
./start-container.sh --gpu intel      # Switch to Selkies

# Method 3: Commit and auto-restart
./commit-container.sh restart --gpu intel --vnc-type kasm  # Save and switch to KasmVNC
```

The start script will detect mode mismatch and show a helpful error message with instructions.

### Common Options

```bash
# Use HTTPS
./generate-ssl-cert.sh
./start-container.sh --gpu nvidia --all

# Use a different port
HTTPS_PORT=9090 ./start-container.sh --gpu nvidia --all

# High resolution (4K)
DISPLAY_WIDTH=3840 DISPLAY_HEIGHT=2160 ./start-container.sh --gpu nvidia --all

# Foreground mode (see logs directly)
DETACHED=false ./start-container.sh --gpu nvidia --all

# Custom container name
CONTAINER_NAME=my-desktop ./start-container.sh --gpu nvidia --all
```

### Stopping the Container

```bash
# Stop container (persists for restart or commit)
./stop-container.sh

# Stop and remove container
./stop-container.sh rm
# or
./stop-container.sh remove
```

**Container Persistence:**
- By default, stopped containers persist and can be restarted
- Use `rm` option to completely remove the container
- Restart with: `./start-container.sh [--gpu <type>] [--vnc-type <type>]`

---

## Scripts Reference

### Core Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `build-user-image.sh` | Build your user-specific image | `./build-user-image.sh` or `./build-user-image.sh JP` |
| `start-container.sh` | Start the desktop container | `./start-container.sh [--gpu <type>] [--vnc-type <type>]` |
| `stop-container.sh` | Stop the container | `./stop-container.sh [rm\|remove]` |
| `generate-ssl-cert.sh` | Generate self-signed SSL certificate | `./generate-ssl-cert.sh` |

### Management Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `restart-container.sh` | Restart the container | `./restart-container.sh` |
| `logs-container.sh` | View container logs | `./logs-container.sh` |
| `shell-container.sh` | Access container shell | `./shell-container.sh` |
| `delete-image.sh` | Delete the user-specific image | `./delete-image.sh` |
| `commit-container.sh` | Save container changes to image | `./commit-container.sh [restart [gpu]]` |

For detailed Japanese documentation, see [SCRIPTS.md](SCRIPTS.md).

### Script Examples

**Viewing Logs:**

```bash
# View last 100 lines
./logs-container.sh

# Follow logs in real-time
FOLLOW=true ./logs-container.sh
```

**Accessing Shell:**

```bash
# As your user
./shell-container.sh

# As root
AS_ROOT=true ./shell-container.sh
```

**Saving Changes:**

If you've installed software or made changes in the container:

```bash
# Save container state to image
./commit-container.sh

# Save and restart automatically
./commit-container.sh restart --gpu nvidia --all      # Restart with all NVIDIA GPUs
./commit-container.sh restart --gpu intel       # Restart with Intel GPU
./commit-container.sh restart --gpu amd      # Restart with AMD GPU
./commit-container.sh restart --vnc-type kasm          # Restart with VNC mode (no GPU)

# Save with a custom tag
COMMIT_TAG=my-setup ./commit-container.sh

# Use the saved image
IMAGE_NAME=devcontainer-ubuntu-egl-desktop-$(whoami):my-setup \
  CONTAINER_NAME=my-desktop-2 \
  ./start-container.sh --gpu nvidia --all
```

**Important Notes:**

- ⚠️ **Always commit before `./stop-container.sh rm`** - Changes are lost if you remove without committing
- ✅ The image name format is `devcontainer-ubuntu-egl-desktop-{username}:24.04` for easy reusability
- ✅ Committed images persist even after container deletion
- ✅ Next startup automatically uses the committed image

**Workflow Example:**

```bash
# 1. Work in container, install software, configure settings
./shell-container.sh
# ... install packages, configure environment ...
exit

# 2. Save your changes to the image
./commit-container.sh

# 3. Stop and remove container safely (changes are saved in image)
./stop-container.sh rm

# 4. Next startup uses the committed image with all your changes
./start-container.sh --gpu intel

# 5. To switch display mode with saved changes:
./commit-container.sh restart --gpu intel --vnc-type kasm  # Save and switch to KasmVNC
```

**Deleting Image:**

```bash
# Delete your user image
./delete-image.sh

# Force delete (removes associated containers too)
FORCE=true ./delete-image.sh

# Delete a specific version
IMAGE_TAG=my-setup ./delete-image.sh

# Delete another user's image
IMAGE_NAME=devcontainer-ubuntu-egl-desktop-otheruser ./delete-image.sh
```

---

## Configuration

### Display Settings

```bash
# Resolution
DISPLAY_WIDTH=1920        # Width in pixels
DISPLAY_HEIGHT=1080       # Height in pixels
DISPLAY_REFRESH=60        # Refresh rate in Hz
DISPLAY_DPI=96            # DPI setting

./start-container.sh --gpu nvidia --all
```

### Video Encoding

```bash
# NVIDIA GPU (hardware encoding)
VIDEO_ENCODER=nvh264enc   # H.264 with NVIDIA
VIDEO_BITRATE=8000        # kbps
FRAMERATE=60              # FPS

# Software encoding (no GPU)
VIDEO_ENCODER=x264enc     # H.264 software
VIDEO_BITRATE=4000        # Lower bitrate for CPU

./start-container.sh
```

**Available encoders:**

- `nvh264enc` - NVIDIA H.264 (requires NVIDIA GPU)
- `x264enc` - Software H.264 (CPU)
- `vp8enc` - Software VP8
- `vp9enc` - Software VP9
- `vah264enc` - AMD/Intel hardware encoding

**Intel mode:** `--gpu intel` now enables VA-API hardware encoding (`vah264enc`) by default.  
Set `INTEL_FORCE_VAAPI=false` before `./start-container.sh --gpu intel` if you need to fall back to software (`x264enc`).

**AMD mode:** `--gpu amd` also uses VA-API hardware encoding by default (`LIBVA_DRIVER_NAME=radeonsi`, `vah264enc`).  
Set `AMD_FORCE_VAAPI=false` (or override `AMD_LIBVA_DRIVER`) before `./start-container.sh --gpu amd` to force software encoding.

### Checking Hardware Encoder Usage

All GPU modes:

```bash
# Confirm what Selkies is using
docker exec devcontainer-egl-desktop-$(whoami) env | grep -E 'SELKIES_ENCODER|LIBVA_DRIVER_NAME'
./logs-container.sh | grep -i encoder
```

**Intel (VA-API / Quick Sync)**

```bash
sudo apt update
sudo apt install intel-gpu-tools
sudo intel_gpu_top
```

- Run the container (`./start-container.sh --gpu intel`) and play a video or move windows.
- In `intel_gpu_top`, the `Video/0` or `VideoEnhance/0` columns should spike while encoding.
- Inside the container you can also run `vainfo | grep -i VAEntrypointEnc` to ensure the iHD driver exposes H.264 encode paths.

**AMD (VA-API / radeonsi)**

```bash
sudo apt update
sudo apt install radeontop
sudo radeontop
```

- After `./start-container.sh --gpu amd`, watch the `vce`/`vcn` usage in `radeontop` while streaming to confirm hardware encode activity.
- From inside the container you can double-check VA-API availability with `vainfo | grep -i VAEntrypointEnc`.

**NVIDIA (NVENC)**

```bash
# nvidia-smi is usually installed with the driver; if missing, install the matching utils package
sudo apt update
sudo apt install nvidia-utils-535   # replace 535 with your driver version
watch -n1 nvidia-smi dmon -s pucvmt
```

- Start Selkies in NVIDIA mode (`./start-container.sh --gpu nvidia --all`).
- `nvidia-smi dmon` (or plain `nvidia-smi`) should show non-zero encoder (ENC) utilization whenever Selkies is streaming.

### Audio Settings

**Audio Support by Display Mode:**

| Mode | Audio Output | Audio Input (Microphone) | Technology |
|------|-------------|-------------------------|------------|
| **Selkies** | ✅ Built-in | ✅ Built-in | WebRTC (browser native) |
| **KasmVNC** | ✅ kclient | ✅ kclient | WebSocket + kasmbins audio system |
| **noVNC** | ✅ Host passthrough | ❌ Not supported | Host PulseAudio mounted to container |

**Selkies Audio Configuration:**

```bash
AUDIO_BITRATE=128000      # Audio bitrate in bps (default: 128000)
./start-container.sh --gpu nvidia --all
```

**KasmVNC Audio (kclient):**

KasmVNC mode uses [LinuxServer.io's kclient](https://github.com/linuxserver/kclient) for bidirectional audio:
- Audio server runs on port 3000 (proxied via nginx)
- Uses PipeWire-Pulse with VirtualSpeaker/VirtualMic devices
- Browser-to-container audio streaming via WebSockets
- Automatic audio device configuration

```bash
./start-container.sh --gpu nvidia --all --vnc-type kasm
# Audio controls appear in the kclient web interface
```

**noVNC Audio (Host Passthrough):**

noVNC mode mounts your host PulseAudio socket for audio output:
- Container applications play audio through host speakers
- Requires PulseAudio running on host: `/run/user/$(id -u)/pulse/native`
- Read-only mount for security
- No microphone input support in this mode

```bash
./start-container.sh --gpu nvidia --all --vnc-type novnc
# Audio plays through host system automatically
```

### Keyboard Settings

**Automatic Detection (Default):**

The container automatically detects your host keyboard layout from:
1. `/etc/default/keyboard` (system default configuration) - **Priority**
2. `setxkbmap -query` (current X session) - Fallback

Supported layouts include: Japanese (jp), US (us), UK (gb), German (de), French (fr), Spanish (es), Italian (it), Korean (kr), Chinese (cn), and more.

**Manual Override:**

```bash
# Specify keyboard layout manually
KEYBOARD_LAYOUT=jp ./start-container.sh --gpu intel              # Japanese keyboard
KEYBOARD_LAYOUT=us ./start-container.sh --gpu intel              # US keyboard
KEYBOARD_LAYOUT=de ./start-container.sh --gpu intel              # German keyboard

# With keyboard model (for non-standard keyboards)
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh --gpu intel  # Japanese 106-key

# With keyboard variant
KEYBOARD_LAYOUT=us KEYBOARD_VARIANT=dvorak ./start-container.sh --gpu nvidia --all # Dvorak layout

# Full specification
KEYBOARD_LAYOUT=fr KEYBOARD_MODEL=pc105 KEYBOARD_VARIANT=azerty ./start-container.sh --gpu intel
```

**Common Keyboard Models:**
- `pc105` - Standard 105-key PC keyboard (default)
- `jp106` - Japanese 106/109-key keyboard
- `pc104` - US 104-key keyboard

**How it works:**
- Keyboard layout is set at container creation time
- Applied to both Selkies and KasmVNC modes
- Configuration uses X11 XKB (setxkbmap) and KDE keyboard settings
- Works with fcitx input method for Asian languages

### Display Mode

**Selkies GStreamer (Default):**

- WebRTC-based streaming
- Low latency, high performance
- Better for gaming and graphics
- ✅ **Audio streaming supported:** Audio is streamed to remote browser clients via WebRTC

```bash
./start-container.sh --gpu nvidia --all       # Uses Selkies by default
```

**KasmVNC:**

- VNC-based streaming over WebSocket
- Better compatibility
- Works without GPU
- ✅ **Audio supported:** Bidirectional audio (speaker + microphone) via kclient WebSocket streaming
- Clipboard support included

```bash
./start-container.sh --gpu nvidia --all --vnc-type kasm # Activates KasmVNC mode
```

---

## HTTPS/SSL

### Quick Setup with Auto-Generation

```bash
# 1. Generate SSL certificate (interactive)
./generate-ssl-cert.sh

# 2. Install the generated CA into your local trust stores (requires sudo)
sudo ./install-ca-cert.sh

# 3. Start container (auto-detects ssl/ folder)
./start-container.sh --gpu nvidia --all
```

The script will:

- Generate a self-signed certificate
- Save to `ssl/` folder by default
- Provide usage examples

Access via: <https://localhost:8080> (your browser will show a security warning)

### Trusting the Generated CA

- `generate-ssl-cert.sh` now issues a *private Certificate Authority (CA)* (`ssl/ca.crt`) and a server certificate signed by that CA.
- Run `sudo ./install-ca-cert.sh` on **every host that opens the web UI** to install the CA into:
  - `/usr/local/share/ca-certificates` (for system-wide trust)
  - The current user’s Chrome/Chromium NSS store (via `certutil` if available)
- If `certutil` is missing, install `libnss3-tools` or manually import `ssl/ca.crt` into Chrome/Firefox/Safari/Edge.
- Chrome may cache earlier invalid certs. If warnings persist, clear `localhost` from `chrome://net-internals/#hsts`, then restart the browser.
- For remote clients, copy `ssl/ca.crt` to the other machine and run `sudo ./install-ca-cert.sh` (or import it into that OS/browser manually).

### Certificate Priority

The `start-container.sh` script auto-detects certificates in this order:

1. `ssl/cert.pem` and `ssl/key.pem` (from generate-ssl-cert.sh)
2. Environment variables `CERT_PATH` and `KEY_PATH`
3. Runs without HTTPS if no certificates found

### Using Custom SSL Certificates

```bash
CERT_PATH=/path/to/cert.pem \
  KEY_PATH=/path/to/key.pem \
  ./start-container.sh --gpu nvidia --all
```

### Manual Certificate Generation

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

For production, use certificates from [Let's Encrypt](https://letsencrypt.org/).

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
./logs-container.sh

# Check if image exists
docker images | grep devcontainer-ubuntu-egl-desktop-base

# Rebuild user image
./build-user-image.sh

# Check if port is in use
sudo netstat -tulpn | grep 8080

# Use a different port
HTTPS_PORT=8081 ./start-container.sh --gpu nvidia --all
```

### GPU Not Detected

```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker can access GPU
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Use software rendering if GPU issues persist
./start-container.sh
```

### Permission Issues

```bash
# Access as root
AS_ROOT=true ./shell-container.sh

# Check user ID matches
id  # on host
./shell-container.sh  # then run 'id' inside container

# If UID/GID mismatch, rebuild user image
./delete-image.sh
./build-user-image.sh
```

### Cannot Access Web Interface

```bash
# Check container is running
docker ps

# Check nginx is running
./shell-container.sh
# Inside container: supervisorctl status

# Check firewall
sudo ufw status
sudo ufw allow 8080/tcp
```

### Services Not Starting

```bash
# Check all services
./shell-container.sh
supervisorctl status

# Restart a specific service
./shell-container.sh
supervisorctl restart nginx

# Check service logs
./logs-container.sh
```

### UID/GID Conflicts

If you get permission errors with mounted volumes:

1. Check your host UID/GID: `id -u` and `id -g`
2. Verify the image was built with the correct UID/GID
3. Rebuild the user image if necessary:

```bash
./delete-image.sh
./build-user-image.sh
```

### Keyboard Layout Issues

**Incorrect keys (e.g., @ key types 2):**

```bash
# Check detected keyboard layout
echo $KEYBOARD_LAYOUT  # Should match your system

# Verify host keyboard configuration
cat /etc/default/keyboard

# Override with correct layout
./stop-container.sh rm
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh --gpu intel
```

**For Japanese keyboards specifically:**
- Use `KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106` for 106/109-key Japanese keyboards
- Model `jp106` is critical for correct @ key placement
- Auto-detection should work if `/etc/default/keyboard` is correctly configured

**Keyboard doesn't work at all:**

```bash
# Check if setxkbmap is installed (should be in base image)
./shell-container.sh
which setxkbmap

# Manually test keyboard configuration
setxkbmap -layout jp -model jp106 -query
```

### Display Mode Issues

**Error: "Container was created with X mode, but you're trying to start it with Y mode"**

This is expected behavior. Display mode (Selkies/KasmVNC) cannot be changed for existing containers.

**Solution:**

```bash
# Option 1: Keep current mode
./start-container.sh --gpu intel  # Use the original mode

# Option 2: Save changes and recreate
./commit-container.sh          # Save changes first!
./stop-container.sh rm         # Remove container
./start-container.sh --gpu intel --vnc-type kasm  # Recreate with new mode

# Option 3: One-step commit and recreate
./commit-container.sh restart --gpu intel --vnc-type kasm
```

**Why can't I change the mode?**
- Display mode is set via environment variables at container creation (`docker run`)
- Running containers use fixed environment variables
- `docker start` on existing containers doesn't change environment variables

## Known Limitations

### Chrome hardware acceleration falls back to software

- Inside the Selkies EGL session Chrome's GPU sandbox strips the VirtualGL `LD_PRELOAD` hooks, so the GPU process fails to find a valid GL implementation (`Requested GL implementation (gl=none,angle=none)`).  
- When video playback starts Chrome automatically switches to software compositing/decoding. This is a Chromium limitation in virtualized GL pipelines and cannot be fixed with Chrome flags alone.  
- Workarounds: run Firefox inside the container, keep Chrome outside the container (accessing Selkies/KasmVNC from the host), or switch to KasmVNC mode if you must use Chrome with GPU acceleration.

### Safari loops on the Basic Auth dialog

- Selkies enables HTTP Basic authentication by default. Safari does not resend credentials when upgrading to WebSocket/WebRTC endpoints (`/ws`, `/webrtc/signalling`), so each 401 response triggers the login dialog again and the page never loads.  
- Workarounds: disable Basic auth (`SELKIES_ENABLE_BASIC_AUTH=false` before `start-container.sh`), use Chrome/Firefox/Edge, or place Selkies behind another reverse proxy that handles authentication.

### Vulkan apps cannot present frames

- Selkies runs the KDE desktop under Xvfb + VirtualGL; there is no real Xorg/DRI3 backend inside the container. Vulkan applications therefore cannot find a graphics+present queue combination and exit with `No DRI3 support detected`.  
- Vulkan's presentation requires DRI3/DRM and a real display server, which is outside the scope of the Selkies EGL pipeline.  
- **NVIDIA GPUs**: Vulkan works when using NVIDIA container toolkit (nvidia-docker), as the drivers provide proper Vulkan ICD and presentation support.  
- **Intel/AMD GPUs**: Vulkan presentation fails in containers regardless of using Xvfb or Xorg, due to integrated graphics sharing host Xorg and limited DRM access.  
- Workarounds: run Vulkan workloads directly on the host, use NVIDIA GPUs with proper drivers, or avoid Vulkan in containerized environments.

### Rebuilding Images

```bash
# Rebuild user image without cache
NO_CACHE=true ./build-user-image.sh

# Pull latest base image
docker pull ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:latest
./build-user-image.sh
```

---

## Advanced Topics

### Docker Compose

If you prefer docker-compose:

```bash
# Start
USER_IMAGE=devcontainer-ubuntu-egl-desktop-$(whoami):24.04 \
  docker-compose -f docker-compose.user.yml up -d

# Stop
docker-compose -f docker-compose.user.yml down
```

### Environment Variables Reference

<details>
<summary>Click to expand full environment variables list</summary>

#### Container Settings

- `CONTAINER_NAME` - Container name (default: `devcontainer-egl-desktop-$(whoami)`)
- `IMAGE_NAME` - Image to use (default: `devcontainer-ubuntu-egl-desktop-$(whoami):24.04`)
- `DETACHED` - Run in background (default: `true`)

#### Display

- `DISPLAY_WIDTH` - Width in pixels (default: `1920`)
- `DISPLAY_HEIGHT` - Height in pixels (default: `1080`)
- `DISPLAY_REFRESH` - Refresh rate in Hz (default: `60`)
- `DISPLAY_DPI` - DPI setting (default: `96`)

#### Authentication

- Password is set during image build (no runtime configuration needed)
- `SELKIES_BASIC_AUTH_PASSWORD` - Web interface password (can be set at runtime if needed)

#### Video

- `VIDEO_ENCODER` - Video encoder (default: `nvh264enc`)
- `VIDEO_BITRATE` - Video bitrate in kbps (default: `8000`)
- `FRAMERATE` - Frame rate (default: `60`)

#### Audio

- `AUDIO_BITRATE` - Audio bitrate in bps (default: `128000`)

#### HTTPS/SSL

- `ENABLE_HTTPS` - Enable HTTPS (default: auto-detected from ssl/ folder)
- `SELKIES_HTTPS_CERT` - Path to SSL certificate (inside container)
- `SELKIES_HTTPS_KEY` - Path to SSL private key (inside container)
- `CERT_PATH` - Host path to certificate file (for mounting)
- `KEY_PATH` - Host path to key file (for mounting)

#### GPU

- GPU selection is via command argument: `all`, `none`, or device numbers
- `ENABLE_NVIDIA` - Deprecated, use command argument instead

#### Network

- `HTTPS_PORT` - Host port to bind (default: `8080`)

</details>

### GPU Support

**NVIDIA GPUs:**

- Requires driver version 450.80.02 or later
- Maxwell generation or newer
- NVENC support for hardware encoding

**AMD/Intel GPUs:**

```bash
VIDEO_ENCODER=vah264enc ./start-container.sh --gpu intel
```

**Software Rendering (No GPU):**

```bash
VIDEO_ENCODER=x264enc ./start-container.sh
```

### Mounting Additional Volumes

Edit `start-container.sh` and add volume mounts:

```bash
CMD="${CMD} -v /path/on/host:/path/in/container"
```

### Multiple Users on Same Host

Each user should build their own image:

```bash
# User 1
USER_PASSWORD=user1pass ./build-user-image.sh

# User 2 (on same machine)
USER_PASSWORD=user2pass ./build-user-image.sh
```

Each will get their own tagged image matching their username and UID/GID:
- Image: `devcontainer-ubuntu-egl-desktop-{username}:24.04`
- Container: `devcontainer-egl-desktop-{username}`

---

## Project Structure

```
docker-selkies-egl-desktop/
├── build-user-image.sh           # Build user-specific image
├── start-container.sh             # Start container
├── stop-container.sh              # Stop container
├── restart-container.sh           # Restart container
├── logs-container.sh              # View logs
├── shell-container.sh             # Access shell
├── delete-image.sh                # Delete user image
├── commit-container.sh            # Save changes
├── generate-ssl-cert.sh           # Generate SSL certificate
├── docker-compose.yml             # Docker Compose config (base image)
├── docker-compose.user.yml        # Docker Compose config (user image)
├── egl.yml                        # Alternative compose config
├── ssl/                           # SSL certificates (auto-detected)
│   ├── cert.pem
│   └── key.pem
└── files/                         # System files
    ├── Dockerfile.base            # Base image definition
    ├── Dockerfile.user            # User image definition
    ├── entrypoint.sh              # Container entrypoint
    ├── kasmvnc-entrypoint.sh      # KasmVNC setup
    ├── selkies-gstreamer-entrypoint.sh  # Selkies setup
    ├── supervisord.conf           # Supervisor config
    └── build-base-image.sh        # Base image builder (for maintainers)
```

---

## Version Pinning

External dependencies are pinned to specific versions for reproducible builds:

- **VirtualGL:** 3.1.4
- **KasmVNC:** 1.4.0
- **Selkies GStreamer:** 1.6.2
- **NVIDIA VAAPI Driver:** 0.0.14
- **RustDesk:** 1.4.4

These are defined in [files/Dockerfile.base](files/Dockerfile.base) as build arguments.

---

## Building Base Image (For Maintainers)

If you need to build the base image (usually only for project maintainers):

```bash
cd files
./build-base-image.sh
```

Or manually:

```bash
docker build \
    -f files/Dockerfile.base \
    -t ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base:24.04 \
    .
```

The base image build takes 30-60 minutes and requires:

- Fast internet connection (downloads ~5-10 GB)
- 20+ GB free disk space
- Docker with BuildKit enabled

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

For base image changes, test thoroughly and update version numbers as needed.

---

## License

**Main Project:**

Mozilla Public License 2.0

See [LICENSE](LICENSE) file for details.

**Third-Party Components:**

This project uses the following third-party open source software:

- **kclient** ([LinuxServer.io/kclient](https://github.com/linuxserver/kclient))
  - Used in KasmVNC mode for audio streaming functionality
  - License: GNU General Public License v3.0 or later (GPL-3.0-or-later)
  - Copyright: LinuxServer.io team

For a complete list of third-party software and their licenses, see [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

---

## Related Projects

- [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) - Better performance with dedicated X11 server
- [Selkies GStreamer](https://github.com/selkies-project/selkies-gstreamer) - WebRTC streaming component
- [KasmVNC](https://github.com/kasmtech/KasmVNC) - VNC server with web interface

---

## Credits

### Original Project

- **Selkies Project:** [github.com/selkies-project](https://github.com/selkies-project)
- **Original Maintainers:** [@ehfd](https://github.com/ehfd), [@danisla](https://github.com/danisla)
- **Original Repository:** [docker-selkies-egl-desktop](https://github.com/selkies-project/docker-selkies-egl-desktop)

### This Fork

- **Enhancements:** Two-stage build system, non-root execution, UID/GID matching, secure password management, management scripts, SSL automation, version pinning, multi-user support
- **Maintainer:** [@tatsuyai713](https://github.com/tatsuyai713)
