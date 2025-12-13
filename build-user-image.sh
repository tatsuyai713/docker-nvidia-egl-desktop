#!/bin/bash
# Build user-specific image from base image

set -e

# Locale configuration - set defaults first
IN_LOCALE="${IN_LOCALE:-US}"
IN_TZ="${IN_TZ:-UTC}"
IN_LANG="${IN_LANG:-en_US.UTF-8}"
IN_LANGUAGE="${IN_LANGUAGE:-en_US:en}"

# Parse command line arguments and override defaults
if [ $# -ge 1 ]; then
    if [ "$1" = "JP" ] || [ "$1" = "jp" ]; then
        IN_LOCALE="JP"
    elif [ "$1" = "US" ] || [ "$1" = "us" ]; then
        IN_LOCALE="US"
    fi
fi

# Set Japanese locale defaults if IN_LOCALE is JP
if [ "${IN_LOCALE}" = "JP" ]; then
    IN_TZ="Asia/Tokyo"
    IN_LANG="ja_JP.UTF-8"
    IN_LANGUAGE="ja_JP:ja"
fi

# Configuration
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ghcr.io/tatsuyai713/devcontainer-ubuntu-egl-desktop-base}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-24.04}"
USER_IMAGE_NAME="${USER_IMAGE_NAME:-devcontainer-ubuntu-egl-desktop}"
USER_IMAGE_TAG="${USER_IMAGE_TAG:-${BASE_IMAGE_TAG}-$(whoami)}"
NO_CACHE="${NO_CACHE:-false}"

# Get current user information
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Prompt for password if not set via environment variable
if [ -z "${USER_PASSWORD}" ]; then
    echo "========================================"
    echo "Password Setup"
    echo "========================================"
    echo "Please set a password for the container user (${CURRENT_USER})."
    echo ""
    
    while true; do
        read -s -p "Enter password: " USER_PASSWORD
        echo ""
        read -s -p "Confirm password: " USER_PASSWORD_CONFIRM
        echo ""
        
        if [ "${USER_PASSWORD}" = "${USER_PASSWORD_CONFIRM}" ]; then
            if [ -z "${USER_PASSWORD}" ]; then
                echo "Error: Password cannot be empty."
                echo ""
            else
                echo "Password set successfully."
                echo ""
                break
            fi
        else
            echo "Error: Passwords do not match. Please try again."
            echo ""
        fi
    done
fi

echo "========================================"
echo "Building User-Specific Image"
echo "========================================"
echo "Base image: ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}"
echo "User image: ${USER_IMAGE_NAME}:${USER_IMAGE_TAG}"
echo "User: ${CURRENT_USER}"
echo "UID: ${CURRENT_UID}"
echo "GID: ${CURRENT_GID}"
echo "Locale: ${IN_LOCALE}"
echo "Timezone: ${IN_TZ}"
echo "Language: ${IN_LANG}"
echo "No cache: ${NO_CACHE}"
echo "========================================"
echo ""

# Check if base image exists
BASE_EXISTS=$(docker images -q "${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}" 2>/dev/null)

if [ -z "${BASE_EXISTS}" ]; then
    echo "Error: Base image '${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}' not found!"
    echo ""
    echo "Please build the base image first:"
    echo "  ./build-base-image.sh"
    echo ""
    exit 1
fi

# Build user-specific image
BUILD_CMD="docker build"

if [ "${NO_CACHE}" = "true" ]; then
    BUILD_CMD="${BUILD_CMD} --no-cache"
fi

BUILD_CMD="${BUILD_CMD} --build-arg BASE_IMAGE=${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}"
BUILD_CMD="${BUILD_CMD} --build-arg USER_NAME=${CURRENT_USER}"
BUILD_CMD="${BUILD_CMD} --build-arg USER_UID=${CURRENT_UID}"
BUILD_CMD="${BUILD_CMD} --build-arg USER_GID=${CURRENT_GID}"
BUILD_CMD="${BUILD_CMD} --build-arg USER_PASSWORD=${USER_PASSWORD}"
BUILD_CMD="${BUILD_CMD} --build-arg IN_LOCALE=${IN_LOCALE}"
BUILD_CMD="${BUILD_CMD} --build-arg IN_TZ=${IN_TZ}"
BUILD_CMD="${BUILD_CMD} --build-arg IN_LANG=${IN_LANG}"
BUILD_CMD="${BUILD_CMD} --build-arg IN_LANGUAGE=${IN_LANGUAGE}"
BUILD_CMD="${BUILD_CMD} -f files/Dockerfile.user"
BUILD_CMD="${BUILD_CMD} -t ${USER_IMAGE_NAME}:${USER_IMAGE_TAG} ."

eval ${BUILD_CMD}

echo ""
echo "========================================"
echo "User image built successfully!"
echo "========================================"
echo "Image: ${USER_IMAGE_NAME}:${USER_IMAGE_TAG}"
echo ""
echo "To start the container:"
echo "  ./start-container.sh"
echo ""
echo "Or use docker-compose:"
echo "  USER_IMAGE=${USER_IMAGE_NAME}:${USER_IMAGE_TAG} docker-compose -f docker-compose.user.yml up"
echo ""
echo "Note: The password you set is stored in the image and will be used automatically."
echo "========================================"
