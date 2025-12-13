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

# Configure KasmVNC
mkdir -pm700 ~/.vnc
(echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}";) | kasmvncpasswd -u "${SELKIES_BASIC_AUTH_USER:-${USER}}" -ow ~/.kasmpasswd
touch ~/.vnc/.de-was-selected ~/.vnc/kasmvnc.yaml

export KASMVNC_DISPLAY="${KASMVNC_DISPLAY:-:21}"
yq -i "
.command_line.prompt = false |
.desktop.resolution.width = ${DISPLAY_SIZEW} |
.desktop.resolution.height = ${DISPLAY_SIZEH} |
.desktop.allow_resize = $(echo ${SELKIES_ENABLE_RESIZE:-true} | tr '[:upper:]' '[:lower:]') |
.desktop.pixel_depth = ${DISPLAY_CDEPTH} |
.encoding.rect_encoding_mode.rectangle_compress_threads = ${KASMVNC_THREADS-0} |
.encoding.max_frame_rate = ${DISPLAY_REFRESH} |
.network.interface = \"127.0.0.1\" |
.network.websocket_port = ${SELKIES_PORT-8081} |
.network.ssl.require_ssl = $(echo ${SELKIES_ENABLE_HTTPS-false} | tr '[:upper:]' '[:lower:]') |
.network.udp.public_ip = \"${TURN_EXTERNAL_IP-$(dig -4 TXT +short @ns1.google.com o-o.myaddr.l.google.com 2>/dev/null | { read output; if [ -z "$output" ] || echo "$output" | grep -q '^;;'; then exit 1; else echo "$(echo $output | sed 's,\",,g')"; fi } || dig -6 TXT +short @ns1.google.com o-o.myaddr.l.google.com 2>/dev/null | { read output; if [ -z "$output" ] || echo "$output" | grep -q '^;;'; then exit 1; else echo "[$(echo $output | sed 's,\",,g')]"; fi } || hostname -I 2>/dev/null | awk '{print $1; exit}' || echo '127.0.0.1')}\"
" ~/.vnc/kasmvnc.yaml

if [ -n "${SELKIES_HTTPS_CERT}" ]; then yq -i ".network.ssl.pem_certificate = \"${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem}\"" ~/.vnc/kasmvnc.yaml; fi
if [ -n "${SELKIES_HTTPS_KEY}" ]; then yq -i ".network.ssl.pem_key = \"${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}\"" ~/.vnc/kasmvnc.yaml; fi

if [ "$(echo ${SELKIES_ENABLE_RESIZE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASMVNC_PROXY_FLAG="${KASMVNC_PROXY_FLAG} -r"; fi

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Configure NGINX
if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" != "false" ]; then htpasswd -bcm "${XDG_RUNTIME_DIR}/.htpasswd" "${SELKIES_BASIC_AUTH_USER:-${USER}}" "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; fi

# Write NGINX config to user-writable location first
mkdir -p "${XDG_RUNTIME_DIR}/nginx" 2>/dev/null
echo "# Selkies KasmVNC NGINX Configuration
server {
    access_log /dev/stdout;
    error_log /dev/stderr;
    listen ${NGINX_PORT:-8080} $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "ssl"; fi);
    listen [::]:${NGINX_PORT:-8080} $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "ssl"; fi);
    ssl_certificate ${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem};
    ssl_certificate_key ${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key};
    $(if [ \"$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')\" != \"false\" ]; then echo "auth_basic \"Selkies\";"; echo -n "    auth_basic_user_file ${XDG_RUNTIME_DIR}/.htpasswd;"; fi)

    location / {
        proxy_set_header        Upgrade \$http_upgrade;
        proxy_set_header        Connection \"upgrade\";

        proxy_set_header        Host \$host;
        proxy_set_header        X-Real-IP 127.0.0.1;
        proxy_set_header        X-Forwarded-For 127.0.0.1;
        proxy_set_header        X-Forwarded-Proto \$scheme;

        proxy_http_version      1.1;
        proxy_read_timeout      3600s;
        proxy_send_timeout      3600s;
        proxy_connect_timeout   3600s;
        proxy_buffering         off;

        client_max_body_size    10M;

        proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then echo -n "s"; fi)://localhost:${SELKIES_PORT:-8081};
    }
}" > "${XDG_RUNTIME_DIR}/nginx/default.conf"

# Try to copy to system location if we have permissions
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  sudo cp "${XDG_RUNTIME_DIR}/nginx/default.conf" /etc/nginx/sites-available/default 2>/dev/null || \
    echo "Cannot write to /etc/nginx, using config from ${XDG_RUNTIME_DIR}/nginx/"
elif [ -w /etc/nginx/sites-available/default ]; then
  cp "${XDG_RUNTIME_DIR}/nginx/default.conf" /etc/nginx/sites-available/default
else
  echo "Warning: Cannot write NGINX config to /etc/nginx. NGINX must be pre-configured or run with user permissions."
fi

# Run KasmVNC
if ls ~/.vnc/*\:"${KASMVNC_DISPLAY#*:}".pid >/dev/null 2>&1; then kasmvncserver -kill "${KASMVNC_DISPLAY}"; fi

# Start KasmVNC server without keyboard options (they are not supported as command-line arguments)
kasmvncserver "${KASMVNC_DISPLAY}" -geometry "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" -depth "${DISPLAY_CDEPTH}" -noxstartup -FrameRate "${DISPLAY_REFRESH}" -RectThreads "${KASMVNC_THREADS}" -interface 127.0.0.1 -websocketPort "${SELKIES_PORT:-8081}" -disableBasicAuth -AlwaysShared -BlacklistTimeout 0 ${KASMVNC_FLAG}

until [ -S "/tmp/.X11-unix/X${KASMVNC_DISPLAY#*:}" ]; do sleep 0.5; done;

# Apply keyboard layout after KasmVNC X server is ready
if [ -n "${KEYBOARD_LAYOUT}" ]; then
    echo "Configuring KasmVNC keyboard: layout=${KEYBOARD_LAYOUT}, model=${KEYBOARD_MODEL:-pc105}${KEYBOARD_VARIANT:+, variant=${KEYBOARD_VARIANT}}"
    if [ -n "${KEYBOARD_VARIANT}" ]; then
        setxkbmap -display "${KASMVNC_DISPLAY}" -layout "${KEYBOARD_LAYOUT}" -variant "${KEYBOARD_VARIANT}" -model "${KEYBOARD_MODEL:-pc105}" 2>/dev/null || echo "Warning: setxkbmap failed"
    else
        setxkbmap -display "${KASMVNC_DISPLAY}" -layout "${KEYBOARD_LAYOUT}" -model "${KEYBOARD_MODEL:-pc105}" 2>/dev/null || echo "Warning: setxkbmap failed"
    fi
fi

kasmxproxy -a "${DISPLAY}" -v "${KASMVNC_DISPLAY}" -f "${DISPLAY_REFRESH}" ${KASMVNC_PROXY_FLAG}
