#!/bin/bash
# Build TomEE Plume artifact for ARM64
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$POC_DIR/deps-artifacts"

echo "Building TomEE Plume 10.1.0 for ARM64..."
echo "======================================="

cd "$POC_DIR"

# Build the Docker image
echo "Building Docker image..."
docker build --platform=linux/arm64 -f Dockerfile.tomee -t tomee-builder:latest .

# Extract the artifact
echo "Extracting TomEE artifact..."
docker run --rm --platform=linux/arm64 tomee-builder:latest > "$ARTIFACTS_DIR/tomee-10.1.0-plume-arm64.tar.gz"

# Extract metadata
echo "Extracting metadata..."
docker run --rm --platform=linux/arm64 --entrypoint cat tomee-builder:latest /tomee-metadata.txt > "$ARTIFACTS_DIR/tomee-10.1.0-plume-arm64.metadata"

# Verify
echo ""
echo "TomEE artifact created:"
ls -lh "$ARTIFACTS_DIR/tomee-10.1.0-plume-arm64.tar.gz"
echo ""
cat "$ARTIFACTS_DIR/tomee-10.1.0-plume-arm64.metadata"
echo ""
echo "✓ TomEE build complete!"