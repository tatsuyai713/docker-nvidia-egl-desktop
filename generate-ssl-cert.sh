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
DEFAULT_CA_CN="DevContainer Local CA"
DEFAULT_DAYS="365"
DEFAULT_CERT_FILE="ssl/cert.pem"
DEFAULT_KEY_FILE="ssl/key.pem"
DEFAULT_CA_CERT_FILE="ssl/ca.crt"
DEFAULT_CA_KEY_FILE="ssl/ca.key"
DEFAULT_SAN_DNS="localhost"
DEFAULT_SAN_IP="127.0.0.1"

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

read -p "Certificate Authority Common Name [${DEFAULT_CA_CN}]: " CA_CN
CA_CN="${CA_CN:-${DEFAULT_CA_CN}}"

read -p "CA certificate output file [${DEFAULT_CA_CERT_FILE}]: " CA_CERT_FILE
CA_CERT_FILE="${CA_CERT_FILE:-${DEFAULT_CA_CERT_FILE}}"

read -p "CA private key output file [${DEFAULT_CA_KEY_FILE}]: " CA_KEY_FILE
CA_KEY_FILE="${CA_KEY_FILE:-${DEFAULT_CA_KEY_FILE}}"

read -p "Subject Alternative DNS names (comma separated) [${DEFAULT_SAN_DNS}]: " SAN_DNS_INPUT
SAN_DNS_INPUT="${SAN_DNS_INPUT:-${DEFAULT_SAN_DNS}}"

read -p "Subject Alternative IP addresses (comma separated) [${DEFAULT_SAN_IP}]: " SAN_IP_INPUT
SAN_IP_INPUT="${SAN_IP_INPUT:-${DEFAULT_SAN_IP}}"

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
echo "CA Common Name: ${CA_CN}"
echo "CA Certificate file: ${CA_CERT_FILE}"
echo "CA Private key file: ${CA_KEY_FILE}"
echo "SAN DNS: ${SAN_DNS_INPUT}"
echo "SAN IPs: ${SAN_IP_INPUT}"
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

# Build SAN string
SAN_ENTRIES=()

if [ -n "${SAN_DNS_INPUT}" ]; then
    IFS=',' read -ra SAN_DNS_ARRAY <<< "${SAN_DNS_INPUT}"
    for entry in "${SAN_DNS_ARRAY[@]}"; do
        TRIMMED_ENTRY="$(echo "${entry}" | xargs)"
        if [ -n "${TRIMMED_ENTRY}" ]; then
            SAN_ENTRIES+=("DNS:${TRIMMED_ENTRY}")
        fi
    done
fi

if [ -n "${SAN_IP_INPUT}" ]; then
    IFS=',' read -ra SAN_IP_ARRAY <<< "${SAN_IP_INPUT}"
    for entry in "${SAN_IP_ARRAY[@]}"; do
        TRIMMED_ENTRY="$(echo "${entry}" | xargs)"
        if [ -n "${TRIMMED_ENTRY}" ]; then
            SAN_ENTRIES+=("IP:${TRIMMED_ENTRY}")
        fi
    done
fi

# Ensure CN is included in SANs
if [[ "${CN}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    CN_SAN="IP:${CN}"
else
    CN_SAN="DNS:${CN}"
fi

CN_PRESENT=false
for entry in "${SAN_ENTRIES[@]}"; do
    if [ "${entry}" == "${CN_SAN}" ]; then
        CN_PRESENT=true
        break
    fi
done

if [ "${CN_PRESENT}" = false ]; then
    SAN_ENTRIES+=("${CN_SAN}")
fi

SAN_STRING=$(IFS=','; echo "${SAN_ENTRIES[*]}")

echo ""
echo "Generating certificates..."
echo ""

# Prepare cleanup for temporary files
CSR_FILE="$(mktemp)"
EXT_FILE="$(mktemp)"
cleanup() {
    rm -f "${CSR_FILE}" "${EXT_FILE}"
}
trap cleanup EXIT

# Create directories if they don't exist
SSL_DIR="$(dirname "${CERT_FILE}")"
if [ ! -d "${SSL_DIR}" ]; then
    mkdir -p "${SSL_DIR}"
    echo "Created directory: ${SSL_DIR}"
fi

CA_SSL_DIR="$(dirname "${CA_CERT_FILE}")"
if [ ! -d "${CA_SSL_DIR}" ]; then
    mkdir -p "${CA_SSL_DIR}"
    echo "Created directory: ${CA_SSL_DIR}"
fi

echo "Generating CA certificate..."
openssl req -x509 -nodes -days ${DAYS} -newkey rsa:4096 \
    -keyout "${CA_KEY_FILE}" -out "${CA_CERT_FILE}" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/CN=${CA_CN}" \
    -addext "basicConstraints=critical,CA:true" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash"

# Generate server key and CSR
echo "Generating server key and CSR..."
openssl req -new -nodes -newkey rsa:2048 \
    -keyout "${KEY_FILE}" -out "${CSR_FILE}" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/CN=${CN}" \
    -addext "subjectAltName=${SAN_STRING}"

cat > "${EXT_FILE}" <<EOF
subjectAltName=${SAN_STRING}
extendedKeyUsage=serverAuth
keyUsage=digitalSignature,keyEncipherment
basicConstraints=critical,CA:false
EOF

# Sign server certificate with CA
echo "Signing server certificate..."
openssl x509 -req -in "${CSR_FILE}" -CA "${CA_CERT_FILE}" -CAkey "${CA_KEY_FILE}" \
    -CAcreateserial -out "${CERT_FILE}" -days ${DAYS} -sha256 -extfile "${EXT_FILE}"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Certificate generated successfully!"
    echo "========================================"
    echo "CA Certificate: ${CA_CERT_FILE}"
    echo "CA Private key: ${CA_KEY_FILE}"
    echo "Server certificate: ${CERT_FILE}"
    echo "Server private key: ${KEY_FILE}"
    echo ""
    echo "Next steps:"
    echo "  1. Trust the new CA on each client. On Debian/Ubuntu:"
    echo "       sudo ./install-ca-cert.sh"
    echo "  2. Use the server certificate with the container:"
    echo "To use with container:"
    echo "  ENABLE_HTTPS=true \\"
    echo "    CERT_PATH=$(pwd)/${CERT_FILE} \\"
    echo "    KEY_PATH=$(pwd)/${KEY_FILE} \\"
    echo "    ./start-container.sh --gpu nvidia --all"
    echo ""
    echo "Or for KasmVNC:"
    echo "  ENABLE_HTTPS=true \\"
    echo "    CERT_PATH=$(pwd)/${CERT_FILE} \\"
    echo "    KEY_PATH=$(pwd)/${KEY_FILE} \\"
    echo "    ./start-container.sh --gpu nvidia --all --vnc"
    echo "========================================"
else
    echo ""
    echo "Error: Failed to generate certificate"
    exit 1
fi
