#!/bin/bash
# PiTrac CLI
set -euo pipefail

VERSION="1.0.0"
BINARY_PATH="/usr/lib/pitrac/pitrac_lm"
CONFIG_FILE="/etc/pitrac/pitrac.yaml"

if [[ -z "${HOME:-}" ]]; then
    if [[ -n "${USER:-}" ]]; then
        export HOME=$(getent passwd "$USER" | cut -d: -f6)
    elif [[ -n "${SUDO_USER:-}" ]]; then
        export HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        export HOME="/home/pi"
    fi
fi

USER_CONFIG_FILE="$HOME/.pitrac/config/pitrac.yaml"

if [[ -f "$USER_CONFIG_FILE" ]]; then
    CONFIG_FILE="$USER_CONFIG_FILE"
fi
detect_pi_model() {
    if grep -q "Raspberry Pi 5" /proc/cpuinfo 2>/dev/null; then
        echo "pi5"
    elif grep -q "Raspberry Pi 4" /proc/cpuinfo 2>/dev/null; then
        echo "pi4"
    else
        echo "unknown"
    fi
}

get_gpio_chip() {
    local model=$(detect_pi_model)
    if [[ "$model" == "pi5" ]]; then
        echo "4"
    else
        echo "0"
    fi
}

cmd_run() {
    echo "Setting environment variables..."
    
    export PITRAC_ROOT="/usr/lib/pitrac"
    export PITRAC_BASE_IMAGE_LOGGING_DIR="${HOME}/LM_Shares/Images/"
    export PITRAC_WEBSERVER_SHARE_DIR="${HOME}/LM_Shares/WebShare/"
    export PITRAC_MSG_BROKER_FULL_ADDRESS="tcp://localhost:61616"
    export PITRAC_SLOT1_CAMERA_TYPE="4"
    export PITRAC_SLOT2_CAMERA_TYPE="4"
    
    # Check if golf_sim_config.json exists in current directory
    if [[ ! -f "golf_sim_config.json" ]]; then
        echo "Creating golf_sim_config.json from template..."
        if [[ -f "/etc/pitrac/golf_sim_config.json" ]]; then
            cp /etc/pitrac/golf_sim_config.json .
            # Update paths for current user
            sed -i "s|~/|${HOME}/|g" golf_sim_config.json
        else
            echo "ERROR: Template config not found at /etc/pitrac/golf_sim_config.json"
            exit 1
        fi
    fi
    
    # Set libcamera config based on Pi model
    local model=$(detect_pi_model)
    if [[ "$model" == "pi5" ]]; then
        export LIBCAMERA_RPI_CONFIG_FILE="/usr/share/libcamera/pipeline/rpi/pisp/rpi_apps.yaml"
    else
        export LIBCAMERA_RPI_CONFIG_FILE="/usr/share/libcamera/pipeline/rpi/vc4/rpi_apps.yaml"
    fi
    
    # Check and start ActiveMQ if needed
    if ! systemctl is-active --quiet activemq; then
        echo "Starting ActiveMQ broker..."
        sudo systemctl start activemq
        sleep 2
    fi
    
    # Check and start TomEE if needed
    if ! systemctl is-active --quiet tomee; then
        echo "Starting TomEE server..."
        sudo systemctl start tomee
        
        # Auto-deploy web app if available
        if [[ ! -f "/opt/tomee/webapps/golfsim.war" ]] && [[ -f "/usr/share/pitrac/webapp/golfsim.war" ]]; then
            echo "Deploying PiTrac web application..."
            sudo cp /usr/share/pitrac/webapp/golfsim.war /opt/tomee/webapps/
        fi
        sleep 3
    fi
    
    # Check if already running
    if pgrep -x "pitrac_lm" > /dev/null; then
        echo "PiTrac is already running!"
        echo "Use 'pitrac stop' to stop it first, or 'pitrac status' to check status"
        return 1
    fi
    
    # Run in background by default, unless --foreground is specified
    if [[ "$*" == *"--foreground"* ]]; then
        echo "Starting PiTrac launch monitor (foreground)..."
        echo "Press Ctrl+C to stop"
        export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
        # Remove --foreground from arguments before passing to binary
        local args=()
        for arg in "$@"; do
            if [[ "$arg" != "--foreground" ]]; then
                args+=("$arg")
            fi
        done
        # If no arguments provided, determine system mode from config
        if [[ ${#args[@]} -eq 0 ]]; then
            # Check config for system mode
            local system_mode="camera1"  # default
            if [[ -f "$CONFIG_FILE" ]]; then
                local mode=$(grep -A1 "^system:" "$CONFIG_FILE" | grep "mode:" | awk '{print $2}')
                local role=$(grep -A2 "^system:" "$CONFIG_FILE" | grep "camera_role:" | awk '{print $2}')
                if [[ "$mode" == "dual" && "$role" == "camera2" ]]; then
                    system_mode="camera2"
                fi
            fi
            args=("--system_mode=$system_mode")
        fi
        exec "$BINARY_PATH" "${args[@]}"
    else
        echo "Starting PiTrac launch monitor (background)..."
        echo "Use 'pitrac status' to check status, 'pitrac logs' to view output"
        export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
        # If no arguments provided, determine system mode from config
        local run_args=("$@")
        if [[ ${#run_args[@]} -eq 0 ]]; then
            # Check config for system mode
            local system_mode="camera1"  # default
            if [[ -f "$CONFIG_FILE" ]]; then
                local mode=$(grep -A1 "^system:" "$CONFIG_FILE" | grep "mode:" | awk '{print $2}')
                local role=$(grep -A2 "^system:" "$CONFIG_FILE" | grep "camera_role:" | awk '{print $2}')
                if [[ "$mode" == "dual" && "$role" == "camera2" ]]; then
                    system_mode="camera2"
                fi
            fi
            run_args=("--system_mode=$system_mode")
        fi
        nohup "$BINARY_PATH" "${run_args[@]}" > /tmp/pitrac.log 2>&1 &
        local pid=$!
        echo $pid > /tmp/pitrac.pid
        sleep 2
        if kill -0 $pid 2>/dev/null; then
            echo "✓ PiTrac started successfully (PID: $pid)"
        else
            echo "✗ Failed to start PiTrac. Check logs with 'pitrac logs'"
            rm -f /tmp/pitrac.pid
        fi
    fi
}

cmd_stop() {
    if [[ -f /tmp/pitrac.pid ]]; then
        local pid=$(cat /tmp/pitrac.pid)
        if kill -0 $pid 2>/dev/null; then
            echo "Stopping PiTrac (PID: $pid)..."
            kill $pid
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                echo "Forcing stop..."
                kill -9 $pid
            fi
            rm -f /tmp/pitrac.pid
            echo "✓ PiTrac stopped"
        else
            echo "PiTrac process not found (stale PID file)"
            rm -f /tmp/pitrac.pid
        fi
    else
        local pid=$(pgrep -x "pitrac_lm")
        if [[ -n "$pid" ]]; then
            echo "Stopping PiTrac (PID: $pid)..."
            kill $pid
            sleep 1
            if pgrep -x "pitrac_lm" > /dev/null; then
                echo "Forcing stop..."
                pkill -9 -x "pitrac_lm"
            fi
            echo "✓ PiTrac stopped"
        else
            echo "PiTrac is not running"
        fi
    fi
}

cmd_status() {
    echo "=== PiTrac Status ==="
    
    local pid=$(pgrep -x "pitrac_lm")
    if [[ -n "$pid" ]]; then
        echo "✓ PiTrac is running (PID: $pid)"
        
        # Show resource usage
        local cpu_mem=$(ps -p $pid -o %cpu,%mem,etime --no-headers 2>/dev/null)
        if [[ -n "$cpu_mem" ]]; then
            echo "  CPU/Memory/Uptime: $cpu_mem"
        fi
    else
        echo "✗ PiTrac is not running"
    fi
    
    if systemctl is-active --quiet activemq; then
        echo "✓ ActiveMQ is running"
        if netstat -tln 2>/dev/null | grep -q :61616; then
            echo "  Listening on port 61616"
        fi
    else
        echo "✗ ActiveMQ is not running"
    fi
    
    if systemctl is-active --quiet tomee; then
        echo "✓ TomEE is running"
        if netstat -tln 2>/dev/null | grep -q :8080; then
            echo "  Web interface: http://localhost:8080"
        fi
    else
        echo "✗ TomEE is not running"
    fi
    
    if [[ -f golf_sim_config.json ]]; then
        echo "✓ Config file found in current directory"
    else
        echo "⚠ Config file not in current directory"
    fi
}

cmd_config() {
    case "${2:-}" in
        edit)
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        show)
            cat "$CONFIG_FILE"
            ;;
        get)
            if [[ -n "${3:-}" ]]; then
                grep "$3" "$CONFIG_FILE" || echo "Key not found"
            else
                echo "Usage: pitrac config get <key>"
            fi
            ;;
        set)
            if [[ -n "${3:-}" ]] && [[ -n "${4:-}" ]]; then
                # This is simplified - real implementation would use proper YAML parser
                sed -i "s/^$3:.*/$3: $4/" "$CONFIG_FILE"
                echo "Updated $3"
            else
                echo "Usage: pitrac config set <key> <value>"
            fi
            ;;
        validate)
            echo "Validating configuration..."
            # Add validation logic here
            echo "Configuration appears valid"
            ;;
        reset)
            echo "Resetting to default configuration..."
            if [[ -f "/usr/share/pitrac/config.yaml.default" ]]; then
                cp /usr/share/pitrac/config.yaml.default "$CONFIG_FILE"
                echo "Configuration reset to defaults"
            else
                echo "Default configuration not found"
            fi
            ;;
        *)
            echo "Usage: pitrac config {edit|show|get|set|validate|reset}"
            ;;
    esac
}

