#!/bin/bash
# Generate environment variables for docker-compose (same settings as start-container.sh)
# Usage: source <(./compose-env.sh --gpu nvidia --all)
#        ./compose-env.sh --env-file .env --gpu intel --vnc-type kasm

set -e

show_usage() {
    cat <<'EOF'
Usage: compose-env.sh [options]

Options (same as start-container.sh):
  -g, --gpu <type>       GPU vendor: none (default), nvidia, intel, amd
                         Note: --gpu nvidia requires --all or --num
      --all              Use all NVIDIA GPUs (only with --gpu nvidia)
      --num <list>       Comma-separated NVIDIA GPU indices (only with --gpu nvidia)
  -v, --vnc-type <type>  Display mode: selkies (default), kasm, novnc
      --vnc              Legacy alias of --vnc-type kasm
      --xorg             Use Xorg instead of Xvfb
      --no-turn          Disable TURN server (Selkies only)
      --env-file <path>  Write KEY=VALUE pairs to the specified file instead of exports
  -h, --help             Show this help

Environment overrides:
  Display: DISPLAY_WIDTH, DISPLAY_HEIGHT, DISPLAY_REFRESH
  Ports: HTTPS_PORT, TURN_PORT, UDP_PORT_START, UDP_PORT_END
  HTTPS: ENABLE_HTTPS, CERT_PATH, KEY_PATH
  Keyboard: KEYBOARD_LAYOUT, KEYBOARD_MODEL, KEYBOARD_VARIANT
  Password: USER_PASSWORD
EOF
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
GPU_VENDOR="${GPU_VENDOR:-none}"
GPU_ALL="${GPU_ALL:-false}"
GPU_NUMS="${GPU_NUMS:-}"
VNC_TYPE="${VNC_TYPE:-selkies}"
ENABLE_TURN="${ENABLE_TURN:-true}"
USE_XORG="${USE_XORG:-false}"
OUTPUT_MODE="export"
ENV_FILE=""

# Option parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--gpu)
            if [ -z "${2:-}" ]; then
                echo "Error: --gpu requires an argument" >&2
                exit 1
            fi
            if [[ "${2}" = "all" ]]; then
                echo "Error: --gpu all is not supported. Use --gpu nvidia --all." >&2
                exit 1
            fi
            if [[ "${2}" =~ ^[0-9] ]] || [[ "${2}" == *,* ]]; then
                echo "Error: Use --num for device numbers. Example: --gpu nvidia --num 0,1" >&2
                exit 1
            fi
            case "${2}" in
                nvidia|intel|amd|none)
                    GPU_VENDOR="${2}"
                    ;;
                *)
                    echo "Error: Unknown GPU vendor: ${2}" >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --all)
            GPU_ALL="true"
            shift
            ;;
        --num)
            if [ -z "${2:-}" ]; then
                echo "Error: --num requires a value (e.g. --num 0 or --num 0,1)" >&2
                exit 1
            fi
            GPU_NUMS="${2}"
            shift 2
            ;;
        -v|--vnc-type)
            if [ -z "${2:-}" ]; then
                echo "Error: --vnc-type requires an argument (selkies|kasm|novnc)" >&2
                exit 1
            fi
            case "${2}" in
                selkies|kasm|novnc)
                    VNC_TYPE="${2}"
                    ;;
                *)
                    echo "Error: Unknown VNC type: ${2}" >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --vnc)
            VNC_TYPE="kasm"
            shift
            ;;
        --xorg)
            USE_XORG="true"
            shift
            ;;
        --no-turn)
            ENABLE_TURN="false"
            shift
            ;;
        --env-file)
            if [ -z "${2:-}" ]; then
                echo "Error: --env-file requires a path" >&2
                exit 1
            fi
            ENV_FILE="${2}"
            OUTPUT_MODE="envfile"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Validation (match start-container.sh behavior)
if [ -n "${GPU_NUMS}" ] || [ "${GPU_ALL}" = "true" ]; then
    if [ "${GPU_VENDOR}" != "nvidia" ]; then
        echo "Error: --all/--num require --gpu nvidia" >&2
        exit 1
    fi
fi
if [ "${GPU_VENDOR}" = "nvidia" ] && [ "${GPU_ALL}" != "true" ] && [ -z "${GPU_NUMS}" ]; then
    echo "Error: --gpu nvidia requires --all or --num" >&2
    exit 1
fi

# Base configuration
CURRENT_USER=$(whoami)
USER_UID=$(id -u)
USER_GID=$(id -g)
CONTAINER_NAME="devcontainer-egl-desktop-${CURRENT_USER}"
USER_IMAGE="devcontainer-ubuntu-egl-desktop-${CURRENT_USER}:24.04"
CONTAINER_HOSTNAME="${CONTAINER_HOSTNAME:-$(hostname)-Container}"

