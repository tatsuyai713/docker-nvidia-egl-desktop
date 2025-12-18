#!/bin/bash
# Create VS Code .devcontainer configuration
# This script creates a devcontainer.json that works with the EGL desktop container

set -e

echo "========================================"
echo "VS Code Dev Container Configuration"
echo "========================================"
echo "This script will create a .devcontainer configuration"
echo "for using this container with VS Code."
echo ""

# Check if .devcontainer already exists
if [ -d ".devcontainer" ]; then
    echo "⚠️  .devcontainer directory already exists."
    read -p "Overwrite existing configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    rm -rf .devcontainer
fi

# Default values
GPU_VENDOR="none"
GPU_ALL="false"
GPU_NUMS=""
VNC_TYPE="selkies"
USE_XORG="false"
ENABLE_TURN="true"

# Interactive configuration
echo "========================================"
echo "Configuration Questions"
echo "========================================"
echo ""

# GPU configuration
echo "1. GPU Configuration"
echo "-------------------"
echo "Select GPU type:"
echo "  1) No GPU (software rendering)"
echo "  2) NVIDIA GPU"
echo "  3) Intel GPU"
echo "  4) AMD GPU"
read -p "Select [1-4] (default: 1): " gpu_choice

case "${gpu_choice}" in
    2)
        GPU_VENDOR="nvidia"
        echo ""
        echo "NVIDIA GPU selected."
        read -p "Use all NVIDIA GPUs? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "Enter GPU device numbers (comma-separated, e.g., 0,1): " GPU_NUMS
            GPU_ALL="false"
        else
            GPU_ALL="true"
            GPU_NUMS=""
        fi
        ;;
    3)
        GPU_VENDOR="intel"
        echo "Intel GPU selected."
        ;;
    4)
        GPU_VENDOR="amd"
        echo "AMD GPU selected."
        ;;
    *)
        GPU_VENDOR="none"
        echo "No GPU selected (software rendering)."
        ;;
esac
echo ""

# VNC type configuration
echo "2. Display/VNC Type"
echo "-------------------"
echo "Select VNC type:"
echo "  1) Selkies GStreamer (WebRTC, recommended)"
echo "  2) KasmVNC"
echo "  3) noVNC"
read -p "Select [1-3] (default: 1): " vnc_choice

case "${vnc_choice}" in
    2)
        VNC_TYPE="kasm"
        echo "KasmVNC selected."
        ;;
    3)
        VNC_TYPE="novnc"
        echo "noVNC selected."
        ;;
    *)
        VNC_TYPE="selkies"
        echo "Selkies GStreamer selected."
        ;;
esac
echo ""

# TURN server (Selkies only)
if [ "${VNC_TYPE}" = "selkies" ]; then
    echo "3. TURN Server (for remote access)"
    echo "----------------------------------"
    read -p "Enable internal TURN server? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TURN="false"
        echo "TURN server disabled."
    else
        ENABLE_TURN="true"
        echo "TURN server enabled."
    fi
    echo ""
fi

# Xorg option
echo "4. Display Server"
echo "----------------"
read -p "Use Xorg instead of Xvfb? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    USE_XORG="true"
    echo "Xorg selected."
else
    USE_XORG="false"
    echo "Xvfb selected."
fi
echo ""

# Display settings
echo "5. Display Settings"
echo "-------------------"
read -p "Display width (default: 1920): " DISPLAY_WIDTH
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1920}"
read -p "Display height (default: 1080): " DISPLAY_HEIGHT
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1080}"
read -p "Display refresh rate (default: 60): " DISPLAY_REFRESH
DISPLAY_REFRESH="${DISPLAY_REFRESH:-60}"
echo ""

CURRENT_USER=$(whoami)
COMPOSE_ENV_SCRIPT="./compose-env.sh"
if [ ! -x "${COMPOSE_ENV_SCRIPT}" ]; then
    echo "Error: ${COMPOSE_ENV_SCRIPT} not found. Run this script from the repository root." >&2
    exit 1
fi

# Create .devcontainer directory
mkdir -p .devcontainer

# Build compose-env arguments to mirror start-container options
COMPOSE_ARGS=(--gpu "${GPU_VENDOR}" --vnc-type "${VNC_TYPE}")
if [ "${GPU_VENDOR}" = "nvidia" ]; then
    if [ "${GPU_ALL}" = "true" ]; then
        COMPOSE_ARGS+=(--all)
    else
        COMPOSE_ARGS+=(--num "${GPU_NUMS}")
    fi
