#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

echo "Starting kclient audio service..."

# Internal ports are fixed (not affected by UID)
KASMVNC_PORT=${SELKIES_PORT:-8081}
KCLIENT_PORT=3000
KASMAUDIO_PORT=4900

echo "Configuration: UID=$(id -u)"
echo "Ports: KasmVNC=${KASMVNC_PORT}, kclient=${KCLIENT_PORT}, kasmaudio=${KASMAUDIO_PORT}"

# Wait for KasmVNC to be available (check actual port KasmVNC is running on)
# KasmVNC may use HTTPS, so check with -k flag
until curl -k -s https://localhost:${KASMVNC_PORT} > /dev/null 2>&1 || curl -s http://localhost:${KASMVNC_PORT} > /dev/null 2>&1; do 
    echo "Waiting for KasmVNC on port ${KASMVNC_PORT}..."
    sleep 1
done
echo "KasmVNC is ready"

# Wait for kasmbins audio relay to be ready
while ! nc -z localhost ${KASMAUDIO_PORT}; do
    echo "Waiting for kasmbins audio relay on port ${KASMAUDIO_PORT}..."
    sleep 1
done

# Wait for PulseAudio/PipeWire-Pulse to be available
echo "Waiting for PulseAudio..."
until [ -S "${XDG_RUNTIME_DIR}/pulse/native" ]; do
    echo "Waiting for PulseAudio socket at ${XDG_RUNTIME_DIR}/pulse/native..."
    sleep 1
done
echo "PulseAudio is ready"

# Mic Setup (LinuxServer compatibility)
USER_UID=$(id -u)
MIC_LOCK_FILE="/dev/shm/mic-${USER_UID}.lock"
MIC_SOCK_FILE="${XDG_RUNTIME_DIR}/mic-${USER_UID}.sock"

if [ ! -f "${MIC_LOCK_FILE}" ]; then
    echo "Setting up virtual microphone..."
    
    # Wait for PulseAudio daemon
    until [ -f "${XDG_RUNTIME_DIR}/pid" ] || [ -f "${XDG_RUNTIME_DIR}/pulse/pid" ]; do
        sleep 0.5
    done
    
    # Create virtual microphone source
    pactl load-module module-pipe-source \
        source_name="virtmic-${USER_UID}" \
        file="${MIC_SOCK_FILE}" \
        source_properties="device.description=VirtualMic-${USER_UID}" \
        format=s16le \
        rate=44100 \
        channels=1 || echo "Warning: Failed to create virtual microphone"
    
    # Set as default source
    pactl set-default-source "virtmic-${USER_UID}" || echo "Warning: Failed to set default microphone"
    
    # Create lock file
    touch "${MIC_LOCK_FILE}"
    echo "Virtual microphone setup completed"
fi

# Change to kclient directory and start the service
cd /kclient

# Apply kclient fixes for audio compatibility
echo "Applying kclient audio fixes..."

# Fix 1: Remove legacy pcm-player.js reference from index.html
if grep -q 'pcm-player.js' /kclient/public/index.html; then
    sed -i '/<script src="public\/js\/pcm-player.js"><\/script>/d' /kclient/public/index.html
    echo "Removed legacy pcm-player.js reference"
fi

# Fix 2: Update audio device to VirtualSpeaker monitor
if grep -q "device: 'auto_null.monitor'" /kclient/index.js; then
    sed -i "s/device: 'auto_null.monitor'/device: 'VirtualSpeaker-${USER_UID}.monitor'/g" /kclient/index.js
    echo "Updated audio device to VirtualSpeaker-${USER_UID}.monitor"
fi

# Fix 3: Keep resize mode as remote for automatic desktop resolution adjustment
# resize=remote: Server desktop resolution changes based on browser window size
# resize=scale: Client-side scaling only (server resolution stays fixed)
# resize=off: No resizing
if ! grep -q 'resize=remote' /kclient/public/index.html; then
    sed -i 's/resize=[a-z]*/resize=remote/g' /kclient/public/index.html
    echo "Set resize mode to remote for automatic resolution adjustment"
fi

# Fix 4: Update microphone socket path to use environment variable
if grep -q "/defaults/mic.sock" /kclient/index.js; then
    sed -i "s|'/defaults/mic.sock'|process.env.MICROPHONE_SOCKET \|\| '${MIC_SOCK_FILE}'|g" /kclient/index.js
    echo "Updated microphone socket path to ${MIC_SOCK_FILE}"
fi

# Set environment with dynamic port
export PORT=${KCLIENT_PORT}
export MICROPHONE_SOCKET="${MIC_SOCK_FILE}"
export AUDIO_PORT=${KASMAUDIO_PORT}

echo "Starting kclient on port ${KCLIENT_PORT}..."

# Start kclient with audio and microphone support
exec node index.js