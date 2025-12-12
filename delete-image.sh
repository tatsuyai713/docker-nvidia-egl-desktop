#!/bin/bash
# Delete the user-specific image

IMAGE_NAME="${IMAGE_NAME:-devcontainer-ubuntu-egl-desktop}"
IMAGE_TAG="${IMAGE_TAG:-24.04-$(whoami)}"
FORCE="${FORCE:-false}"

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Check if image exists
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${FULL_IMAGE_NAME}$"; then
    echo "Image '${FULL_IMAGE_NAME}' does not exist"
    exit 0
fi

# Check if any containers are using this image
CONTAINERS_USING_IMAGE=$(docker ps -a --filter "ancestor=${FULL_IMAGE_NAME}" --format '{{.Names}}' 2>/dev/null)

if [ -n "${CONTAINERS_USING_IMAGE}" ]; then
    if [ "${FORCE}" = "true" ]; then
        echo "Force removing image and associated containers: ${FULL_IMAGE_NAME}"
        echo "Stopping and removing containers: ${CONTAINERS_USING_IMAGE}"
        docker ps -a --filter "ancestor=${FULL_IMAGE_NAME}" -q | xargs -r docker rm -f
        docker rmi -f "${FULL_IMAGE_NAME}"
        echo "Image '${FULL_IMAGE_NAME}' and associated containers removed successfully"
    else
        echo "Image '${FULL_IMAGE_NAME}' is being used by the following containers:"
        echo "${CONTAINERS_USING_IMAGE}"
        echo ""
        echo "Stop and remove containers first, or use FORCE=true to force remove:"
        echo "  FORCE=true ./delete-image.sh"
        exit 1
    fi
else
    echo "Removing image: ${FULL_IMAGE_NAME}"
    docker rmi "${FULL_IMAGE_NAME}"
    echo "Image '${FULL_IMAGE_NAME}' removed successfully"
fi
