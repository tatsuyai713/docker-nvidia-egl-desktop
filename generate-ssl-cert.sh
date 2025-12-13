#!/bin/bash
# Generate SSL certificate and key for container

set -e

echo "========================================"
echo "SSL Certificate Generator"
echo "========================================"
echo ""
echo "This script will generate a self-signed SSL certificate"
echo "and private key for use with the container."
echo ""

# Default values
DEFAULT_COUNTRY="US"
DEFAULT_STATE="State"
DEFAULT_CITY="City"
DEFAULT_ORG="Organization"
DEFAULT_CN="localhost"
DEFAULT_DAYS="365"
DEFAULT_CERT_FILE="ssl/cert.pem"
DEFAULT_KEY_FILE="ssl/key.pem"

# Get user input
read -p "Country Name (2 letter code) [${DEFAULT_COUNTRY}]: " COUNTRY
COUNTRY="${COUNTRY:-${DEFAULT_COUNTRY}}"

read -p "State or Province Name [${DEFAULT_STATE}]: " STATE
STATE="${STATE:-${DEFAULT_STATE}}"

read -p "City or Locality Name [${DEFAULT_CITY}]: " CITY
CITY="${CITY:-${DEFAULT_CITY}}"

read -p "Organization Name [${DEFAULT_ORG}]: " ORG
ORG="${ORG:-${DEFAULT_ORG}}"

read -p "Common Name (hostname/IP) [${DEFAULT_CN}]: " CN
CN="${CN:-${DEFAULT_CN}}"

read -p "Validity period in days [${DEFAULT_DAYS}]: " DAYS
DAYS="${DAYS:-${DEFAULT_DAYS}}"

read -p "Certificate output file [${DEFAULT_CERT_FILE}]: " CERT_FILE
CERT_FILE="${CERT_FILE:-${DEFAULT_CERT_FILE}}"

read -p "Private key output file [${DEFAULT_KEY_FILE}]: " KEY_FILE
KEY_FILE="${KEY_FILE:-${DEFAULT_KEY_FILE}}"

echo ""
echo "========================================"
echo "Certificate Configuration"
echo "========================================"
echo "Country: ${COUNTRY}"
echo "State: ${STATE}"
echo "City: ${CITY}"
echo "Organization: ${ORG}"
echo "Common Name: ${CN}"
echo "Validity: ${DAYS} days"
echo "Certificate file: ${CERT_FILE}"
echo "Private key file: ${KEY_FILE}"
echo "========================================"
echo ""

read -p "Generate certificate with these settings? (y/n) [y]: " CONFIRM
CONFIRM="${CONFIRM:-y}"

if [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Generating certificate..."
echo ""

# Create ssl directory if it doesn't exist
SSL_DIR="$(dirname "${CERT_FILE}")"
if [ ! -d "${SSL_DIR}" ]; then
    mkdir -p "${SSL_DIR}"
    echo "Created directory: ${SSL_DIR}"
fi

# Generate certificate and key
openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
    -keyout "${KEY_FILE}" -out "${CERT_FILE}" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/CN=${CN}"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Certificate generated successfully!"
    echo "========================================"
    echo "Certificate: ${CERT_FILE}"
    echo "Private key: ${KEY_FILE}"
    echo ""
    echo "To use with container:"
    echo "  ENABLE_HTTPS=true \\"
    echo "    CERT_PATH=$(pwd)/${CERT_FILE} \\"
    echo "    KEY_PATH=$(pwd)/${KEY_FILE} \\"
    echo "    ./start-container.sh --gpu all"
    echo ""
    echo "Or for KasmVNC:"
    echo "  ENABLE_HTTPS=true \\"
    echo "    CERT_PATH=$(pwd)/${CERT_FILE} \\"
    echo "    KEY_PATH=$(pwd)/${KEY_FILE} \\"
    echo "    ./start-container.sh -g all --vnc"
    echo "========================================"
else
    echo ""
    echo "Error: Failed to generate certificate"
    exit 1
fi
