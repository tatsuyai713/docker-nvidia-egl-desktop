#!/bin/bash
# Build base image only (system packages, no user configuration)

set -e

DISTRIB_RELEASE="${DISTRIB_RELEASE:-24.04}"
REGISTRY="${REGISTRY:-ghcr.io}"
GITHUB_USER="${GITHUB_USER:-tatsuyai713}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-${REGISTRY}/${GITHUB_USER}/devcontainer-ubuntu-egl-desktop-base}"
NO_CACHE="${NO_CACHE:-false}"

echo "========================================"
echo "Building Base Image"
echo "========================================"
echo "Distribution: Ubuntu ${DISTRIB_RELEASE}"
echo "Image name: ${BASE_IMAGE_NAME}:${DISTRIB_RELEASE}"
echo "No cache: ${NO_CACHE}"
echo "========================================"
echo ""
echo "This may take 30-60 minutes on first build..."
echo ""

# Build base image
BUILD_CMD="docker build -f Dockerfile.base"

if [ "${NO_CACHE}" = "true" ]; then
    BUILD_CMD="${BUILD_CMD} --no-cache"
fi

BUILD_CMD="${BUILD_CMD} --build-arg DISTRIB_RELEASE=${DISTRIB_RELEASE}"
BUILD_CMD="${BUILD_CMD} -t ${BASE_IMAGE_NAME}:${DISTRIB_RELEASE} .."

eval ${BUILD_CMD}

echo ""
echo "========================================"
echo "Base image built successfully!"
echo "========================================"
echo "Image: ${BASE_IMAGE_NAME}:${DISTRIB_RELEASE}"
echo ""
echo "Next step: Build user-specific image"
echo "  ./build-user-image.sh"
echo "========================================"