fi
if [ "${USE_XORG}" = "true" ]; then
    COMPOSE_ARGS+=(--xorg)
fi
if [ "${ENABLE_TURN}" = "false" ]; then
    COMPOSE_ARGS+=(--no-turn)
fi

ENV_FILE=".devcontainer/.env"
DISPLAY_WIDTH="${DISPLAY_WIDTH}" DISPLAY_HEIGHT="${DISPLAY_HEIGHT}" DISPLAY_REFRESH="${DISPLAY_REFRESH}" \
    "${COMPOSE_ENV_SCRIPT}" "${COMPOSE_ARGS[@]}" --env-file "${ENV_FILE}"

# Load generated environment values
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

DEVCONTAINER_CONTAINER_NAME="${CONTAINER_NAME}-devcontainer"
{
    echo ""
    echo "# Dev Container specific"
    echo "DEVCONTAINER_CONTAINER_NAME=${DEVCONTAINER_CONTAINER_NAME}"
} >> "${ENV_FILE}"
export DEVCONTAINER_CONTAINER_NAME

WORKSPACE_FOLDER="/home/${CURRENT_USER}/workspace"

# Build forward port list / attributes
FORWARD_PORTS=("${HTTPS_PORT}")
if [ "${VNC_TYPE}" = "kasm" ]; then
    FORWARD_PORTS+=("${KASM_WEBSOCKET_PORT}" "${KCLIENT_PORT}" "${KASMAUDIO_PORT}" "${NGINX_KASM_PORT}")
fi
if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    FORWARD_PORTS+=("${TURN_PORT}")
fi

FORWARD_PORTS_JSON=""
for PORT in "${FORWARD_PORTS[@]}"; do
    if [ -n "${FORWARD_PORTS_JSON}" ]; then
        FORWARD_PORTS_JSON="${FORWARD_PORTS_JSON},
"
    fi
    FORWARD_PORTS_JSON="${FORWARD_PORTS_JSON}    ${PORT}"
done

PORT_ATTRIBUTES_JSON="    \"${HTTPS_PORT}\": {
      \"label\": \"Web UI\",
      \"onAutoForward\": \"notify\"
    }"
if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    PORT_ATTRIBUTES_JSON="${PORT_ATTRIBUTES_JSON},
    \"${TURN_PORT}\": {
      \"label\": \"TURN Server\",
      \"onAutoForward\": \"silent\"
    }"
fi

# devcontainer.json
cat > .devcontainer/devcontainer.json << EOF
{
  "name": "EGL Desktop (${GPU_VENDOR})",
  "dockerComposeFile": [
    "../docker-compose.user.yml",
    "docker-compose.override.yml"
  ],
  "service": "egl",
  "workspaceFolder": "${WORKSPACE_FOLDER}",
  "runServices": ["egl"],
  "initializeCommand": "bash .devcontainer/sync-env.sh",
  "overrideCommand": false,
  "shutdownAction": "stopCompose",
  "forwardPorts": [
${FORWARD_PORTS_JSON}
  ],
  "portsAttributes": {
${PORT_ATTRIBUTES_JSON}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-python.python",
        "ms-python.vscode-pylance"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  },
  "remoteUser": "${CURRENT_USER}",
  "containerUser": "${CURRENT_USER}",
  "postCreateCommand": "echo 'Dev container is ready!'"
}
EOF

# docker-compose override for devcontainer
cat > .devcontainer/docker-compose.override.yml << EOF
version: '3.8'

services:
  egl:
    container_name: \${DEVCONTAINER_CONTAINER_NAME:-devcontainer-egl-desktop-\${USER}-devcontainer}
    volumes:
      - ..:${WORKSPACE_FOLDER}:cached
EOF

# sync-env helper
cat > .devcontainer/sync-env.sh << 'EOF'
#!/usr/bin/env bash
# Copy .devcontainer/.env to the workspace root for docker compose

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ENV="${ROOT_DIR}/.devcontainer/.env"
TARGET_ENV="${ROOT_DIR}/.env"

if [ ! -f "${SOURCE_ENV}" ]; then
    echo "[devcontainer] No .devcontainer/.env found, skipping env sync." >&2
    exit 0