# Ports (UID-based, but allow overrides)
HTTPS_PORT="${HTTPS_PORT:-$((10000 + USER_UID))}"
TURN_PORT="${TURN_PORT:-$((13000 + USER_UID))}"
UDP_PORT_START="${UDP_PORT_START:-$((40000 + (USER_UID - 1000) * 200))}"
UDP_PORT_END="${UDP_PORT_END:-$((UDP_PORT_START + 100))}"

# Display
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1920}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1080}"
DISPLAY_REFRESH="${DISPLAY_REFRESH:-60}"
TZ="${TZ:-UTC}"

# Video / audio defaults
VIDEO_ENCODER="nvh264enc"
VIDEO_BITRATE="${VIDEO_BITRATE:-8000}"
FRAMERATE="${FRAMERATE:-60}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128000}"

# Keyboard detection (match start-container.sh)
if [ -z "${KEYBOARD_LAYOUT:-}" ]; then
    if [ -f /etc/default/keyboard ]; then
        KEYBOARD_LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard | cut -d= -f2 | tr -d '"')
        KEYBOARD_MODEL=$(grep '^XKBMODEL=' /etc/default/keyboard | cut -d= -f2 | tr -d '"')
        KEYBOARD_VARIANT=$(grep '^XKBVARIANT=' /etc/default/keyboard | cut -d= -f2 | tr -d '"')
    fi
    if [ -z "${KEYBOARD_LAYOUT}" ] && command -v setxkbmap >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        KEYBOARD_LAYOUT=$(setxkbmap -query 2>/dev/null | awk '/layout/{print $2}')
        KEYBOARD_MODEL=$(setxkbmap -query 2>/dev/null | awk '/model/{print $2}')
        KEYBOARD_VARIANT=$(setxkbmap -query 2>/dev/null | awk '/variant/{print $2}')
    fi
fi
KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-us}"
KEYBOARD_MODEL="${KEYBOARD_MODEL:-pc105}"
KEYBOARD_VARIANT="${KEYBOARD_VARIANT:-}"

ENABLE_HTTPS="${ENABLE_HTTPS:-true}"
USER_PASSWORD="${USER_PASSWORD:-mypasswd}"

# GPU configuration
VIDEO_GID=$(getent group video | cut -d: -f3 || echo "44")
RENDER_GID=$(getent group render | cut -d: -f3 || echo "109")
GPU_RUNTIME=""
ENABLE_NVIDIA="false"
PRIVILEGED="false"
LIBVA_DRIVER_NAME=""
NVIDIA_VISIBLE_DEVICES=""

case "${GPU_VENDOR}" in
    nvidia)
        GPU_RUNTIME="nvidia"
        ENABLE_NVIDIA="true"
        if [ "${GPU_ALL}" = "true" ]; then
            NVIDIA_VISIBLE_DEVICES="all"
        else
            NVIDIA_VISIBLE_DEVICES="${GPU_NUMS}"
        fi
        ;;
    intel)
        PRIVILEGED="true"
        LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-iHD}"
        VIDEO_ENCODER="vah264enc"
        ;;
    amd)
        LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-radeonsi}"
        VIDEO_ENCODER="vah264enc"
        ;;
    none)
        VIDEO_ENCODER="x264enc"
        ;;
esac

# VNC specific ports
KASMVNC_ENABLE="false"
KASM_WEBSOCKET_PORT="6900"
KCLIENT_PORT="3000"
KASMAUDIO_PORT="4900"
NGINX_KASM_PORT="12000"
if [ "${VNC_TYPE}" = "kasm" ]; then
    KASMVNC_ENABLE="true"
    USER_UID_OFFSET=$((USER_UID % 1000))
    KASM_WEBSOCKET_PORT=$((6900 + USER_UID_OFFSET))
    KCLIENT_PORT=$((3000 + USER_UID_OFFSET))
    KASMAUDIO_PORT=$((4900 + USER_UID_OFFSET))
    NGINX_KASM_PORT=$((12000 + USER_UID_OFFSET))
fi

# TURN configuration
SELKIES_TURN_HOST=""
SELKIES_TURN_PORT=""
TURN_EXTERNAL_IP=""
if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    LAN_IP=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    if [ -z "${LAN_IP}" ]; then
        LAN_IP=$(ip -4 addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | grep -v "172.17" | head -1 | awk '{print $2}' | cut -d/ -f1)
    fi
    if [ -n "${LAN_IP}" ]; then
        SELKIES_TURN_HOST="${LAN_IP}"
        TURN_EXTERNAL_IP="${LAN_IP}"
    else
        SELKIES_TURN_HOST="127.0.0.1"
        TURN_EXTERNAL_IP="127.0.0.1"
    fi
    SELKIES_TURN_PORT="${TURN_PORT}"
fi

