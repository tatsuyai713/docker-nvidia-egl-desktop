#!/bin/bash
# Install a CA certificate into the system trust store (Debian/Ubuntu).

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo or as root."
    exit 1
fi

DEFAULT_CA_CERT_FILE="ssl/ca.crt"
read -p "CA certificate path [${DEFAULT_CA_CERT_FILE}]: " CA_CERT_FILE
CA_CERT_FILE="${CA_CERT_FILE:-${DEFAULT_CA_CERT_FILE}}"

if [ ! -f "${CA_CERT_FILE}" ]; then
    echo "Error: CA certificate not found at ${CA_CERT_FILE}"
    exit 1
fi

DEFAULT_INSTALL_NAME="$(basename "${CA_CERT_FILE}")"
DEFAULT_INSTALL_NAME="${DEFAULT_INSTALL_NAME%.*}"
read -p "Install name (used under /usr/local/share/ca-certificates) [${DEFAULT_INSTALL_NAME}]: " INSTALL_NAME
INSTALL_NAME="${INSTALL_NAME:-${DEFAULT_INSTALL_NAME}}"

INSTALL_PATH="/usr/local/share/ca-certificates/${INSTALL_NAME}.crt"

# Remove existing certificate if present
if [ -f "${INSTALL_PATH}" ]; then
    echo "Removing existing CA certificate at ${INSTALL_PATH}..."
    rm -f "${INSTALL_PATH}"
    if command -v update-ca-certificates >/dev/null 2>&1; then
        echo "Refreshing trust store after removal..."
        update-ca-certificates
    fi
fi

echo "Copying CA certificate to ${INSTALL_PATH}..."
cp "${CA_CERT_FILE}" "${INSTALL_PATH}"
chmod 644 "${INSTALL_PATH}"

if ! command -v update-ca-certificates >/dev/null 2>&1; then
    echo "Warning: update-ca-certificates not found. Please install ca-certificates package."
    exit 1
fi

echo "Updating system trust store..."
update-ca-certificates

CERT_ALIAS="${INSTALL_NAME}"
if command -v certutil >/dev/null 2>&1; then
    TARGET_USER="${SUDO_USER:-}"
    if [ -n "${TARGET_USER}" ]; then
        echo "Installing CA into ${TARGET_USER}'s NSS (Chrome/Chromium) store..."
        su - "${TARGET_USER}" -c '
            set -e
            CERT_PATH="'"${INSTALL_PATH}"'"
            DB_DIR="$HOME/.pki/nssdb"
            mkdir -p "${DB_DIR}"
            if [ ! -f "${DB_DIR}/cert9.db" ]; then
                certutil -d "sql:${DB_DIR}" -N --empty-password
            fi
            certutil -d "sql:${DB_DIR}" -D -n "'"${CERT_ALIAS}"'" >/dev/null 2>&1 || true
            certutil -d "sql:${DB_DIR}" -A -t "CT,c,c" -n "'"${CERT_ALIAS}"'" -i "${CERT_PATH}"
        '
    else
        echo "Note: certutil found but SUDO_USER is empty; skipping user NSS store install."
    fi
else
    echo "Note: certutil not found; skipping Chrome/Chromium NSS store installation."
fi

echo "========================================"
echo "CA certificate installed."
echo "Stored as: ${INSTALL_PATH}"
echo "You may need to restart your browser for changes to take effect."
echo "========================================"