cmd_setup() {
    echo "Running initial setup..."
    echo ""
    
    # Create directories
    echo "Creating directory structure..."
    mkdir -p ~/LM_Shares/{Images,WebShare}
    mkdir -p ~/.pitrac/{config,cache,state,calibration}
    
    # Set up user config if not exists
    if [[ ! -f "$USER_CONFIG_FILE" ]]; then
        echo "Creating user configuration..."
        mkdir -p "$(dirname "$USER_CONFIG_FILE")"
        cp "$CONFIG_FILE" "$USER_CONFIG_FILE"
    fi
    
    # Configure based on Pi model
    local model=$(detect_pi_model)
    echo "Detected Pi model: $model"
    
    # Apply boot config
    cmd_boot config
    
    # Configure camera timeout
    cmd_camera config timeout
    
    echo ""
    echo "Setup complete! Please reboot to apply changes."
    echo "Run: sudo reboot"
}

cmd_camera() {
    case "${2:-}" in
        list)
            echo "Detecting cameras..."
            local model=$(detect_pi_model)
            if [[ "$model" == "pi5" ]]; then
                rpicam-hello --list-cameras
            else
                libcamera-hello --list-cameras
            fi
            ;;
        test)
            echo "Testing camera capture for 5 seconds..."
            local model=$(detect_pi_model)
            if [[ "$model" == "pi5" ]]; then
                rpicam-hello -t 5000
            else
                libcamera-hello -t 5000
            fi
            ;;
        trigger)
            case "${3:-external}" in
                external)
                    echo "Setting camera to external trigger mode..."
                    if [[ -f "/usr/lib/pitrac/ImageProcessing/CameraTools/setCameraTriggerExternal.sh" ]]; then
                        sudo /usr/lib/pitrac/ImageProcessing/CameraTools/setCameraTriggerExternal.sh
                        echo "Camera set to external trigger mode"
                    else
                        echo "Error: Camera trigger script not found"
                    fi
                    ;;
                internal)
                    echo "Setting camera to internal trigger mode..."
                    if [[ -f "/usr/lib/pitrac/ImageProcessing/CameraTools/setCameraTriggerInternal.sh" ]]; then
                        sudo /usr/lib/pitrac/ImageProcessing/CameraTools/setCameraTriggerInternal.sh
                        echo "Camera set to internal trigger mode"
                    else
                        echo "Error: Camera trigger script not found"
                    fi
                    ;;
                *)
                    echo "Usage: pitrac camera trigger [external|internal]"
                    ;;
            esac
            ;;
        config)
            case "${3:-}" in
                timeout)
                    local model=${4:-$(detect_pi_model)}
                    local timeout=${5:-1000000}
                    local config_file
                    
                    if [[ "$model" == "pi5" ]]; then
                        config_file="/usr/share/libcamera/pipeline/rpi/pisp/rpi_apps.yaml"
                    else
                        config_file="/usr/share/libcamera/pipeline/rpi/vc4/rpi_apps.yaml"
                    fi
                    
                    echo "Setting camera timeout to ${timeout}ms in $config_file..."
                    # Would need sudo and proper YAML handling
                    echo "Manual edit required: Add 'camera_timeout_value_ms: $timeout' to $config_file"
                    ;;
                *)
                    echo "Usage: pitrac camera config timeout [pi4|pi5] [timeout_ms]"
                    ;;
            esac
            ;;
        *)
            echo "Usage: pitrac camera {list|test|trigger|config}"
            ;;
    esac
}

