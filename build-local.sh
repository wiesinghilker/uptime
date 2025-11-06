#!/usr/bin/env bash
set -euo pipefail

# Local build script for testing whitelabel Uptime Kuma builds
# Usage: ./build-local.sh [ref] [platform]
# Example: ./build-local.sh master linux/arm64
# Example: ./build-local.sh 2.0.0-beta.0 linux/arm64

REF="${1:-master}"
PLATFORM="${2:-linux/arm64}"
IMAGE_NAME="wiesinghilker/monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
PATCH_FILE="${SCRIPT_DIR}/whitelabel-patches.diff"

echo "======================================"
echo "Local Whitelabel Build"
echo "======================================"
echo "Ref:      ${REF}"
echo "Platform: ${PLATFORM}"
echo "Image:    ${IMAGE_NAME}:${REF}"
echo "======================================"

# Check if patch file exists
if [ ! -f "${PATCH_FILE}" ]; then
    echo "Error: Patch file not found: ${PATCH_FILE}"
    exit 1
fi

# Clean up previous build
if [ -d "${BUILD_DIR}" ]; then
    echo "Cleaning up previous build directory..."
    rm -rf "${BUILD_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Clone upstream at ref
echo ""
echo "Cloning upstream at ref ${REF}..."
git clone --depth 1 --branch "${REF}" https://github.com/louislam/uptime-kuma.git "${BUILD_DIR}/uptime-kuma"
echo "Cloned upstream at ref ${REF}"

# Apply whitelabel patch
echo ""
echo "Applying whitelabel patch..."
cd "${BUILD_DIR}/uptime-kuma"
git apply --index --reject --whitespace=nowarn "${PATCH_FILE}"
echo "Applied whitelabel-patches.diff"

# Build Docker image
echo ""
echo "Building Docker image..."
docker buildx build \
    --platform "${PLATFORM}" \
    --tag "${IMAGE_NAME}:${REF}" \
    --tag "${IMAGE_NAME}:latest" \
    --load \
    --file Dockerfile \
    .

echo ""
echo "======================================"
echo "Build completed successfully!"
echo "======================================"
echo "Images built:"
echo "  - ${IMAGE_NAME}:${REF}"
echo "  - ${IMAGE_NAME}:latest"
echo ""
echo "Test the image with:"
echo "  docker run -p 3001:3001 -v uptime-kuma-data:/app/data ${IMAGE_NAME}:${REF}"
echo ""
echo "Clean up build directory with:"
echo "  rm -rf ${BUILD_DIR}"
echo "======================================"