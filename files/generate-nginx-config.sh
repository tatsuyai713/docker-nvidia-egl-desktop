#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

echo "Generating multi-user nginx configuration..."

# Multi-user port configuration based on UID
# External-facing nginx port uses NGINX_PORT from environment (default 8080)
# This aligns with Selkies/noVNC which also use NGINX_PORT
NGINX_KASM_PORT=${NGINX_PORT:-8080}

# HTTPS configuration (default enabled for security)
ENABLE_HTTPS=${SELKIES_ENABLE_HTTPS:-true}

# Internal ports are fixed
KASMVNC_PORT=8081
KCLIENT_PORT=3000
KASMAUDIO_PORT=4900

USER_UID=$(id -u)

echo "Nginx configuration for KasmVNC: UID=${USER_UID}, HTTPS=$(echo ${ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')"
echo "Nginx Port=${NGINX_KASM_PORT}, KasmVNC=${KASMVNC_PORT}, kclient=${KCLIENT_PORT}, audio=${KASMAUDIO_PORT}"

# Create user-specific nginx configuration
cat > "${XDG_RUNTIME_DIR}/nginx/nginx-kclient.conf" << EOF
pid ${XDG_RUNTIME_DIR}/nginx/nginx.pid;
error_log /dev/stderr;

events {
    worker_connections 768;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # WebSocket upgrade mapping
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    access_log /dev/stdout;
    error_log /dev/stderr;
    
    server {
        listen ${NGINX_KASM_PORT} $(if [ "$(echo ${ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')" = "true" ]; then echo -n "ssl"; fi) default_server;
        listen [::]:${NGINX_KASM_PORT} $(if [ "$(echo ${ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')" = "true" ]; then echo -n "ssl"; fi) default_server;
        
        ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
        ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
        
        # NGINX Basic Authentication (unified authentication for all KasmVNC access)
$(if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH:-true} | tr '[:upper:]' '[:lower:]')" != "false" ]; then echo "        auth_basic \"Selkies\";"; echo "        auth_basic_user_file ${XDG_RUNTIME_DIR}/.htpasswd;"; fi)
    
    # KasmVNC audio WebSocket endpoint (kasmbins) - must be before / location
    location /kasmaudio/ {
        proxy_pass http://localhost:${KASMAUDIO_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # kclient for audio integration - must be before / location
    location /kclient/ {
        proxy_pass http://localhost:${KCLIENT_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # Microphone socket endpoint - must be before / location
    location /mic {
        proxy_pass http://localhost:${KCLIENT_PORT}/mic;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # Test page for audio debugging
    location /test-audio {
        default_type text/html;
        alias /tmp/test-audio.html;
    }
    
    # KasmVNC WebSocket endpoint (/websockify) - used by VNC client in iframe
    location /websockify {
        proxy_pass https://localhost:${KASMVNC_PORT}/websockify;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }
    
    # KasmVNC static files and API - direct access (for iframe)
    location /vnc/ {
        proxy_pass https://localhost:${KASMVNC_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }
    
    # kclient static files (public directory)
    location /public/ {
        proxy_pass http://localhost:${KCLIENT_PORT}/public/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # kclient audio endpoint
    location /audio/ {
        proxy_pass http://localhost:${KCLIENT_PORT}/audio/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # kclient file browser (with WebSocket support for Socket.IO)
    location /files {
        proxy_pass http://localhost:${KCLIENT_PORT}/files;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Proxy root to kclient (audio wrapper with KasmVNC iframe)
    location / {
        proxy_pass http://localhost:${KCLIENT_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }
}
}
EOF

echo "Multi-user nginx configuration generated at ${XDG_RUNTIME_DIR}/nginx/nginx-kclient.conf"
echo "Available at: http://localhost:${NGINX_KASM_PORT}"