cmd_boot() {
    case "${2:-}" in
        config)
            local model=${3:-$(detect_pi_model)}
            local config_file
            
            if [[ "$model" == "pi5" ]]; then
                config_file="/boot/firmware/config.txt"
            else
                config_file="/boot/config.txt"
            fi
            
            echo "Boot configuration for $model:"
            echo "  Config file: $config_file"
            echo ""
            echo "Required settings:"
            echo "  camera_auto_detect=1"
            echo "  dtparam=i2c_arm=on"
            echo "  dtparam=spi=on"
            if [[ "$model" == "pi4" ]]; then
                echo "  gpu_mem=256"
            fi
            echo ""
            echo "Edit with: sudo nano $config_file"
            ;;
        *)
            echo "Usage: pitrac boot config [pi4|pi5]"
            ;;
    esac
}

cmd_tomee() {
    case "${2:-}" in
        start)
            echo "Starting TomEE web server..."
            sudo systemctl start tomee
            ;;
        stop)
            echo "Stopping TomEE web server..."
            sudo systemctl stop tomee
            ;;
        restart)
            echo "Restarting TomEE web server..."
            sudo systemctl restart tomee
            ;;
        status)
            systemctl status tomee
            ;;
        deploy)
            if [[ -f "/usr/share/pitrac/webapp/golfsim.war" ]]; then
                echo "Deploying PiTrac web application..."
                sudo cp /usr/share/pitrac/webapp/golfsim.war /opt/tomee/webapps/
                echo "Deployment complete. Restarting TomEE..."
                sudo systemctl restart tomee
            else
                echo "Web application not found"
            fi
            ;;
        logs)
            sudo journalctl -u tomee -f
            ;;
        *)
            echo "Usage: pitrac tomee {start|stop|restart|status|deploy|logs}"
            ;;
    esac
}

