#!/bin/bash
# Start the container with common settings

set -e

# Default values
GPU_VENDOR="none"   # one of: none, intel, amd, nvidia
GPU_ALL="false"     # when vendor is nvidia, whether to use all GPUs
GPU_NUMS=""         # when vendor is nvidia, specific device numbers (comma-separated)
VNC_TYPE="selkies"  # one of: selkies, kasm, novnc
ENABLE_TURN="true"
USE_XORG="false"    # whether to use Xorg instead of Xvfb

HOST_ARCH="$(uname -m)"
SELKIES_SUPPORTED="true"
case "${HOST_ARCH}" in
    x86_64|amd64)
        ;;
    arm64|aarch64)
        SELKIES_SUPPORTED="false"
        VNC_TYPE="kasm"
        echo "Selkies mode is unavailable on ${HOST_ARCH}; defaulting to VNC type 'kasm'."
        ;;
    *)
        SELKIES_SUPPORTED="false"
        ;;
esac

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --gpu <type>    GPU vendor (default: none)"
    echo "                      nvidia    - NVIDIA (requires --all or --num)"
    echo "                      intel     - Use Intel integrated GPU"
    echo "                      amd       - Use AMD GPU"
    echo "                      none      - No GPU support (software rendering)"
    echo "  --all                Used with --gpu nvidia to select all NVIDIA GPUs"
    echo "  --num <n[,m]>        Used with --gpu nvidia to select specific device numbers (comma-separated)"
    echo "  -v, --vnc-type <type>    VNC type (default: selkies)"
    echo "                      selkies   - Selkies GStreamer (WebRTC)"
    echo "                      kasm      - KasmVNC"
    echo "                      novnc     - noVNC (with clipboard support)"
    echo "  --xorg               Use Xorg instead of Xvfb"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Note: TURN server is enabled by default for remote Selkies access."
    echo "      Ports are automatically assigned based on UID to avoid conflicts."
    echo ""
    echo "Examples:"
    echo "  $0 --gpu nvidia --all             # Use all NVIDIA GPUs with Selkies"
    echo "  $0 --gpu intel                     # Use Intel GPU with Selkies"
    echo "  $0                                 # Use software rendering (no GPU)"
    echo "  $0 --gpu nvidia --all --vnc-type kasm        # Use all NVIDIA GPUs with KasmVNC"
    echo "  $0 --gpu nvidia --num 0 --vnc-type kasm      # Use NVIDIA GPU 0 with KasmVNC"
    echo "  $0 --gpu intel --vnc-type novnc               # Use Intel GPU with noVNC"
    echo "  $0 --gpu nvidia --num 0,1 --vnc-type novnc    # Use NVIDIA GPUs 0 and 1 with noVNC"
    echo "  $0 --gpu intel --xorg                        # Use Intel GPU with Xorg"
    if [ "${SELKIES_SUPPORTED}" != "true" ]; then
        echo ""
        echo "Note: Selkies mode is not supported on ${HOST_ARCH}. Use --vnc-type kasm or novnc."
    fi
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--gpu)
            if [ -z "$2" ]; then
                echo "Error: --gpu requires an argument (nvidia|intel|amd|none)"
                exit 1
            fi
            # Disallow legacy 'all' here; require explicit vendor + --all/--num
            if [ "${2}" = "all" ]; then
                echo "Error: --gpu all is not allowed. Use --gpu nvidia --all instead."
                exit 1
            fi
            if [[ "${2}" =~ ^[0-9] ]] || [[ "${2}" == *,* ]]; then
                echo "Error: Specify device numbers with --num. Example: --gpu nvidia --num 0,1"
                exit 1
            fi
            case "${2}" in
                nvidia|intel|amd|none)
                    GPU_VENDOR="${2}"
                    ;;
                *)
                    echo "Error: Unknown GPU vendor: ${2}"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --num)
            if [ -z "$2" ]; then
                echo "Error: --num requires an argument (e.g. --num 0 or --num 0,1)"
                exit 1
            fi
            # Accept --num regardless of order; validation performed after parsing
            GPU_NUMS="$2"
            shift 2
            ;;
        --all)
            # Accept --all regardless of order; validation performed after parsing
            GPU_ALL="true"
            shift
            ;;
        --vnc-type|-v)
            if [ -z "$2" ]; then
                echo "Error: --vnc-type requires an argument (selkies|kasm|novnc)"
                exit 1
            fi
            case "${2}" in
                selkies|kasm|novnc)
                    VNC_TYPE="${2}"
                    ;;
                *)
                    echo "Error: Unknown VNC type: ${2}"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --vnc)
            # Legacy support for --vnc (maps to kasm)
            VNC_TYPE="kasm"
            shift
            ;;
        --xorg)
            USE_XORG="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

