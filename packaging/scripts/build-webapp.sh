#!/usr/bin/env bash
set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(cd "$POC_DIR/.." && pwd)"
WEBAPP_SOURCE="$REPO_ROOT/Software/LMSourceCode/ImageProcessing/golfsim_tomee_webapp"
BUILD_DIR="$POC_DIR/build/webapp"
ARTIFACTS_DIR="$POC_DIR/deps-artifacts"

VERSION="${WEBAPP_VERSION:-1.0.0}"
ARCH="noarch"
OUTPUT_FILE="golfsim-${VERSION}-${ARCH}.war"
build_webapp() {
    log_info "Building PiTrac Web Application v${VERSION}"
    
    if [[ ! -d "$WEBAPP_SOURCE" ]]; then
        log_error "Web app source not found at $WEBAPP_SOURCE"
        exit 1
    fi
    
    # Clean and create build directory
    log_info "Preparing build environment..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$ARTIFACTS_DIR"
    
    # Copy source files
    log_info "Copying source files..."
    cp -r "$WEBAPP_SOURCE"/* "$BUILD_DIR/"
    
    # Build with Maven in Docker (to avoid local Maven requirement)
    log_info "Building with Maven in Docker..."
    
    # Use --user to avoid permission issues
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$BUILD_DIR:/build" \
        -w /build \
        maven:3.8-openjdk-17 \
        mvn clean package -DskipTests
    
    # Check if build succeeded
    if [[ -f "$BUILD_DIR/target/golfsim.war" ]]; then
        # Copy to artifacts directory
        cp "$BUILD_DIR/target/golfsim.war" "$ARTIFACTS_DIR/$OUTPUT_FILE"
        
        # Create metadata file
        cat > "$ARTIFACTS_DIR/${OUTPUT_FILE}.info" << EOF
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Version: $VERSION
Source: $WEBAPP_SOURCE
Size: $(du -h "$ARTIFACTS_DIR/$OUTPUT_FILE" | cut -f1)
MD5: $(md5sum "$ARTIFACTS_DIR/$OUTPUT_FILE" | cut -d' ' -f1)
EOF
        
        log_success "Web application built successfully!"
        log_success "Output: $ARTIFACTS_DIR/$OUTPUT_FILE"
        
        # Clean up build directory
        rm -rf "$BUILD_DIR"
        
        return 0
    else
        log_error "Failed to build web application"
        return 1
    fi
}

# Parse arguments
case "${1:-build}" in
    build)
        build_webapp
        ;;
    clean)
        log_info "Cleaning webapp build artifacts..."
        rm -rf "$BUILD_DIR"
        rm -f "$ARTIFACTS_DIR/golfsim-*.war"
        rm -f "$ARTIFACTS_DIR/golfsim-*.war.info"
        log_success "Cleaned"
        ;;
    info)
        if [[ -f "$ARTIFACTS_DIR/${OUTPUT_FILE}.info" ]]; then
            cat "$ARTIFACTS_DIR/${OUTPUT_FILE}.info"
        else
            log_warn "No build info found. Run './build-webapp.sh build' first"
        fi
        ;;
    *)
        echo "Usage: $0 {build|clean|info}"
        echo "  build - Build the web application"
        echo "  clean - Remove build artifacts"
        echo "  info  - Show build information"
        exit 1
        ;;
esac