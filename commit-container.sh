#!/bin/bash
# Commit container changes to a new image

set -e

CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
# Default tag without timestamp for easy reuse (can be overridden with COMMIT_TAG env var)
COMMIT_TAG="${COMMIT_TAG:-24.04}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-devcontainer-ubuntu-egl-desktop-$(whoami)}"
RESTART="${1:-no}"  # Pass "restart" as first argument to auto-restart

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

# Restart with new image if requested
if [ "${RESTART}" = "restart" ]; then
    echo "Stopping and removing old container..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    
    echo "Starting new container with committed image..."
    IMAGE_NAME="${BASE_IMAGE_NAME}:${COMMIT_TAG}" ./start-container.sh "$@"
else
    echo "To use this image:"
    echo "  IMAGE_NAME=${BASE_IMAGE_NAME}:${COMMIT_TAG} ./start-container.sh [--gpu <type>] [--vnc]"
    echo ""
    echo "To restart with this image:"
    echo "  ./commit-container.sh restart [--gpu <type>] [--vnc]"
    echo "========================================"
fi