if [ "${VNC_TYPE}" = "selkies" ] && [ "${SELKIES_SUPPORTED}" != "true" ]; then
    echo "Error: Selkies mode is not supported on ${HOST_ARCH}. Use --vnc-type kasm or novnc."
    exit 1
fi

# Post-parse validation: ensure combinations are valid regardless of option order
# If user provided --num or --all, they must be used with --gpu nvidia
if [ -n "${GPU_NUMS}" ] || [ "${GPU_ALL}" = "true" ]; then
    if [ "${GPU_VENDOR}" != "nvidia" ]; then
        echo "Error: --all/--num options require --gpu nvidia. Example: --gpu nvidia --all or --gpu nvidia --num 0,1"
        exit 1
    fi
fi

# If vendor is nvidia, require either --all or --num
if [ "${GPU_VENDOR}" = "nvidia" ]; then
    if [ "${GPU_ALL}" != "true" ] && [ -z "${GPU_NUMS}" ]; then
        echo "Error: --gpu nvidia requires either --all or --num. Example: --gpu nvidia --all or --gpu nvidia --num 0,1"
        exit 1
    fi
fi

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
IMAGE_NAME="${IMAGE_NAME:-devcontainer-ubuntu-egl-desktop-$(whoami):24.04}"

# Enable HTTPS for all VNC types (required for clipboard API)
ENABLE_HTTPS="${ENABLE_HTTPS:-true}"

# Port configuration (UID-based for multi-user support)
USER_UID=$(id -u)
# HTTPS_PORT: 10000 + UID (e.g., UID 1000 -> port 11000)
HTTPS_PORT="${HTTPS_PORT:-$((10000 + USER_UID))}"
# TURN port: 13000 + UID (e.g., UID 1000 -> port 14000)
TURN_PORT="$((13000 + USER_UID))"
# UDP port range: 40000 + ((UID - 1000) * 200) to +100
# e.g., UID 1000 -> ports 40000-40100, UID 1001 -> 40200-40300
UDP_PORT_START="$((40000 + (USER_UID - 1000) * 200))"
UDP_PORT_END="$((UDP_PORT_START + 100))"

DETACHED="${DETACHED:-true}"

# Display settings
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1920}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1080}"
DISPLAY_REFRESH="${DISPLAY_REFRESH:-60}"

# Video encoding
VIDEO_ENCODER="${VIDEO_ENCODER:-nvh264enc}"
VIDEO_BITRATE="${VIDEO_BITRATE:-8000}"
FRAMERATE="${FRAMERATE:-60}"

# Audio
AUDIO_BITRATE="${AUDIO_BITRATE:-128000}"

# Keyboard layout configuration
# Auto-detect keyboard layout from host system if not explicitly set
if [ -z "${KEYBOARD_LAYOUT}" ]; then
    echo "Auto-detecting keyboard layout from host system..."
    
    # Prioritize system default from /etc/default/keyboard
    if [ -f /etc/default/keyboard ]; then
        HOST_LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d= -f2 | tr -d '"')
        HOST_MODEL=$(grep '^XKBMODEL=' /etc/default/keyboard 2>/dev/null | cut -d= -f2 | tr -d '"')
        HOST_VARIANT=$(grep '^XKBVARIANT=' /etc/default/keyboard 2>/dev/null | cut -d= -f2 | tr -d '"')
    fi
    
    # Fall back to current X session if /etc/default/keyboard not available
    if [ -z "${HOST_LAYOUT}" ] && command -v setxkbmap >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
        HOST_LAYOUT=$(setxkbmap -query 2>/dev/null | grep layout | awk '{print $2}')
        HOST_MODEL=$(setxkbmap -query 2>/dev/null | grep model | awk '{print $2}')
        HOST_VARIANT=$(setxkbmap -query 2>/dev/null | grep variant | awk '{print $2}')
    fi
    
    # Set detected values
    if [ -n "${HOST_LAYOUT}" ]; then
        KEYBOARD_LAYOUT="${HOST_LAYOUT}"
        KEYBOARD_MODEL="${HOST_MODEL:-pc105}"
        KEYBOARD_VARIANT="${HOST_VARIANT}"
        echo "✓ Detected host keyboard: layout=${KEYBOARD_LAYOUT}, model=${KEYBOARD_MODEL}${KEYBOARD_VARIANT:+, variant=${KEYBOARD_VARIANT}}"
    else
        # Default to US keyboard
        KEYBOARD_LAYOUT="us"
        KEYBOARD_MODEL="pc105"
        echo "⚠ Could not detect host keyboard, using default (us)"
    fi
