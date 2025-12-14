#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

# Wait for XDG_RUNTIME_DIR
until [ -d "${XDG_RUNTIME_DIR}" ]; do sleep 0.5; done

# Set default display
# Use DISPLAY from environment (set per-user in Dockerfile.user)
export DISPLAY="${DISPLAY}"
# PipeWire-Pulse server socket path
export PIPEWIRE_LATENCY="128/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

# Check if NVIDIA support is enabled (default: true for backward compatibility)
export ENABLE_NVIDIA="${ENABLE_NVIDIA:-true}"

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Apply keyboard layout configuration
if [ -n "${KEYBOARD_LAYOUT}" ]; then
  echo "Configuring keyboard layout: ${KEYBOARD_LAYOUT} ${KEYBOARD_VARIANT:+(variant: ${KEYBOARD_VARIANT})}"
  
  # Set XKB for X server
  if [ -n "${KEYBOARD_VARIANT}" ]; then
    setxkbmap -display "${DISPLAY}" -layout "${KEYBOARD_LAYOUT}" -variant "${KEYBOARD_VARIANT}" -model "${KEYBOARD_MODEL:-pc105}" 2>/dev/null || true
  else
    setxkbmap -display "${DISPLAY}" -layout "${KEYBOARD_LAYOUT}" -model "${KEYBOARD_MODEL:-pc105}" 2>/dev/null || true
  fi
  
  # Configure KDE keyboard settings
  mkdir -p ~/.config
  cat > ~/.config/kxkbrc << EOF
[Layout]
DisplayNames=
LayoutList=${KEYBOARD_LAYOUT}
Model=${KEYBOARD_MODEL:-pc105}
ResetOldOptions=true
Use=true
VariantList=${KEYBOARD_VARIANT}
EOF
  
  # Create .Xkbmap for session startup
  if [ -n "${KEYBOARD_VARIANT}" ]; then
    echo "-layout ${KEYBOARD_LAYOUT} -variant ${KEYBOARD_VARIANT} -model ${KEYBOARD_MODEL:-pc105}" > ~/.Xkbmap
  else
    echo "-layout ${KEYBOARD_LAYOUT} -model ${KEYBOARD_MODEL:-pc105}" > ~/.Xkbmap
  fi
  
  echo "Keyboard configuration applied"
fi

# Run the x11vnc + noVNC fallback web interface if enabled
if [ -n "$NOVNC_VIEWPASS" ]; then export NOVNC_VIEWONLY="-viewpasswd ${NOVNC_VIEWPASS}"; else unset NOVNC_VIEWONLY; fi

# Configure SSL options for noVNC proxy
if [ "$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  NOVNC_SSL="--ssl-only"
  NOVNC_CERT="--cert ${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem} --key ${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}"
else
  NOVNC_SSL=""
  NOVNC_CERT=""
fi

x11vnc -display "${DISPLAY}" -listen 0.0.0.0 -nopw -shared -forever -repeat -xkb -snapfb -threads -xrandr "resize" -rfbport 5900 ${NOVNC_VIEWONLY} &
/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen ${NGINX_PORT:-8080} --heartbeat 10 ${NOVNC_SSL} ${NOVNC_CERT}