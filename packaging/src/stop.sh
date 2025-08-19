
force_stop="${args[--force]:-}"
timeout="${args[--timeout]:-5}"

if ! validate_positive_integer "$timeout"; then
  error "Invalid timeout: $timeout"
  exit 1
fi

if [[ "$force_stop" == "1" ]]; then
  info "Force stopping PiTrac..."
  force_stop_pitrac
else
  info "Stopping PiTrac gracefully (timeout: ${timeout}s)..."
  stop_pitrac_gracefully "$timeout"
fi