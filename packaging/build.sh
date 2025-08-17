#!/usr/bin/env bash
# POC build orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACT_DIR="$SCRIPT_DIR/deps-artifacts"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }

ACTION="${1:-build}"
FORCE_REBUILD="${2:-false}"

show_usage() {
    echo "Usage: $0 [action] [force-rebuild]"
    echo ""
    echo "Actions:"
    echo "  deps      - Build dependency artifacts if missing"
    echo "  build     - Build PiTrac using artifacts (default)"
    echo "  all       - Build deps then PiTrac"
    echo "  clean     - Remove all artifacts and Docker images"
    echo "  shell     - Interactive shell with artifacts"
    echo ""
    echo "Options:"
    echo "  force-rebuild - Force rebuild even if artifacts exist"
    echo ""
    echo "Examples:"
    echo "  $0              # Build PiTrac (deps must exist)"
    echo "  $0 deps         # Build dependency artifacts"
    echo "  $0 all          # Build everything from scratch"
    echo "  $0 all true     # Force rebuild everything"
}

check_artifacts() {
    local missing=()
    
    log_info "Checking for pre-built artifacts..."
    
    if [ ! -f "$ARTIFACT_DIR/opencv-4.11.0-arm64.tar.gz" ]; then
        missing+=("opencv")
    fi
    if [ ! -f "$ARTIFACT_DIR/activemq-cpp-3.9.5-arm64.tar.gz" ]; then
        missing+=("activemq")
    fi
    if [ ! -f "$ARTIFACT_DIR/lgpio-0.2.2-arm64.tar.gz" ]; then
        missing+=("lgpio")
    fi
    if [ ! -f "$ARTIFACT_DIR/msgpack-cxx-6.1.1-arm64.tar.gz" ]; then
        missing+=("msgpack")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing artifacts: ${missing[*]}"
        return 1
    else
        log_success "All artifacts present"
        return 0
    fi
}

build_deps() {
    log_info "Building dependency artifacts..."
    
    if [ "$FORCE_REBUILD" = "true" ]; then
        log_warn "Force rebuild enabled - removing existing artifacts"
        rm -f "$ARTIFACT_DIR"/*.tar.gz
    fi
    
    # Build all dependencies
    "$SCRIPT_DIR/scripts/build-all-deps.sh"
}

build_pitrac() {
    log_info "Building PiTrac with pre-built artifacts..."
    
    # Check artifacts exist
    if ! check_artifacts; then
        log_error "Missing dependency artifacts. Run: $0 deps"
        exit 1
    fi
    
    # Build Docker image
    log_info "Building PiTrac Docker image..."
    docker build \
        --platform=linux/arm64 \
        -f "$SCRIPT_DIR/Dockerfile.pitrac" \
        -t pitrac-poc:arm64 \
        "$SCRIPT_DIR"
    
    # Run build
    log_info "Running PiTrac build..."
    docker run \
        --rm \
        --platform=linux/arm64 \
        -v "$REPO_ROOT:/build:rw" \
        -u "$(id -u):$(id -g)" \
        pitrac-poc:arm64
    
    # Check result
    BINARY="$REPO_ROOT/Software/LMSourceCode/ImageProcessing/build/pitrac_lm"
    if [ -f "$BINARY" ]; then
        log_success "Build successful!"
        log_info "Binary: $BINARY"
        log_info "Size: $(du -h "$BINARY" | cut -f1)"
        file "$BINARY"
    else
        log_error "Build failed - binary not found"
        exit 1
    fi
}

run_shell() {
    log_info "Starting interactive shell with pre-built artifacts..."
    
    # Check artifacts exist
    if ! check_artifacts; then
        log_error "Missing dependency artifacts. Run: $0 deps"
        exit 1
    fi
    
    # Ensure image exists
    if ! docker image inspect pitrac-poc:arm64 &>/dev/null; then
        log_info "Building Docker image first..."
        docker build \
            --platform=linux/arm64 \
            -f "$SCRIPT_DIR/Dockerfile.pitrac" \
            -t pitrac-poc:arm64 \
            "$SCRIPT_DIR"
    fi
    
    docker run \
        --rm -it \
        --platform=linux/arm64 \
        -v "$REPO_ROOT:/build:rw" \
        -u "$(id -u):$(id -g)" \
        pitrac-poc:arm64 \
        /bin/bash
}

clean_all() {
    log_warn "Cleaning all POC artifacts and images..."
    
    # Remove artifacts
    rm -rf "$ARTIFACT_DIR"/*.tar.gz
    rm -rf "$ARTIFACT_DIR"/*.metadata
    
    # Remove Docker images
    docker rmi opencv-builder:arm64 2>/dev/null || true
    docker rmi activemq-builder:arm64 2>/dev/null || true
    docker rmi lgpio-builder:arm64 2>/dev/null || true
    docker rmi pitrac-poc:arm64 2>/dev/null || true
    
    log_success "Cleaned all POC resources"
}

# Main execution
main() {
    log_info "PiTrac POC Build System"
    log_info "Action: $ACTION"
    
    case "$ACTION" in
        deps)
            build_deps
            ;;
        build)
            build_pitrac
            ;;
        all)
            build_deps
            build_pitrac
            ;;
        shell)
            run_shell
            ;;
        clean)
            clean_all
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
    
    log_success "Done!"
}

# Check Docker
if ! command -v docker &>/dev/null; then
    log_error "Docker is required but not installed"
    exit 1
fi

# Ensure artifact directory exists
mkdir -p "$ARTIFACT_DIR"

# Run main
main