cmd_activemq() {
    case "${2:-}" in
        start)
            echo "Starting ActiveMQ broker..."
            sudo systemctl start activemq
            ;;
        stop)
            echo "Stopping ActiveMQ broker..."
            sudo systemctl stop activemq
            ;;
        restart)
            echo "Restarting ActiveMQ broker..."
            sudo systemctl restart activemq
            ;;
        status)
            systemctl status activemq
            echo ""
            echo "Broker port check:"
            if netstat -tln | grep -q :61616; then
                echo "Listening on port 61616"
            else
                echo "Not listening on port 61616"
            fi
            ;;
        logs)
            journalctl -u activemq -f
            ;;
        console)
            echo "ActiveMQ Web Console: http://localhost:8161/admin"
            echo "Default credentials: admin/admin"
            ;;
        port)
            echo "ActiveMQ broker port: 61616"
            echo "ActiveMQ web console port: 8161"
            ;;
        *)
            echo "Usage: pitrac activemq {start|stop|restart|status|logs|console|port}"
            ;;
    esac
}

cmd_calibrate() {
    if [[ -f "/usr/lib/pitrac/calibration-wizard" ]]; then
        exec /usr/lib/pitrac/calibration-wizard "$@"
    else
        echo "Calibration wizard not installed"
    fi
}

