#!/bin/bash
# Stop the running container

CONTAINER_NAME="${CONTAINER_NAME:-devcontainer-egl-desktop-$(whoami)}"
REMOVE="${1:-no}"  # Pass "rm" or "remove" as first argument to also delete the container

echo "Stopping container: ${CONTAINER_NAME}"
docker stop "${CONTAINER_NAME}" || echo "Container '${CONTAINER_NAME}' not found or already stopped"

# Remove container if requested
if [ "${REMOVE}" = "rm" ] || [ "${REMOVE}" = "remove" ]; then
    echo "Removing container: ${CONTAINER_NAME}"
    docker rm "${CONTAINER_NAME}" || echo "Container '${CONTAINER_NAME}' not found"
fi
