
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

ensure_golf_config

load_configuration

setup_pitrac_environment

cmd_args=("--system_mode=$system_mode")

if [[ "$verbose" == "1" ]]; then
  cmd_args+=("--logging_level=debug")
else
  cmd_args+=("--logging_level=info")
fi

if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
  cmd_args+=("--config=$config_file")
fi

if [[ "$foreground" == "1" ]]; then
  info "Starting PiTrac launch monitor (foreground)..."
  info "Press Ctrl+C to stop"
  exec "$PITRAC_BINARY" "${cmd_args[@]}"
else
  info "Starting PiTrac launch monitor (background)..."
  info "Use 'pitrac status' to check status, 'pitrac logs' to view output"
  
  ensure_pid_directory
  ensure_log_directory
  
  nohup "$PITRAC_BINARY" "${cmd_args[@]}" > "$PITRAC_LOG_FILE" 2>&1 &
  local pid=$!
  echo $pid > "$PITRAC_PID_FILE"
  
  sleep 2
  if kill -0 $pid 2>/dev/null; then
    success "PiTrac started successfully (PID: $pid)"
  else
    error "Failed to start PiTrac. Check logs with 'pitrac logs'"
    rm -f "$PITRAC_PID_FILE"
    exit 1
  fi
fi