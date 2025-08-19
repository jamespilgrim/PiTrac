#!/usr/bin/env bash
# Generate Bashly script using Docker
set -euo pipefail

# Build the Bashly Docker image if needed
docker build -f Dockerfile.bashly -t bashly-generator .

# Generate the script (bashly.yml is in root, not src/)
# Also mount settings.yml if it exists
if [[ -f "settings.yml" ]]; then
  docker run --rm \
    -v "$PWD:/app" \
    -v "$PWD/bashly.yml:/app/src/bashly.yml" \
    -v "$PWD/settings.yml:/app/settings.yml" \
    bashly-generator bashly generate
else
  docker run --rm \
    -v "$PWD:/app" \
    -v "$PWD/bashly.yml:/app/src/bashly.yml" \
    bashly-generator bashly generate
fi

# Make the generated script executable
chmod +x pitrac

echo "✓ Generated pitrac script"
echo "Test with: ./pitrac --help"