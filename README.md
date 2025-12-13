# docker-selkies-egl-desktop

KDE Plasma Desktop container designed for Kubernetes, supporting OpenGL EGL and GLX, Vulkan for NVIDIA GPUs through WebRTC and HTML5, providing an open-source remote cloud/HPC graphics or game streaming platform.

---

## 🚀 Key Improvements in This Fork

This repository is an enhanced fork of the original Selkies EGL Desktop project, with significant improvements for security, usability, and multi-user environments:

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

- **🖥️ Dual Display Modes:** Choose your streaming protocol
  - **Selkies GStreamer (default):** WebRTC with low latency, better for gaming
  - **KasmVNC:** VNC over WebSocket, better compatibility, works without GPU
  - Switch with simple `vnc` argument

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
  - `start-container.sh <gpu> [vnc]` - Start with GPU selection
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
  - Set `IN_LOCALE=JP` during build for Japanese input (Mozc)
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
| 30-60 minute build | 1-2 minute build |
| Root container | User-privilege container |
| Manual UID/GID setup | Automatic matching |
| Password in command | Interactive secure input |
| Generic bash | Ubuntu Desktop bash |
| GPU auto-detected | GPU explicitly selected |
| Version drift | Version pinned |
| Single streaming mode | Dual mode (Selkies/KasmVNC) |
| Manual SSL setup | Auto-detection + generator |
| Single user focused | Multi-user optimized |
| English only | Multi-language (EN/JP) |

---

## Quick Start

```bash
# 1. Build your user image (password will be prompted)
./build-user-image.sh              # English environment (default)
IN_LOCALE=JP ./build-user-image.sh # Japanese environment with Mozc input

# 2. Generate SSL certificate (optional, for HTTPS)
./generate-ssl-cert.sh

# 3. Start the container
./start-container.sh                      # Software rendering (no GPU), Selkies mode
./start-container.sh --gpu all            # With all GPUs (NVIDIA), Selkies mode
./start-container.sh -g intel             # With Intel integrated GPU, Selkies mode
./start-container.sh --gpu amd            # With AMD GPU, Selkies mode
./start-container.sh --gpu all --vnc      # KasmVNC mode with NVIDIA GPUs
./start-container.sh -g intel -v          # KasmVNC mode with Intel GPU
./start-container.sh -g 0 -v              # NVIDIA GPU 0 with KasmVNC
# Note: Default is software rendering if --gpu not specified
# Note: Keyboard layout is auto-detected from your host system

# 4. Access via browser
# → http://localhost:8080 (or https://localhost:8080 if HTTPS enabled)

# 5. Save your changes (IMPORTANT before removing container!)
./commit-container.sh              # Save container state to image
./commit-container.sh restart all  # Save and restart with all GPUs

# 6. Stop the container
./stop-container.sh                # Stop (container persists, can restart)
./stop-container.sh rm             # Stop and remove (only after commit!)

# 7. Switch display mode (requires recreation)
./commit-container.sh              # Save changes first!
./stop-container.sh rm             # Remove container
./start-container.sh intel vnc     # Recreate with KasmVNC mode
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
./build-user-image.sh
```

This will:

- Pull the pre-built base image (if not already available)
- Prompt you to set a password (input is hidden for security)
- Create a user-specific image matching your host UID/GID
- Take about 1-2 minutes

**Password Setup:**

- You'll be asked to enter a password twice for confirmation
- The password is securely stored in the image during build
- No need to specify password when starting containers

**Environment Variables:**

```bash
# Use a specific base image version
BASE_IMAGE_TAG=v1.0 ./build-user-image.sh

# Set password via environment (for automation)
USER_PASSWORD=mysecurepassword ./build-user-image.sh

# Build without cache
NO_CACHE=true ./build-user-image.sh

# Build for a different user
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
# Syntax: ./start-container.sh [--gpu <type>] [--vnc]
# Default: Software rendering with Selkies if no options specified

# NVIDIA GPU options:
./start-container.sh --gpu all            # Use all available NVIDIA GPUs
./start-container.sh -g 0                 # Use NVIDIA GPU 0 only
./start-container.sh --gpu 0,1            # Use NVIDIA GPU 0 and 1

# Intel/AMD GPU options:
./start-container.sh --gpu intel          # Use Intel integrated GPU (Quick Sync Video)
./start-container.sh -g amd               # Use AMD GPU (VCE/VCN)

# Software rendering:
./start-container.sh                      # No GPU (software rendering, default)
./start-container.sh --gpu none           # Explicitly specify no GPU

# Display mode options:
./start-container.sh --gpu all            # Selkies GStreamer (WebRTC, default)
./start-container.sh -g intel --vnc       # KasmVNC (VNC over WebSocket) with Intel GPU
./start-container.sh --gpu all -v         # KasmVNC with NVIDIA GPUs
./start-container.sh -v                   # KasmVNC with software rendering

# Keyboard layout override (auto-detected by default):
KEYBOARD_LAYOUT=jp ./start-container.sh -g intel        # Japanese keyboard
KEYBOARD_LAYOUT=us ./start-container.sh --gpu intel    # US keyboard
KEYBOARD_LAYOUT=de KEYBOARD_MODEL=pc105 ./start-container.sh -g all  # German keyboard
```

Then open your browser to: <http://localhost:8080>

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
./start-container.sh intel vnc     # Switch to KasmVNC