# PulseAudio mount path (default to repo-local directory)
mkdir -p "${PROJECT_ROOT}/.pulse-host"
CONTAINER_RUNTIME_DIR="/tmp/runtime-${CURRENT_USER}"
DEFAULT_PULSE_SERVER="unix:${CONTAINER_RUNTIME_DIR}/pulse/native"
PULSE_SERVER="${DEFAULT_PULSE_SERVER}"
CONTAINER_PULSE_SERVER="${PULSE_SERVER}"
PULSE_PATH="${PULSE_PATH:-${PROJECT_ROOT}/.pulse-host}"
if [ "${VNC_TYPE}" = "novnc" ]; then
    if [ -S "/run/user/${USER_UID}/pulse/native" ]; then
        PULSE_SERVER="unix:/tmp/pulse-host/native"
        PULSE_PATH="/run/user/${USER_UID}/pulse"
    elif [ -d "${HOME}/.pulse" ]; then
        # Host provides ~/.pulse but no runtime socket; mount it for legacy daemons.
        PULSE_PATH="${HOME}/.pulse"
    fi
fi

# SSL certificate paths (create folder if needed)
SSL_CERT_DIR="${SSL_CERT_DIR:-${PROJECT_ROOT}/ssl}"
mkdir -p "${SSL_CERT_DIR}"
CERT_PATH_OVERRIDE="${CERT_PATH:-}"
KEY_PATH_OVERRIDE="${KEY_PATH:-}"
CERT_PATH="${CERT_PATH_OVERRIDE:-${SSL_CERT_DIR}/cert.pem}"
KEY_PATH="${KEY_PATH_OVERRIDE:-${SSL_CERT_DIR}/key.pem}"
SELKIES_HTTPS_CERT=""
SELKIES_HTTPS_KEY=""
if [ "${ENABLE_HTTPS}" = "true" ]; then
    if [ -f "${CERT_PATH}" ] && [ -f "${KEY_PATH}" ]; then
        SELKIES_HTTPS_CERT="/etc/ssl/custom/cert.pem"
        SELKIES_HTTPS_KEY="/etc/ssl/custom/key.pem"
    else
        SELKIES_HTTPS_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
        SELKIES_HTTPS_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"
    fi
fi

SELKIES_TURN_PROTOCOL="${SELKIES_TURN_PROTOCOL:-udp}"
SELKIES_TURN_SHARED_SECRET="${SELKIES_TURN_SHARED_SECRET:-}"
SELKIES_TURN_USERNAME="${SELKIES_TURN_USERNAME:-}"
SELKIES_TURN_PASSWORD="${SELKIES_TURN_PASSWORD:-}"
SELKIES_CONGESTION_CONTROL="${SELKIES_CONGESTION_CONTROL:-false}"
KASMVNC_THREADS="${KASMVNC_THREADS:-0}"

ENV_VARS=(
    USER USER_UID USER_GID CONTAINER_NAME USER_IMAGE CONTAINER_HOSTNAME
    GPU_RUNTIME VIDEO_GID RENDER_GID PRIVILEGED HTTPS_PORT TURN_PORT
    UDP_PORT_START UDP_PORT_END KASM_WEBSOCKET_PORT KCLIENT_PORT KASMAUDIO_PORT
    NGINX_KASM_PORT TZ DISPLAY_WIDTH DISPLAY_HEIGHT DISPLAY_REFRESH USE_XORG
    KEYBOARD_LAYOUT KEYBOARD_VARIANT KEYBOARD_MODEL ENABLE_NVIDIA
    LIBVA_DRIVER_NAME USER_PASSWORD VNC_TYPE KASMVNC_ENABLE KASMVNC_THREADS
    VIDEO_ENCODER VIDEO_BITRATE FRAMERATE AUDIO_BITRATE SELKIES_CONGESTION_CONTROL
    ENABLE_HTTPS SELKIES_HTTPS_CERT SELKIES_HTTPS_KEY SELKIES_TURN_HOST
    SELKIES_TURN_PORT SELKIES_TURN_PROTOCOL TURN_EXTERNAL_IP
    SELKIES_TURN_SHARED_SECRET SELKIES_TURN_USERNAME SELKIES_TURN_PASSWORD
    PULSE_SERVER CONTAINER_PULSE_SERVER PULSE_PATH CERT_PATH KEY_PATH SSL_CERT_DIR ENABLE_TURN GPU_VENDOR GPU_ALL
    GPU_NUMS NVIDIA_VISIBLE_DEVICES
)

emit_exports() {
    for var in "${ENV_VARS[@]}"; do
        printf 'export %s="%s"\n' "${var}" "${!var}"
    done
}

emit_envfile() {
    for var in "${ENV_VARS[@]}"; do
        printf '%s=%s\n' "${var}" "${!var}"
    done
}

if [ -n "${ENV_FILE}" ]; then
    mkdir -p "$(dirname "${ENV_FILE}")"
    emit_envfile > "${ENV_FILE}"
else
    emit_exports
fi
