#!/bin/bash
# Start the container with common settings

set -e

# Check for GPU argument
if [ $# -eq 0 ]; then
    echo "Error: GPU configuration required"
    echo ""
    echo "Usage: $0 <gpu_option> [vnc]"
    echo ""
    echo "GPU Options:"
    echo "  all       - Use all available GPUs"
    echo "  none      - No GPU support (software rendering)"
    echo "  0,1,2...  - Use specific GPU(s) by device number"
    echo ""
    echo "Display Options (optional):"
    echo "  vnc       - Use KasmVNC instead of Selkies GStreamer"
    echo ""
    echo "Examples:"
    echo "  $0 all        # Use all GPUs with Selkies"
    echo "  $0 none       # No GPU with Selkies"
    echo "  $0 0          # Use GPU 0 with Selkies"
    echo "  $0 all vnc    # Use all GPUs with KasmVNC"
    echo "  $0 none vnc   # No GPU with KasmVNC"
    echo ""
    exit 1
fi

GPU_ARG="$1"
DISPLAY_MODE="${2:-selkies}"

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
IMAGE_NAME="${IMAGE_NAME:-devcontainer-ubuntu-egl-desktop:24.04-$(whoami)}"
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
    echo "Container '${CONTAINER_NAME}' already exists."
    echo "Starting existing container..."
    docker start "${CONTAINER_NAME}"
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

# Interactive or detached
if [ "${DETACHED}" = "true" ]; then
    CMD="${CMD} -d"
else
    CMD="${CMD} -it"
fi

CMD="${CMD} --rm"
CMD="${CMD} --tmpfs /dev/shm:rw"
CMD="${CMD} --hostname $(hostname)-Container"

# GPU support based on argument
if [ "${GPU_ARG}" = "none" ]; then
    # No GPU - software rendering
    CMD="${CMD} --device=/dev/dri:rwm"
    CMD="${CMD} -e ENABLE_NVIDIA=false"
    VIDEO_ENCODER="x264enc"
elif [ "${GPU_ARG}" = "all" ]; then
    # All GPUs
    CMD="${CMD} --gpus all"
    VIDEO_ENCODER="${VIDEO_ENCODER:-nvh264enc}"
else
    # Specific GPU(s) by device number
    CMD="${CMD} --gpus '\"device=${GPU_ARG}\"'"
    VIDEO_ENCODER="${VIDEO_ENCODER:-nvh264enc}"
fi

# Display settings
CMD="${CMD} -e DISPLAY_SIZEW=${DISPLAY_WIDTH}"
CMD="${CMD} -e DISPLAY_SIZEH=${DISPLAY_HEIGHT}"
CMD="${CMD} -e DISPLAY_REFRESH=${DISPLAY_REFRESH}"

# Video encoding
CMD="${CMD} -e SELKIES_ENCODER=${VIDEO_ENCODER}"
CMD="${CMD} -e SELKIES_VIDEO_BITRATE=${VIDEO_BITRATE}"
CMD="${CMD} -e SELKIES_FRAMERATE=${FRAMERATE}"

# Audio
CMD="${CMD} -e SELKIES_AUDIO_BITRATE=${AUDIO_BITRATE}"

# Display mode (Selkies or KasmVNC)
if [ "${DISPLAY_MODE}" = "vnc" ]; then
    CMD="${CMD} -e KASMVNC_ENABLE=true"
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