else
    echo "Using specified keyboard layout: ${KEYBOARD_LAYOUT}"
fi

# SSL certificates (for custom certificates)
CERT_PATH="${CERT_PATH:-}"
KEY_PATH="${KEY_PATH:-}"

# Check if image exists
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    echo "Error: Image '${IMAGE_NAME}' not found"
    echo ""
    echo "Please build the user image first:"
    echo "  ./build-user-image.sh"
    echo ""
    exit 1
fi

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "========================================"
    echo "Container '${CONTAINER_NAME}' already exists."
    echo "========================================"
    
    # Check if display mode is different from existing container
    EXISTING_KASMVNC=$(docker inspect "${CONTAINER_NAME}" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep "^KASMVNC_ENABLE=" | cut -d= -f2)
    
    # Build current command for display
    CURRENT_GPU_OPT=""
    if [ "${GPU_VENDOR}" != "none" ]; then
        CURRENT_GPU_OPT="--gpu ${GPU_VENDOR}"
        if [ "${GPU_VENDOR}" = "nvidia" ]; then
            if [ "${GPU_ALL}" = "true" ]; then
                CURRENT_GPU_OPT="${CURRENT_GPU_OPT} --all"
            elif [ -n "${GPU_NUMS}" ]; then
                CURRENT_GPU_OPT="${CURRENT_GPU_OPT} --num ${GPU_NUMS}"
            fi
        fi
    fi
    
    if [ "${VNC_TYPE}" = "kasm" ] && [ "${EXISTING_KASMVNC}" = "false" ]; then
        echo ""
        echo "⚠️  WARNING: Container was created with Selkies mode, but you're trying to start it with KasmVNC mode."
        echo "    Display mode cannot be changed for existing containers."
        echo ""
        echo "Options:"
        echo "  1. Keep using Selkies mode: ./start-container.sh ${CURRENT_GPU_OPT}"
        echo "  2. Delete and recreate with KasmVNC: ./stop-container.sh rm && ./start-container.sh ${CURRENT_GPU_OPT} --vnc-type kasm"
        echo ""
        exit 1
    elif [ "${VNC_TYPE}" = "selkies" ] && [ "${EXISTING_KASMVNC}" = "true" ]; then
        echo ""
        echo "⚠️  WARNING: Container was created with KasmVNC mode, but you're trying to start it with Selkies mode."
        echo "    Display mode cannot be changed for existing containers."
        echo ""
        echo "Options:"
        echo "  1. Keep using KasmVNC mode: ./start-container.sh ${CURRENT_GPU_OPT} --vnc-type kasm"
        echo "  2. Delete and recreate with Selkies: ./stop-container.sh rm && ./start-container.sh ${CURRENT_GPU_OPT}"
        echo ""
        exit 1
    fi
    
    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is already running with $([ "${EXISTING_KASMVNC}" = "true" ] && echo "KasmVNC" || echo "Selkies") mode."
    else
        echo "Starting existing container with $([ "${EXISTING_KASMVNC}" = "true" ] && echo "KasmVNC" || echo "Selkies") mode..."
        docker start "${CONTAINER_NAME}"
    fi
    
    echo ""
    echo "========================================"
    echo "Container is ready!"
    echo "========================================"
    if [ "${ENABLE_HTTPS}" = "true" ]; then
        echo "Access via: https://localhost:${HTTPS_PORT}"
    else
        echo "Access via: http://localhost:${HTTPS_PORT}"
    fi
    echo "Username: $(whoami)"
    echo "UID: ${USER_UID}, Port: ${HTTPS_PORT}"
    if [ "${ENABLE_TURN}" = "true" ]; then
        echo "TURN Port: ${TURN_PORT}, UDP: ${UDP_PORT_START}-${UDP_PORT_END}"
    fi
    echo ""
    echo "View logs: ./logs-container.sh"
    echo "Stop container: ./stop-container.sh"
    echo "Access shell: ./shell-container.sh"
    echo "========================================"
    exit 0
