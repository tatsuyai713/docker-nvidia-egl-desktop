#!/bin/bash
# Start the container with common settings

set -e

# Default values
GPU_ARG="none"
DISPLAY_MODE="selkies"

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -g, --gpu <type>    GPU configuration (default: none)"
    echo "                      all       - Use all available NVIDIA GPUs"
    echo "                      none      - No GPU support (software rendering)"
    echo "                      0,1,2...  - Use specific NVIDIA GPU(s) by device number"
    echo "                      intel     - Use Intel integrated GPU"
    echo "                      amd       - Use AMD GPU"
    echo "  -v, --vnc           Use KasmVNC instead of Selkies GStreamer"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --gpu all              # Use all NVIDIA GPUs with Selkies"
    echo "  $0 -g intel               # Use Intel GPU with Selkies"
    echo "  $0                        # Use software rendering (no GPU)"
    echo "  $0 --gpu all --vnc        # Use all NVIDIA GPUs with KasmVNC"
    echo "  $0 -g 0 -v                # Use NVIDIA GPU 0 with KasmVNC"
    echo "  $0 -g intel -v            # Use Intel GPU with KasmVNC"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--gpu)
            GPU_ARG="$2"
            shift 2
            ;;
        -v|--vnc)
            DISPLAY_MODE="vnc"
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

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
IMAGE_NAME="${IMAGE_NAME:-devcontainer-ubuntu-egl-desktop-$(whoami):24.04}"
ENABLE_HTTPS="${ENABLE_HTTPS:-false}"
HTTPS_PORT="${HTTPS_PORT:-8080}"
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
    if [ "${GPU_ARG}" != "none" ]; then
        CURRENT_GPU_OPT="--gpu ${GPU_ARG}"
    fi
    
    if [ "${DISPLAY_MODE}" = "vnc" ] && [ "${EXISTING_KASMVNC}" = "false" ]; then
        echo ""
        echo "⚠️  WARNING: Container was created with Selkies mode, but you're trying to start it with KasmVNC mode."
        echo "    Display mode cannot be changed for existing containers."
        echo ""
        echo "Options:"
        echo "  1. Keep using Selkies mode: ./start-container.sh ${CURRENT_GPU_OPT}"
        echo "  2. Delete and recreate with KasmVNC: ./stop-container.sh rm && ./start-container.sh ${CURRENT_GPU_OPT} --vnc"
        echo ""
        exit 1
    elif [ "${DISPLAY_MODE}" = "selkies" ] && [ "${EXISTING_KASMVNC}" = "true" ]; then
        echo ""
        echo "⚠️  WARNING: Container was created with KasmVNC mode, but you're trying to start it with Selkies mode."
        echo "    Display mode cannot be changed for existing containers."
        echo ""
        echo "Options:"
        echo "  1. Keep using KasmVNC mode: ./start-container.sh ${CURRENT_GPU_OPT} --vnc"
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
echo "GPU: ${GPU_ARG}"
echo "Display: ${DISPLAY_MODE}"
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

# GPU support based on argument
if [ "${GPU_ARG}" = "none" ]; then
    # No GPU - software rendering
    CMD="${CMD} --device=/dev/dri:rwm"
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    VIDEO_ENCODER="x264enc"
elif [ "${GPU_ARG}" = "intel" ]; then
    # Intel GPU with VA-API hardware acceleration
    CMD="${CMD} --device=/dev/dri:rwm"
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    CMD="${CMD} -e LIBVA_DRIVER_NAME=iHD"
    # Intel Quick Sync Video encoder via VA-API
    VIDEO_ENCODER="vah264enc"
    echo "Using Intel GPU with VA-API hardware acceleration (Quick Sync Video)"
elif [ "${GPU_ARG}" = "amd" ]; then
    # AMD GPU - use for rendering but software encoding if VA-API not working
    CMD="${CMD} --device=/dev/dri:rwm"
    CMD="${CMD} --device=/dev/kfd:rwm"
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    # Try VA-API hardware encoding first, will fallback to software if unavailable
    VIDEO_ENCODER="x264enc"
    echo "Using AMD GPU for rendering with software encoding (x264)"
elif [ "${GPU_ARG}" = "all" ]; then
    # All NVIDIA GPUs
    CMD="${CMD} --gpus all"
    CMD="${CMD} --device=/dev/dri:rwm"
    # VIDEO_ENCODER already set to nvh264enc by default
else
    # Specific NVIDIA GPU(s) by device number
    CMD="${CMD} --gpus '\"device=${GPU_ARG}\"'"
    CMD="${CMD} --device=/dev/dri:rwm"
    # VIDEO_ENCODER already set to nvh264enc by default
fi

# Display settings
CMD="${CMD} -e DISPLAY_SIZEW=${DISPLAY_WIDTH}"
CMD="${CMD} -e DISPLAY_SIZEH=${DISPLAY_HEIGHT}"
CMD="${CMD} -e DISPLAY_REFRESH=${DISPLAY_REFRESH}"

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

# Display mode (Selkies or KasmVNC)
if [ "${DISPLAY_MODE}" = "vnc" ]; then
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

# Mount home directory as host_home and create user's home directory
CMD="${CMD} -v ${HOME}:/home/$(whoami)/host_home"

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
    echo ""
    echo "View logs: ./logs-container.sh"
    echo "Stop container: ./stop-container.sh"
    echo "Access shell: ./shell-container.sh"
    echo "========================================"
fi