fi

if [ ! -f "${TARGET_ENV}" ] || ! cmp -s "${SOURCE_ENV}" "${TARGET_ENV}"; then
    cp "${SOURCE_ENV}" "${TARGET_ENV}"
    echo "[devcontainer] Synced .devcontainer/.env to workspace .env for docker compose." >&2
fi
EOF
chmod +x .devcontainer/sync-env.sh

# README
cat > .devcontainer/README.md << EOF
# VS Code Dev Container Configuration

このディレクトリのファイルは \`./create-devcontainer-config.sh\` によって生成され、\`start-container.sh\` と同じ環境変数を \`.devcontainer/.env\` に書き出します。VS Code は起動前に \`.devcontainer/sync-env.sh\` を実行し、同じ値をリポジトリ直下の \`.env\` にコピーしてから \`docker compose\` を実行します。

## 生成された設定

- GPU: ${GPU_VENDOR}
EOF

if [ "${GPU_VENDOR}" = "nvidia" ]; then
    if [ "${GPU_ALL}" = "true" ]; then
        cat >> .devcontainer/README.md << 'EOF'
- NVIDIA GPUs: all
EOF
    else
        cat >> .devcontainer/README.md << EOF
- NVIDIA GPUs: ${GPU_NUMS}
EOF
    fi
fi

cat >> .devcontainer/README.md << EOF
- VNC Type: ${VNC_TYPE}
- Display Server: $( [ "${USE_XORG}" = "true" ] && echo "Xorg" || echo "Xvfb" )
- Resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}@${DISPLAY_REFRESH}Hz
- HTTPS (Web UI): https://localhost:${HTTPS_PORT}
EOF

if [ "${VNC_TYPE}" = "kasm" ]; then
    cat >> .devcontainer/README.md << EOF
- Kasm WebSocket: ${KASM_WEBSOCKET_PORT}
- Kasm kclient: ${KCLIENT_PORT}
- Kasm Audio Relay: ${KASMAUDIO_PORT}
- Kasm nginx: ${NGINX_KASM_PORT}
EOF
fi

if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    cat >> .devcontainer/README.md << EOF
- TURN Server: ${TURN_PORT} (UDP ${UDP_PORT_START}-${UDP_PORT_END})
EOF
else
    cat >> .devcontainer/README.md << 'EOF'
- TURN Server: disabled
EOF
fi

cat >> .devcontainer/README.md << 'EOF'

## VS Code での利用手順
1. Dev Containers 拡張機能をインストールする
2. ワークスペースを開き、`F1` → `Dev Containers: Reopen in Container` を実行
3. VS Code が `.devcontainer/.env` を同期してから `docker compose` を起動

## 再設定
設定を変更したい場合はリポジトリルートで `./create-devcontainer-config.sh` を再実行し、案内に従ってください。スクリプト完了後に VS Code 側で「Rebuild Container」を選択すると新しい設定が反映されます。
EOF

# Copy .env to workspace root for docker-compose users
bash .devcontainer/sync-env.sh >/dev/null

echo ""
echo "========================================"
echo "Configuration Complete!"
echo "========================================"
echo ""
echo "Created files:"
echo "  - .devcontainer/devcontainer.json"
echo "  - .devcontainer/docker-compose.override.yml"
echo "  - .devcontainer/.env"
echo "  - .devcontainer/sync-env.sh"
echo "  - .devcontainer/README.md"
echo ""
echo "Configuration summary:"
echo "  - GPU: ${GPU_VENDOR}"
if [ "${GPU_VENDOR}" = "nvidia" ]; then
    if [ "${GPU_ALL}" = "true" ]; then
        echo "    NVIDIA GPUs: all"
    else
        echo "    NVIDIA GPUs: ${GPU_NUMS}"
    fi
fi
echo "  - VNC Type: ${VNC_TYPE}"
echo "  - Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}@${DISPLAY_REFRESH}Hz (Xorg=${USE_XORG})"
echo "  - HTTPS Port: ${HTTPS_PORT}"
if [ "${ENABLE_TURN}" = "true" ] && [ "${VNC_TYPE}" = "selkies" ]; then
    echo "  - TURN Port: ${TURN_PORT}"
fi
echo ""
echo "Access the desktop at: https://localhost:${HTTPS_PORT}"
echo "========================================"