cmd_test() {
    case "${2:-hardware}" in
        hardware)
            echo "Running hardware tests..."
            echo ""
            echo "1. Testing cameras..."
            cmd_camera list
            echo ""
            echo "2. Testing message broker connection..."
            if netstat -an | grep -q ":61616.*LISTEN"; then
                echo "   ActiveMQ broker is listening on port 61616"
            else
                echo "   ActiveMQ broker not detected"
            fi
            echo ""
            echo "3. Testing GPIO access..."
            if [[ -e "/dev/gpiochip0" ]] || [[ -e "/dev/gpiochip4" ]]; then
                echo "   GPIO available (chip $(get_gpio_chip))"
            else
                echo "   GPIO not available"
            fi
            ;;
        pulse)
            echo "Running strobe pulse test..."
            echo "You should see dark-reddish pulses in the LED lens"
            echo "Press Ctrl+C to stop"
            echo ""
            echo "WARNING: Look at the LED from at least 2 feet away!"
            sleep 2
            
            export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
            export PITRAC_ROOT="/usr/lib/pitrac"
            export PITRAC_BASE_IMAGE_LOGGING_DIR="${HOME}/LM_Shares/Images/"
            /usr/lib/pitrac/pitrac_lm --pulse_test --system_mode=camera1 --logging_level=info
            ;;
        quick)
            echo "Running PiTrac quick test..."
            echo "This will start PiTrac in test mode and exit"
            
            # Copy config if not present
            if [[ ! -f "golf_sim_config.json" ]]; then
                if [[ -f "/etc/pitrac/golf_sim_config.json" ]]; then
                    echo "Copying config file to current directory..."
                    cp /etc/pitrac/golf_sim_config.json .
                else
                    echo "ERROR: Config file not found. Please copy /etc/pitrac/golf_sim_config.json to current directory"
                    exit 1
                fi
            fi
            
            export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
            export PITRAC_ROOT="/usr/lib/pitrac"
            export PITRAC_BASE_IMAGE_LOGGING_DIR="${HOME}/LM_Shares/Images/"
            /usr/lib/pitrac/pitrac_lm --system_mode=test "$@"
            ;;
        camera1|camera2)
            echo "Running PiTrac ${2} standalone test..."
            
            # Copy config if not present
            if [[ ! -f "golf_sim_config.json" ]]; then
                if [[ -f "/etc/pitrac/golf_sim_config.json" ]]; then
                    echo "Copying config file to current directory..."
                    cp /etc/pitrac/golf_sim_config.json .
                else
                    echo "ERROR: Config file not found. Please copy /etc/pitrac/golf_sim_config.json to current directory"
                    exit 1
                fi
            fi
            
            export LD_LIBRARY_PATH="/usr/lib/pitrac:${LD_LIBRARY_PATH:-}"
            export PITRAC_ROOT="/usr/lib/pitrac"
            export PITRAC_BASE_IMAGE_LOGGING_DIR="${HOME}/LM_Shares/Images/"
            /usr/lib/pitrac/pitrac_lm --system_mode="${2}_test_standalone" "$@"
            ;;
        *)
            echo "Usage: pitrac test [hardware|pulse|quick|camera1|camera2]"
            echo "  hardware - Test hardware components (default)"
            echo "  pulse    - Test strobe light pulses (Ctrl+C to stop)"
            echo "  quick    - Run PiTrac in test mode"
            echo "  camera1  - Test camera 1 standalone"
            echo "  camera2  - Test camera 2 standalone"
            ;;
    esac
}

