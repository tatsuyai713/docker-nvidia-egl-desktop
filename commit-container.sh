#!/bin/bash
# Commit container changes to a new image

set -e

CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
COMMIT_TAG="${COMMIT_TAG:-24.04-$(whoami)-$(date +%Y%m%d-%H%M%S)}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-devcontainer-ubuntu-egl-desktop}"

echo "========================================"
echo "Committing Container Changes"
echo "========================================"
echo "Container: ${CONTAINER_NAME}"
echo "New tag: ${BASE_IMAGE_NAME}:${COMMIT_TAG}"
echo "========================================"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' not found"
    exit 1
fi

# Commit the container
docker commit "${CONTAINER_NAME}" "${BASE_IMAGE_NAME}:${COMMIT_TAG}"

echo ""
echo "========================================"
echo "Commit successful!"
echo "========================================"
echo "New image: ${BASE_IMAGE_NAME}:${COMMIT_TAG}"
echo ""
echo "To use this image:"
echo "  IMAGE_NAME=${BASE_IMAGE_NAME}:${COMMIT_TAG} ./start-container.sh"
echo "========================================"