fi

echo "========================================"
echo "Starting new container: ${CONTAINER_NAME}"
echo "========================================"
echo "Image: ${IMAGE_NAME}"
echo "HTTPS: ${ENABLE_HTTPS}"
echo "Port: ${HTTPS_PORT}"
GPU_DESC="${GPU_VENDOR}"
if [ "${GPU_VENDOR}" = "nvidia" ]; then
    if [ "${GPU_ALL}" = "true" ]; then
        GPU_DESC="${GPU_DESC} --all"
    elif [ -n "${GPU_NUMS}" ]; then
        GPU_DESC="${GPU_DESC} --num ${GPU_NUMS}"
    else
        GPU_DESC="${GPU_DESC} (no --all or --num specified)"
    fi
fi
echo "GPU: ${GPU_DESC}"
echo "Display: ${VNC_TYPE}"
echo "========================================"

# Build docker run command
CMD="docker run --name ${CONTAINER_NAME}"

# Add video and render groups for GPU access (use host GIDs)
# Required for all GPU types to access /dev/dri devices
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)
if [ -n "${VIDEO_GID}" ]; then
    CMD="${CMD} --group-add=${VIDEO_GID}"
    echo "Adding video group (GID: ${VIDEO_GID})"
fi
if [ -n "${RENDER_GID}" ]; then
    CMD="${CMD} --group-add=${RENDER_GID}"
    echo "Adding render group (GID: ${RENDER_GID})"
fi

# Interactive or detached
if [ "${DETACHED}" = "true" ]; then
    CMD="${CMD} -d"
else
    CMD="${CMD} -it"
fi

# Note: --rm flag removed to allow container persistence and commit
CMD="${CMD} --tmpfs /dev/shm:rw"
CMD="${CMD} --hostname $(hostname)-Container"

# GPU support based on parsed options (GPU_VENDOR, GPU_ALL, GPU_NUMS)
if [ "${GPU_VENDOR}" = "none" ]; then
    # No GPU - software rendering
    if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
        CMD="${CMD} --device=/dev/dri:rwm"
    else
        echo "Warning: /dev/dri not found, skipping GPU device mount (WSL environment detected)"
    fi
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    VIDEO_ENCODER="x264enc"
elif [ "${GPU_VENDOR}" = "intel" ]; then
    # Intel GPU with VA-API hardware acceleration
    if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
        CMD="${CMD} --device=/dev/dri:rwm"
        CMD="${CMD} --privileged"
    else
        echo "Warning: /dev/dri not found, Intel GPU not available (WSL environment detected)"
    fi
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    INTEL_FORCE_VAAPI="${INTEL_FORCE_VAAPI:-true}"
    if [ "${INTEL_FORCE_VAAPI}" = "true" ]; then
        CMD="${CMD} -e LIBVA_DRIVER_NAME=${LIBVA_DRIVER_NAME:-iHD}"
        VIDEO_ENCODER="vah264enc"
        if command -v vainfo >/dev/null 2>&1; then
            if vainfo 2>&1 | grep -q "iHD.*VAEntrypoint"; then
                echo "Using Intel GPU with VA-API hardware acceleration (Quick Sync Video)"
            else
                echo "Intel VA-API check failed, but forcing hardware encoder (set INTEL_FORCE_VAAPI=false to fall back)"
            fi
        else
            echo "vainfo not available, assuming Intel VA-API works (INTEL_FORCE_VAAPI=true)"
        fi
    else
        # Check if Intel GPU VA-API is actually available
        if command -v vainfo >/dev/null 2>&1 && vainfo 2>&1 | grep -q "iHD.*VAEntrypoint"; then
            CMD="${CMD} -e LIBVA_DRIVER_NAME=iHD"
            VIDEO_ENCODER="vah264enc"
            echo "Using Intel GPU with VA-API hardware acceleration (Quick Sync Video)"
        else
            echo "Warning: Intel VA-API not available, falling back to software encoding"
            VIDEO_ENCODER="x264enc"
            echo "Using software encoding (x264) for Intel GPU mode"
        fi
    fi