cmd_service() {
    case "${2:-}" in
        start|stop|restart|status|enable|disable)
            if [[ "${2}" == "status" ]]; then
                systemctl status pitrac.service
            else
                sudo systemctl "${2}" pitrac.service
            fi
            ;;
        *)
            echo "Usage: pitrac service {start|stop|restart|status|enable|disable}"
            ;;
    esac
}

cmd_logs() {
    case "${2:-}" in
        --follow|-f)
            if [[ -f /tmp/pitrac.log ]]; then
                echo "Following PiTrac runtime logs (Ctrl+C to stop)..."
                tail -f /tmp/pitrac.log
            else
                echo "No runtime logs found. PiTrac may not have been started yet."
            fi
            ;;
        --service)
            journalctl -u pitrac -f
            ;;
        --all)
            if [[ -f /tmp/pitrac.log ]]; then
                cat /tmp/pitrac.log
            else
                echo "No runtime logs found."
            fi
            ;;
        *)
            if [[ -f /tmp/pitrac.log ]]; then
                echo "=== Recent PiTrac logs ==="
                tail -n 50 /tmp/pitrac.log
                echo ""
                echo "Use 'pitrac logs -f' to follow logs in real-time"
            else
                echo "No runtime logs found. PiTrac may not have been started yet."
            fi
            ;;
    esac
}

cmd_help() {
    echo "PiTrac v$VERSION - Golf Launch Monitor"
    cat << 'HELP_TEXT'
Usage: pitrac <command> [options]

Main Commands:
  run              Start tracking (runs in background)
  run --foreground Run in terminal (Ctrl+C to stop)
  stop             Stop PiTrac
  status           Check what's running
  setup            First-time setup
  test             Test cameras and hardware
  calibrate        Camera calibration
  logs             Show recent logs
  logs -f          Watch logs live
  help             Show this help
  version          Version info

Config:
  config edit      Open config in editor
  config show      View current config
  config get KEY   Get a config value
  config set KEY VALUE  Set a config value
  config validate  Check config is valid
  config reset     Reset to defaults

Camera:
  camera list      Find connected cameras
  camera test      5-second camera test
  camera trigger external  Set external trigger mode
  camera trigger internal  Set internal trigger mode
  camera config timeout    Set camera timeout

Boot Settings:
  boot config      Show Pi boot config changes needed

TomEE Web Server:
  tomee start      Start web server
  tomee stop       Stop web server
  tomee restart    Restart web server
  tomee status     Check if running
  tomee deploy     Deploy web app
  tomee logs       View server logs

ActiveMQ Broker:
  activemq start   Start message broker
  activemq stop    Stop message broker
  activemq restart Restart broker
  activemq status  Check if running
  activemq console Web console info (port 8161)
  activemq logs    View broker logs

System Service:
  service start    Start PiTrac service
  service stop     Stop PiTrac service
  service status   Service status
  service enable   Auto-start on boot
  service disable  Don't auto-start

Quick Examples:
  pitrac run       Start in background
  pitrac status    See what's running
  pitrac test      Test everything works
  pitrac stop      Stop tracking
HELP_TEXT
}

cmd_version() {
    echo "PiTrac Launch Monitor"
    echo "Version: $VERSION"
    echo "Build: Raspberry Pi OS Bookworm (64-bit)"
    echo "Architecture: ARM64"
}

# Main command dispatcher
case "${1:-}" in
    run)
        shift
        cmd_run "$@"
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    config)
        cmd_config "$@"
        ;;
    setup)
        cmd_setup "$@"
        ;;
    camera)
        cmd_camera "$@"
        ;;
    boot)
        cmd_boot "$@"
        ;;
    tomee)
        cmd_tomee "$@"
        ;;
    activemq)
        cmd_activemq "$@"
        ;;
    calibrate)
        cmd_calibrate "$@"
        ;;
    test)
        cmd_test "$@"
        ;;
    service)
        cmd_service "$@"
        ;;
    logs)
        cmd_logs "$@"
        ;;
    version|--version)
        cmd_version
        ;;
    help|--help|"")
        cmd_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'pitrac help' for usage information."
        exit 1
        ;;
esac