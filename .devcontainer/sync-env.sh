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