elif [ "${GPU_VENDOR}" = "amd" ]; then
    # AMD GPU - use for rendering but software encoding if VA-API not working
    if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
        CMD="${CMD} --device=/dev/dri:rwm"
    else
        echo "Warning: /dev/dri not found, AMD GPU not available (WSL environment detected)"
    fi
    if [ -d "/dev/kfd" ]; then
        CMD="${CMD} --device=/dev/kfd:rwm"
    fi
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    AMD_FORCE_VAAPI="${AMD_FORCE_VAAPI:-true}"
    AMD_LIBVA_DRIVER="${AMD_LIBVA_DRIVER:-radeonsi}"
    if [ "${AMD_FORCE_VAAPI}" = "true" ]; then
        CMD="${CMD} -e LIBVA_DRIVER_NAME=${AMD_LIBVA_DRIVER}"
        VIDEO_ENCODER="vah264enc"
        if command -v vainfo >/dev/null 2>&1; then
            if vainfo 2>&1 | grep -q "VAProfileH264.*VAEntrypointEncSlice"; then
                echo "Using AMD GPU with VA-API hardware encoding (radeonsi)"
            else
                echo "AMD VA-API check failed, but forcing hardware encoder (set AMD_FORCE_VAAPI=false to fall back)"
            fi
        else
            echo "vainfo not available, assuming AMD VA-API works (AMD_FORCE_VAAPI=true)"
        fi
    else
        if command -v vainfo >/dev/null 2>&1 && vainfo 2>&1 | grep -q "VAProfileH264.*VAEntrypointEncSlice"; then
            CMD="${CMD} -e LIBVA_DRIVER_NAME=${AMD_LIBVA_DRIVER}"
            VIDEO_ENCODER="vah264enc"
            echo "Using AMD GPU with VA-API hardware encoding (radeonsi)"
        else
            echo "Warning: AMD VA-API not available, falling back to software encoding"
            VIDEO_ENCODER="x264enc"
            echo "Using software encoding (x264) for AMD GPU mode"
        fi
    fi
elif [ "${GPU_VENDOR}" = "nvidia" ]; then
    # NVIDIA: require explicit --all or --num
    if [ "${GPU_ALL}" = "true" ]; then
        CMD="${CMD} --gpus all"
        if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
            CMD="${CMD} --device=/dev/dri:rwm"
        fi
    elif [ -n "${GPU_NUMS}" ]; then
        # Pass device list to docker --gpus option
        CMD="${CMD} --gpus '\"device=${GPU_NUMS}\"'"
        if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
            CMD="${CMD} --device=/dev/dri:rwm"
        fi
    else
        echo "Error: --gpu nvidia requires either --all or --num. Example: --gpu nvidia --all or --gpu nvidia --num 0,1"
        exit 1
    fi
    # Enable NVIDIA GPU support explicitly
    CMD="${CMD} -e ENABLE_NVIDIA=true"
    # VIDEO_ENCODER is nvh264enc by default
else
    echo "Error: Unknown GPU vendor: ${GPU_VENDOR}"
    exit 1
fi

# Display settings
CMD="${CMD} -e DISPLAY_SIZEW=${DISPLAY_WIDTH}"
CMD="${CMD} -e DISPLAY_SIZEH=${DISPLAY_HEIGHT}"
CMD="${CMD} -e DISPLAY_REFRESH=${DISPLAY_REFRESH}"
CMD="${CMD} -e USE_XORG=${USE_XORG}"

# Keyboard layout
CMD="${CMD} -e KEYBOARD_LAYOUT=${KEYBOARD_LAYOUT}"
if [ -n "${KEYBOARD_VARIANT}" ]; then
    CMD="${CMD} -e KEYBOARD_VARIANT=${KEYBOARD_VARIANT}"
