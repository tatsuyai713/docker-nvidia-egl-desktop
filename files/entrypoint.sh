#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

trap "echo TRAPed signal" HUP INT QUIT TERM

# Wait for XDG_RUNTIME_DIR
until [ -d "${XDG_RUNTIME_DIR}" ]; do sleep 0.5; done
# Change operating system password to environment variable (requires sudo)
if command -v sudo >/dev/null 2>&1; then
  (echo "${PASSWD}"; echo "${PASSWD}";) | sudo passwd "$(id -nu)" 2>/dev/null || echo 'Password change requires root privileges, skipping'
else
  echo 'Password change requires root privileges, skipping'
fi
# Remove directories to make sure the desktop environment starts
rm -rf /tmp/.X* ~/.cache 2>/dev/null || echo 'Failed to clean X11 paths'
# Timezone should be set at container build time or via volume mount
# Add Lutris directories to path
export PATH="${PATH:+${PATH}:}/usr/local/games:/usr/games"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Configure joystick interposer
export SELKIES_INTERPOSER='/usr/$LIB/selkies_joystick_interposer.so'
export LD_PRELOAD="${SELKIES_INTERPOSER}${LD_PRELOAD:+:${LD_PRELOAD}}"
export SDL_JOYSTICK_DEVICE="${XDG_RUNTIME_DIR}/js0"
# Create joystick devices in user-writable location
mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null || true
for i in 0 1 2 3; do
  touch "${XDG_RUNTIME_DIR}/js${i}" 2>/dev/null || true
done

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

if [ "$(echo ${ENABLE_NVIDIA} | tr '[:upper:]' '[:lower:]')" = "true" ] && { [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libEGL_nvidia.so.0')" ] || [ -z "$(ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH) 2>/dev/null | grep 'libGLX_nvidia.so.0')" ]; }; then
  # Install NVIDIA userspace driver components including X graphic libraries, keep contents same between docker-selkies-glx-desktop and docker-selkies-egl-desktop
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    elif command -v nvidia-smi >/dev/null 2>&1; then
      # Use NVIDIA-SMI when not available
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'DRIVER version' | cut -d: -f2 | tr -d ' ')"
    else
      echo 'Failed to find NVIDIA GPU driver version, container will likely not start because of no NVIDIA container toolkit or NVIDIA GPU driver present'
    fi
  fi
  cd /tmp
  # If version is different, new installer will overwrite the existing components
  if [ ! -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Check multiple sources in order to probe both consumer and datacenter driver versions
    curl -fsSL -O "https://international.download.nvidia.com/XFree86/Linux-${NVIDIA_DRIVER_ARCH}/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || curl -fsSL -O "https://international.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || echo 'Failed NVIDIA GPU driver download'
  fi
  if [ -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Extract installer before installing
    rm -rf "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    sh "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" -x
    cd "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
    # Run NVIDIA driver installation without the kernel modules and host components
    if command -v sudo >/dev/null 2>&1; then
      sudo ./nvidia-installer --silent \
                        --no-kernel-module \
                        --install-compat32-libs \
                        --no-nouveau-check \
                        --no-nvidia-modprobe \
                        --no-systemd \
                        --no-rpms \
                        --no-backup \
                        --no-check-for-alternate-installs || echo 'NVIDIA driver installation requires root privileges'
    else
      echo 'NVIDIA driver installation requires sudo, skipping. Drivers should be pre-installed in base image.'
    fi
    rm -rf /tmp/NVIDIA* && cd ~
  else
    echo 'NVIDIA driver installation file not found. If using NVIDIA GPUs, ensure drivers are pre-installed or mounted.'
  fi
elif [ "$(echo ${ENABLE_NVIDIA} | tr '[:upper:]' '[:lower:]')" != "true" ]; then
  echo 'NVIDIA support is disabled (ENABLE_NVIDIA=false). Using software rendering or other GPU vendors.'
fi

# Run Xvfb server with required extensions
# Start with Full HD resolution (1920x1080)
# The actual display size can be adjusted by selkies-gstreamer-resize
/usr/bin/Xvfb "${DISPLAY}" -screen 0 "1920x1080x${DISPLAY_CDEPTH}" -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" +iglx +render -nolisten "tcp" -ac -noreset -shmem &

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Resize the screen to the provided size
/usr/local/bin/selkies-gstreamer-resize "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}"

# Use VirtualGL to run the KDE desktop environment with OpenGL if the GPU is available, otherwise use OpenGL with llvmpipe
export XDG_SESSION_ID="${DISPLAY#*:}"
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-*.debug=false;qt.qpa.*=false}"
if [ "$(echo ${ENABLE_NVIDIA} | tr '[:upper:]' '[:lower:]')" = "true" ] && [ -n "$(nvidia-smi --query-gpu=uuid --format=csv,noheader 2>/dev/null | head -n1)" ]; then
  echo "Starting desktop with NVIDIA GPU acceleration via VirtualGL"
  export VGL_FPS="${DISPLAY_REFRESH}"
  /usr/bin/vglrun -d "${VGL_DISPLAY:-egl}" +wm /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
elif [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
  echo "Starting desktop with GPU acceleration (non-NVIDIA)"
  export VGL_FPS="${DISPLAY_REFRESH}"
  /usr/bin/vglrun -d "${VGL_DISPLAY:-egl}" +wm /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
else
  echo "Starting desktop with software rendering (no GPU acceleration)"
  /usr/bin/dbus-launch --exit-with-session /usr/bin/startplasma-x11 &
fi

# Start Fcitx input method framework
/usr/bin/fcitx &

# Add custom processes right below this line, or within `supervisord.conf` to perform service management similar to systemd

echo "Session Running. Press [Return] to exit."
read
