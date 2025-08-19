
system_mode="${args[mode]:-camera1}"
foreground="${args[--foreground]:-}"
verbose="${args[--verbose]:-}"
config_file="${args[--config]:-}"

if ! validate_system_mode "$system_mode"; then
  error "Invalid system mode: $system_mode"
  exit 1
fi

if is_pitrac_running; then
  error "PiTrac is already running (PID: $(cat "$PITRAC_PID_FILE"))"
  exit 1
fi

ensure_configuration
ensure_golf_config

load_configuration

setup_pitrac_environment

mapped_mode=$(map_system_mode "$system_mode")

cmd_args=("--system_mode=$mapped_mode")

if [[ "$verbose" == "1" ]]; then
  cmd_args+=("--logging_level=debug")
else
  cmd_args+=("--logging_level=info")
fi

if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
  cmd_args+=("--config=$config_file")
fi

if [[ "$foreground" == "1" ]]; then
  info "Starting PiTrac in foreground mode ($mapped_mode)..."
  exec "$PITRAC_BINARY" "${cmd_args[@]}"
else
  info "Starting PiTrac in background mode ($mapped_mode)..."
  start_pitrac_background "${cmd_args[@]}"
  
  # Wait a moment and check if it started
  sleep 2
  if is_pitrac_running; then
    success "PiTrac started successfully (PID: $(cat "$PITRAC_PID_FILE"))"
  else
    error "Failed to start PiTrac. Check logs for details."
    exit 1
  fi
fi