fi
if [ -n "${KEYBOARD_MODEL}" ]; then
    CMD="${CMD} -e KEYBOARD_MODEL=${KEYBOARD_MODEL}"
fi

# Video encoding
CMD="${CMD} -e SELKIES_ENCODER=${VIDEO_ENCODER}"
CMD="${CMD} -e SELKIES_VIDEO_BITRATE=${VIDEO_BITRATE}"
CMD="${CMD} -e SELKIES_FRAMERATE=${FRAMERATE}"

# Audio
CMD="${CMD} -e SELKIES_AUDIO_BITRATE=${AUDIO_BITRATE}"

# Display mode (Selkies, KasmVNC, or noVNC)
CMD="${CMD} -e VNC_TYPE=${VNC_TYPE}"

# Set KASMVNC_ENABLE based on VNC_TYPE
if [ "${VNC_TYPE}" = "kasm" ]; then
    CMD="${CMD} -e KASMVNC_ENABLE=true"
else
    CMD="${CMD} -e KASMVNC_ENABLE=false"
fi

# HTTPS configuration
if [ "${ENABLE_HTTPS}" = "true" ]; then
    CMD="${CMD} -e SELKIES_ENABLE_HTTPS=true"
    
    # Check if custom certificates are provided
    if [ -n "${CERT_PATH}" ] && [ -n "${KEY_PATH}" ]; then
        CMD="${CMD} -e SELKIES_HTTPS_CERT=/etc/ssl/custom/cert.pem"
        CMD="${CMD} -e SELKIES_HTTPS_KEY=/etc/ssl/custom/key.pem"
        CMD="${CMD} -v ${CERT_PATH}:/etc/ssl/custom/cert.pem:ro"
        CMD="${CMD} -v ${KEY_PATH}:/etc/ssl/custom/key.pem:ro"
        echo "Using custom SSL certificates"
    # Check if certificates exist in ssl/ directory
    elif [ -f "ssl/cert.pem" ] && [ -f "ssl/key.pem" ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        CMD="${CMD} -e SELKIES_HTTPS_CERT=/etc/ssl/custom/cert.pem"
        CMD="${CMD} -e SELKIES_HTTPS_KEY=/etc/ssl/custom/key.pem"
        CMD="${CMD} -v ${SCRIPT_DIR}/ssl/cert.pem:/etc/ssl/custom/cert.pem:ro"
        CMD="${CMD} -v ${SCRIPT_DIR}/ssl/key.pem:/etc/ssl/custom/key.pem:ro"
        echo "Using SSL certificates from ssl/ directory"
    else
        echo "Using default self-signed certificates"
    fi
fi

# Port mapping
CMD="${CMD} -p ${HTTPS_PORT}:8080"

# KasmVNC multi-user port mapping
if [ "${VNC_TYPE}" = "kasm" ]; then
    USER_UID_OFFSET=$((USER_UID % 1000))
    KASM_WEBSOCKET_PORT=$((6900 + USER_UID_OFFSET))
    KCLIENT_PORT=$((3000 + USER_UID_OFFSET))
    KASMAUDIO_PORT=$((4900 + USER_UID_OFFSET))
    NGINX_KASM_PORT=$((12000 + USER_UID_OFFSET))  # Use different port range to avoid HTTPS conflict
    
    echo "KasmVNC multi-user ports: WebSocket=${KASM_WEBSOCKET_PORT}, kclient=${KCLIENT_PORT}, audio=${KASMAUDIO_PORT}, nginx=${NGINX_KASM_PORT}"
    
    # Map KasmVNC specific ports
    CMD="${CMD} -p ${KASM_WEBSOCKET_PORT}:${KASM_WEBSOCKET_PORT}"
    CMD="${CMD} -p ${KCLIENT_PORT}:${KCLIENT_PORT}"
    CMD="${CMD} -p ${KASMAUDIO_PORT}:${KASMAUDIO_PORT}"
    CMD="${CMD} -p ${NGINX_KASM_PORT}:${NGINX_KASM_PORT}"
fi

# TURN server ports (Selkies mode only, for remote access)
if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    CMD="${CMD} -p ${TURN_PORT}:3478/tcp"
    CMD="${CMD} -p ${TURN_PORT}:3478/udp"
    CMD="${CMD} -p ${UDP_PORT_START}-${UDP_PORT_END}:${UDP_PORT_START}-${UDP_PORT_END}/udp"
    # TURN server configuration
    CMD="${CMD} -e TURN_MIN_PORT=${UDP_PORT_START}"
    CMD="${CMD} -e TURN_MAX_PORT=${UDP_PORT_END}"
    # TURN_LISTENING_PORT: Internal port for turnserver (always 3478)
    CMD="${CMD} -e TURN_LISTENING_PORT=3478"
    # Get LAN IP address for TURN server
    # For WSL2: prioritize eth0 address (WSL2's main interface)
    LAN_IP=$(ip -4 addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [ -z "${LAN_IP}" ]; then
        # Fallback: get first non-loopback, non-docker-bridge IP
        LAN_IP=$(ip -4 addr show | grep "inet " | grep -v "127.0.0.1" | grep -v "172.17" | head -1 | awk '{print $2}' | cut -d/ -f1)
    fi
    if [ -n "${LAN_IP}" ]; then
        # SELKIES_TURN_PORT: External port for Selkies client (UID-based)
        CMD="${CMD} -e SELKIES_TURN_HOST=${LAN_IP}"
        CMD="${CMD} -e SELKIES_TURN_PORT=${TURN_PORT}"
        CMD="${CMD} -e TURN_EXTERNAL_IP=${LAN_IP}"
        echo "Enabling TURN server for LAN access (${LAN_IP}:${TURN_PORT}, UDP ports ${UDP_PORT_START}-${UDP_PORT_END})"
    else
        CMD="${CMD} -e SELKIES_TURN_PORT=${TURN_PORT}"
        # Ensure SELKIES_TURN_HOST and TURN_EXTERNAL_IP are set so the container
        # will start the bundled coTURN server even when LAN IP detection fails.
        CMD="${CMD} -e SELKIES_TURN_HOST=127.0.0.1"
        CMD="${CMD} -e TURN_EXTERNAL_IP=127.0.0.1"
        echo "Enabling TURN server ports (TCP/UDP ${TURN_PORT}, UDP ${UDP_PORT_START}-${UDP_PORT_END})"
    fi
fi

# Mount home directory as host_home and create user's home directory
CMD="${CMD} -v ${HOME}:/home/$(whoami)/host_home"

# Mount host PulseAudio socket for audio support (noVNC mode only)
# noVNC does not have built-in audio support, so we mount host PulseAudio
if [ "${VNC_TYPE}" = "novnc" ]; then
    if [ -S "/run/user/$(id -u)/pulse/native" ]; then
        CMD="${CMD} -e PULSE_SERVER=unix:/tmp/pulse-host/native"
        CMD="${CMD} -v /run/user/$(id -u)/pulse:/tmp/pulse-host:ro"
        echo "Mounting host PulseAudio socket for noVNC audio support"
    elif [ -d "${HOME}/.pulse" ]; then
        CMD="${CMD} -v ${HOME}/.pulse:/tmp/pulse-host:ro"
        echo "Mounting host PulseAudio directory for noVNC audio support"
    else
        echo "Warning: Host PulseAudio socket not found, audio may not work in noVNC mode"
    fi
fi

# Image name
CMD="${CMD} ${IMAGE_NAME}"

# Execute command
echo ""
echo "Executing: ${CMD}"
echo ""
eval ${CMD}

if [ "${DETACHED}" = "true" ]; then
    echo ""
    echo "========================================"
    echo "Container started successfully!"
    echo "========================================"
    if [ "${ENABLE_HTTPS}" = "true" ]; then
        echo "Access via: https://localhost:${HTTPS_PORT}"
    else
        echo "Access via: http://localhost:${HTTPS_PORT}"
    fi
    echo "Username: $(whoami)"
    echo "UID: ${USER_UID}, Port: ${HTTPS_PORT}"
    if [ "${ENABLE_TURN}" = "true" ]; then
        echo "TURN Port: ${TURN_PORT}, UDP: ${UDP_PORT_START}-${UDP_PORT_END}"
    fi
    echo ""
    echo "View logs: ./logs-container.sh"
    echo "Stop container: ./stop-container.sh"
    echo "Access shell: ./shell-container.sh"
    echo "========================================"
fi
