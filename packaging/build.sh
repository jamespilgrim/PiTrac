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

# Setup QEMU for cross-platform builds
setup_qemu() {
    if ! docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/null; then
        log_warn "Setting up QEMU for ARM64 emulation..."
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    fi
}

ACTION="${1:-build}"
FORCE_REBUILD="${2:-false}"

show_usage() {
    echo "Usage: $0 [action] [force-rebuild]"
    echo ""
    echo "Actions:"
    echo "  deps      - Build dependency artifacts if missing"
    echo "  build     - Build PiTrac using artifacts (default)"
    echo "  all       - Build deps then PiTrac"
    echo "  dev       - Build and install directly on Pi (for development)"
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
    echo "  $0 dev          # Build and install on Pi for testing"
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
    
    # Setup QEMU for ARM64 emulation on x86_64
    setup_qemu
    
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
    
    # Setup QEMU for ARM64 emulation on x86_64
    setup_qemu
    
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

build_dev() {
    log_info "PiTrac Development Build - Direct Pi Installation"
    
    # Check if running on Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_error "Dev mode must be run on a Raspberry Pi"
        exit 1
    fi
    
    # Check for sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "Dev mode requires root privileges to install to system locations"
        log_info "Please run: sudo $0 dev"
        exit 1
    fi
    
    # Check artifacts exist
    if ! check_artifacts; then
        log_error "Missing dependency artifacts. These should be in git."
        log_error "Try: git lfs pull"
        exit 1
    fi
    
    # Check build dependencies (matching Dockerfile.pitrac)
    log_info "Checking build dependencies..."
    local missing_deps=()
    
    # Build tools
    for pkg in build-essential meson ninja-build pkg-config git; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # Boost libraries (runtime and dev)
    for pkg in libboost-system1.74.0 libboost-thread1.74.0 libboost-filesystem1.74.0 \
               libboost-program-options1.74.0 libboost-timer1.74.0 libboost-log1.74.0 \
               libboost-regex1.74.0 libboost-dev; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # Core libraries
    for pkg in libcamera0.0.3 libcamera-dev libfmt-dev libssl-dev libssl3 \
               liblgpio-dev liblgpio1 libmsgpack-cxx-dev \
               libapr1 libaprutil1 libapr1-dev libaprutil1-dev; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # OpenCV runtime dependencies
    for pkg in libgtk-3-0 libavcodec59 libavformat59 libswscale6 libtbb12 \
               libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libopenexr-3-1-30; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # FFmpeg development libraries
    for pkg in libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libavdevice-dev; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # Image libraries
    for pkg in libexif-dev libjpeg-dev libtiff-dev libpng-dev; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    # Display/GUI libraries
    for pkg in libdrm-dev libx11-dev libxext-dev libepoxy-dev qtbase5-dev qt5-qmake; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_deps+=("$pkg")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "Missing build dependencies: ${missing_deps[*]}"
        log_info "Installing missing dependencies..."
        apt-get update
        apt-get install -y "${missing_deps[@]}"
    fi
    
    # Extract dependencies to system locations
    log_info "Installing pre-built dependencies to /usr/lib/pitrac..."
    mkdir -p /usr/lib/pitrac
    
    log_info "  Extracting OpenCV 4.11.0..."
    tar xzf "$ARTIFACT_DIR/opencv-4.11.0-arm64.tar.gz" -C /tmp/
    cp -r /tmp/opencv/lib/*.so* /usr/lib/pitrac/ 2>/dev/null || true
    rm -rf /tmp/opencv
    
    log_info "  Extracting ActiveMQ-CPP 3.9.5..."
    tar xzf "$ARTIFACT_DIR/activemq-cpp-3.9.5-arm64.tar.gz" -C /tmp/
    cp -r /tmp/activemq-cpp/lib/*.so* /usr/lib/pitrac/ 2>/dev/null || true
    # Also need headers for building
    mkdir -p /opt/activemq-cpp
    cp -r /tmp/activemq-cpp/* /opt/activemq-cpp/
    rm -rf /tmp/activemq-cpp
    
    log_info "  Extracting lgpio 0.2.2..."
    tar xzf "$ARTIFACT_DIR/lgpio-0.2.2-arm64.tar.gz" -C /tmp/
    cp -r /tmp/lgpio/lib/*.so* /usr/lib/pitrac/ 2>/dev/null || true
    rm -rf /tmp/lgpio
    
    log_info "  Extracting msgpack-cxx 6.1.1..."
    tar xzf "$ARTIFACT_DIR/msgpack-cxx-6.1.1-arm64.tar.gz" -C /tmp/
    if [[ -d /tmp/msgpack/lib ]]; then
        cp -r /tmp/msgpack/lib/*.so* /usr/lib/pitrac/ 2>/dev/null || true
    fi
    rm -rf /tmp/msgpack
    
    # Extract OpenCV headers for building
    log_info "  Setting up OpenCV headers..."
    tar xzf "$ARTIFACT_DIR/opencv-4.11.0-arm64.tar.gz" -C /tmp/
    mkdir -p /opt/opencv
    cp -r /tmp/opencv/* /opt/opencv/
    rm -rf /tmp/opencv
    
    # Update library cache
    ldconfig
    
    # Create pkg-config files for libraries that don't have them
    log_info "Creating pkg-config files..."
    mkdir -p /usr/lib/pkgconfig
    
    # Create lgpio.pc (the Pi repo package doesn't include one)
    cat > /usr/lib/pkgconfig/lgpio.pc << 'EOF'
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib/aarch64-linux-gnu
includedir=${prefix}/include

Name: lgpio
Description: GPIO library for Linux
Version: 0.2.2
Libs: -L${libdir} -llgpio
Cflags: -I${includedir}
EOF
    
    # Create msgpack-cxx.pc (header-only library)
    cat > /usr/lib/pkgconfig/msgpack-cxx.pc << 'EOF'
prefix=/usr
exec_prefix=${prefix}
includedir=${prefix}/include

Name: msgpack-cxx
Description: MessagePack implementation for C++
Version: 4.1.3
Cflags: -I${includedir}
EOF
    
    # Build PiTrac
    log_info "Building PiTrac..."
    cd "$REPO_ROOT/Software/LMSourceCode/ImageProcessing"
    
    # Apply Boost C++20 fix if needed
    if ! grep -q "#include <utility>" /usr/include/boost/asio/awaitable.hpp 2>/dev/null; then
        log_info "Applying Boost C++20 compatibility fix..."
        sed -i '/namespace boost {/i #include <utility>' /usr/include/boost/asio/awaitable.hpp
    fi
    
    # Set build environment
    export PKG_CONFIG_PATH="/opt/opencv/lib/pkgconfig:/opt/activemq-cpp/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"
    export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
    export CMAKE_PREFIX_PATH="/opt/opencv:/opt/activemq-cpp"
    export CPLUS_INCLUDE_PATH="/opt/opencv/include/opencv4:/opt/activemq-cpp/include/activemq-cpp-3.9.5"
    export PITRAC_ROOT="$REPO_ROOT/Software/LMSourceCode"
    export CXXFLAGS="-I/opt/opencv/include/opencv4"
    
    # Create dummy closed source file if needed
    mkdir -p ClosedSourceObjectFiles
    touch ClosedSourceObjectFiles/gs_e6_response.cpp.o
    
    # Clean previous build
    rm -rf build
    
    # Build with meson
    log_info "Configuring build with Meson..."
    meson setup build --buildtype=release -Denable_recompile_closed_source=false
    
    log_info "Building with Ninja..."
    ninja -C build pitrac_lm
    
    # Check if build succeeded
    if [[ ! -f "build/pitrac_lm" ]]; then
        log_error "Build failed - binary not found"
        exit 1
    fi
    
    # Install binary
    log_info "Installing PiTrac binary..."
    install -m 755 build/pitrac_lm /usr/lib/pitrac/pitrac_lm
    
    # Install CLI tool
    log_info "Installing CLI tool..."
    install -m 755 "$SCRIPT_DIR/templates/pitrac-cli.sh" /usr/bin/pitrac
    
    # Install camera tools
    log_info "Installing camera tools..."
    if [[ -d "$REPO_ROOT/Software/LMSourceCode/ImageProcessing/CameraTools" ]]; then
        mkdir -p /usr/lib/pitrac/ImageProcessing/CameraTools
        cp -r "$REPO_ROOT/Software/LMSourceCode/ImageProcessing/CameraTools"/* \
           /usr/lib/pitrac/ImageProcessing/CameraTools/
        find /usr/lib/pitrac/ImageProcessing/CameraTools -name "*.sh" -type f -exec chmod 755 {} \;
    fi
    
    # Install test images
    log_info "Installing test images..."
    mkdir -p /usr/share/pitrac/test-images
    local test_images_dir="$REPO_ROOT/Software/LMSourceCode/Images"
    if [[ -d "$test_images_dir" ]]; then
        if [[ -f "$test_images_dir/gs_log_img__log_ball_final_found_ball_img.png" ]]; then
            cp "$test_images_dir/gs_log_img__log_ball_final_found_ball_img.png" \
               /usr/share/pitrac/test-images/teed-ball.png
        fi
        if [[ -f "$test_images_dir/log_cam2_last_strobed_img.png" ]]; then
            cp "$test_images_dir/log_cam2_last_strobed_img.png" \
               /usr/share/pitrac/test-images/strobed.png
        fi
    fi
    
    # Install calibration tools
    log_info "Installing calibration tools..."
    mkdir -p /usr/share/pitrac/calibration
    local calib_dir="$REPO_ROOT/Software/CalibrateCameraDistortions"
    if [[ -d "$calib_dir" ]]; then
        cp "$calib_dir/CameraCalibration.py" /usr/share/pitrac/calibration/ 2>/dev/null || true
        cp "$calib_dir/checkerboard.png" /usr/share/pitrac/calibration/ 2>/dev/null || true
    fi
    
    # Create calibration wizard
    cat > /usr/lib/pitrac/calibration-wizard << 'EOF'
#!/bin/bash
if [[ -f /usr/share/pitrac/calibration/CameraCalibration.py ]]; then
    cd /usr/share/pitrac/calibration
    python3 CameraCalibration.py "$@"
else
    echo "Calibration tools not installed"
    exit 1
fi
EOF
    chmod 755 /usr/lib/pitrac/calibration-wizard
    
    # Install config templates (only if they don't exist)
    log_info "Installing configuration templates..."
    mkdir -p /etc/pitrac
    if [[ ! -f /etc/pitrac/pitrac.yaml ]]; then
        cp "$SCRIPT_DIR/templates/pitrac.yaml" /etc/pitrac/pitrac.yaml
    else
        log_info "  pitrac.yaml already exists, skipping"
    fi
    
    if [[ ! -f /etc/pitrac/golf_sim_config.json ]]; then
        cp "$SCRIPT_DIR/templates/golf_sim_config.json" /etc/pitrac/golf_sim_config.json
    else
        log_info "  golf_sim_config.json already exists, skipping"
    fi
    
    # Install systemd services (optional)
    log_info "Installing systemd services..."
    cp "$SCRIPT_DIR/templates/pitrac.service" /etc/systemd/system/pitrac.service
    cp "$SCRIPT_DIR/templates/tomee.service" /etc/systemd/system/tomee.service
    cp "$SCRIPT_DIR/templates/tomee-wrapper.sh" /usr/lib/pitrac/tomee-wrapper.sh
    chmod 755 /usr/lib/pitrac/tomee-wrapper.sh
    
    # Install TomEE if artifact exists
    if [[ -f "$ARTIFACT_DIR/tomee-10.1.0-plume-arm64.tar.gz" ]]; then
        log_info "Installing TomEE..."
        tar xzf "$ARTIFACT_DIR/tomee-10.1.0-plume-arm64.tar.gz" -C /opt/
    else
        log_warn "TomEE artifact not found, skipping"
    fi
    
    # Install webapp if exists
    if [[ -f "$ARTIFACT_DIR/golfsim-1.0.0-noarch.war" ]]; then
        log_info "Installing web application..."
        mkdir -p /usr/share/pitrac/webapp
        cp "$ARTIFACT_DIR/golfsim-1.0.0-noarch.war" /usr/share/pitrac/webapp/golfsim.war
    else
        log_warn "Web application not found, skipping"
    fi
    
    # Create default directories
    log_info "Creating default directories..."
    mkdir -p /var/lib/pitrac
    mkdir -p /usr/share/pitrac/{webapp,test-images,calibration}
    
    # Update systemd
    systemctl daemon-reload
    
    log_success "Development build complete!"
    echo ""
    echo "PiTrac has been installed to system locations:"
    echo "  Binary: /usr/lib/pitrac/pitrac_lm"
    echo "  CLI: /usr/bin/pitrac"
    echo "  Libraries: /usr/lib/pitrac/"
    echo "  Configs: /etc/pitrac/"
    echo ""
    echo "You can now run:"
    echo "  pitrac test quick   # Test image processing"
    echo "  pitrac run          # Start tracking (requires cameras)"
    echo "  pitrac help         # Show all commands"
    echo ""
    echo "To rebuild after code changes, run: sudo $0 dev"
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
        dev)
            build_dev
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

# Check Docker (not needed for dev mode)
if [[ "$ACTION" != "dev" ]]; then
    if ! command -v docker &>/dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
fi

# Ensure artifact directory exists
mkdir -p "$ARTIFACT_DIR"

# Run main
main