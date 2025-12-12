#!/bin/bash
# Push base image to GitHub Container Registry

set -e

DISTRIB_RELEASE="${DISTRIB_RELEASE:-24.04}"
REGISTRY="${REGISTRY:-ghcr.io}"
GITHUB_USER="${GITHUB_USER:-tatsuyai713}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-${REGISTRY}/${GITHUB_USER}/devcontainer-ubuntu-egl-desktop-base}"
PUSH_LATEST="${PUSH_LATEST:-false}"

LOCAL_IMAGE="${BASE_IMAGE_NAME}:${DISTRIB_RELEASE}"
REMOTE_IMAGE="${REGISTRY}/${GITHUB_USER}/${BASE_IMAGE_NAME}:${DISTRIB_RELEASE}"
REMOTE_LATEST="${REGISTRY}/${GITHUB_USER}/${BASE_IMAGE_NAME}:latest"

echo "========================================"
echo "Push Base Image to GitHub Registry"
echo "========================================"
echo "Local image: ${LOCAL_IMAGE}"
echo "Remote image: ${REMOTE_IMAGE}"
if [ "${PUSH_LATEST}" = "true" ]; then
    echo "Also push as: ${REMOTE_LATEST}"
fi
echo "========================================"
echo ""

# Check if local image exists
if ! docker images -q "${LOCAL_IMAGE}" > /dev/null 2>&1; then
    echo "Error: Local image '${LOCAL_IMAGE}' not found!"
    echo ""
    echo "Please build the base image first:"
    echo "  cd files && ./build-base-image.sh"
    echo ""
    exit 1
fi

# Tag the image for remote registry
echo "Tagging image..."
docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"

if [ "${PUSH_LATEST}" = "true" ]; then
    docker tag "${LOCAL_IMAGE}" "${REMOTE_LATEST}"
fi

# Push to registry
echo ""
echo "Pushing to GitHub Container Registry..."
echo "Note: You must be logged in to GitHub Container Registry"
echo "  docker login ghcr.io -u ${GITHUB_USER}"
echo ""

docker push "${REMOTE_IMAGE}"

if [ "${PUSH_LATEST}" = "true" ]; then
    docker push "${REMOTE_LATEST}"
fi

echo ""
echo "========================================"
echo "Base image pushed successfully!"
echo "========================================"
echo "Image: ${REMOTE_IMAGE}"
if [ "${PUSH_LATEST}" = "true" ]; then
    echo "       ${REMOTE_LATEST}"
fi
echo ""
echo "To use this image in build-user-image.sh:"
echo "  BASE_IMAGE_NAME=${REGISTRY}/${GITHUB_USER}/devcontainer-ubuntu-egl-desktop-base \\"
echo "  BASE_IMAGE_TAG=${DISTRIB_RELEASE} \\"
echo "  ./build-user-image.sh"
echo "========================================"