# Method 2: Commit, delete, and recreate
./commit-container.sh              # Save changes first
./stop-container.sh rm
./start-container.sh intel         # Switch to Selkies

# Method 3: Commit and auto-restart
./commit-container.sh restart intel vnc  # Save and switch to KasmVNC
```

The start script will detect mode mismatch and show a helpful error message with instructions.

### Common Options

```bash
# Use HTTPS
./generate-ssl-cert.sh
./start-container.sh -g all

# Use a different port
HTTPS_PORT=9090 ./start-container.sh --gpu all

# High resolution (4K)
DISPLAY_WIDTH=3840 DISPLAY_HEIGHT=2160 ./start-container.sh -g all

# Foreground mode (see logs directly)
DETACHED=false ./start-container.sh --gpu all

# Custom container name
CONTAINER_NAME=my-desktop ./start-container.sh -g all
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
- Restart with: `./start-container.sh [--gpu <type>] [--vnc]`

---

## Scripts Reference

### Core Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `build-user-image.sh` | Build your user-specific image | `./build-user-image.sh` or `IN_LOCALE=JP ./build-user-image.sh` |
| `start-container.sh` | Start the desktop container | `./start-container.sh [--gpu <type>] [--vnc]` |
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
./commit-container.sh restart --gpu all      # Restart with all NVIDIA GPUs
./commit-container.sh restart -g intel       # Restart with Intel GPU
./commit-container.sh restart --gpu amd      # Restart with AMD GPU
./commit-container.sh restart --vnc          # Restart with VNC mode (no GPU)

# Save with a custom tag
COMMIT_TAG=my-setup ./commit-container.sh

# Use the saved image
IMAGE_NAME=devcontainer-ubuntu-egl-desktop-$(whoami):my-setup \
  CONTAINER_NAME=my-desktop-2 \
  ./start-container.sh all
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
./start-container.sh -g intel

# 5. To switch display mode with saved changes:
./commit-container.sh restart -g intel --vnc  # Save and switch to KasmVNC
```

**Deleting Image:**

```bash
# Delete your user image
./delete-image.sh

# Force delete (removes associated containers too)
FORCE=true ./delete-image.sh

# Delete a specific user's image
IMAGE_TAG=username ./delete-image.sh
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

./start-container.sh -g all
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

./start-container.sh -g all
```

**Available encoders:**

- `nvh264enc` - NVIDIA H.264 (requires NVIDIA GPU)
- `x264enc` - Software H.264 (CPU)
- `vp8enc` - Software VP8
- `vp9enc` - Software VP9
- `vah264enc` - AMD/Intel hardware encoding

### Audio Settings

```bash
AUDIO_BITRATE=128000      # Audio bitrate in bps (default: 128000)
./start-container.sh -g all
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
KEYBOARD_LAYOUT=jp ./start-container.sh intel              # Japanese keyboard
KEYBOARD_LAYOUT=us ./start-container.sh intel              # US keyboard
KEYBOARD_LAYOUT=de ./start-container.sh intel              # German keyboard

# With keyboard model (for non-standard keyboards)
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh intel  # Japanese 106-key

# With keyboard variant
KEYBOARD_LAYOUT=us KEYBOARD_VARIANT=dvorak ./start-container.sh all # Dvorak layout

# Full specification
KEYBOARD_LAYOUT=fr KEYBOARD_MODEL=pc105 KEYBOARD_VARIANT=azerty ./start-container.sh intel
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

```bash
./start-container.sh -g all       # Uses Selkies by default
```

**KasmVNC:**

- VNC-based streaming over WebSocket
- Better compatibility
- Works without GPU

```bash
./start-container.sh -g all --vnc # Activates KasmVNC mode
```

---

## HTTPS/SSL

### Quick Setup with Auto-Generation

```bash
# 1. Generate SSL certificate (interactive)
./generate-ssl-cert.sh

# 2. Start container (auto-detects ssl/ folder)
./start-container.sh -g all
```

The script will:

- Generate a self-signed certificate
- Save to `ssl/` folder by default
- Provide usage examples

Access via: <https://localhost:8080> (your browser will show a security warning)

### Certificate Priority

The `start-container.sh` script auto-detects certificates in this order:

1. `ssl/cert.pem` and `ssl/key.pem` (from generate-ssl-cert.sh)
2. Environment variables `CERT_PATH` and `KEY_PATH`
3. Runs without HTTPS if no certificates found

### Using Custom SSL Certificates

```bash
CERT_PATH=/path/to/cert.pem \
  KEY_PATH=/path/to/key.pem \
  ./start-container.sh -g all
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
HTTPS_PORT=8081 ./start-container.sh -g all
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
KEYBOARD_LAYOUT=jp KEYBOARD_MODEL=jp106 ./start-container.sh -g intel
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
./start-container.sh -g intel  # Use the original mode

# Option 2: Save changes and recreate
./commit-container.sh          # Save changes first!
./stop-container.sh rm         # Remove container
./start-container.sh -g intel --vnc  # Recreate with new mode

# Option 3: One-step commit and recreate
./commit-container.sh restart -g intel --vnc
```

**Why can't I change the mode?**
- Display mode is set via environment variables at container creation (`docker run`)
- Running containers use fixed environment variables
- `docker start` on existing containers doesn't change environment variables

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
VIDEO_ENCODER=vah264enc ./start-container.sh -g intel
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

Mozilla Public License 2.0

See [LICENSE](LICENSE) file for details.

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
