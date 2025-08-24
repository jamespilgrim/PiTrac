#!/usr/bin/env bash
# lib/logging.sh - Logging functions

readonly LOG_LEVEL_TRACE=0
readonly LOG_LEVEL_DEBUG=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_WARN=3
readonly LOG_LEVEL_ERROR=4
readonly LOG_LEVEL_NONE=5

LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_GRAY='\033[0;90m'

supports_color() {
  if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM}" != "dumb" ]]; then
    return 0
  else
    return 1
  fi
}

format_log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "[$timestamp] [$level] $message"
}

log_trace() {
  if [[ $LOG_LEVEL -le $LOG_LEVEL_TRACE ]]; then
    local message=$(format_log_message "TRACE" "$*")
    if supports_color; then
      echo -e "${COLOR_GRAY}${message}${COLOR_RESET}" >&2
    else
      echo "$message" >&2
    fi
  fi
}

log_debug() {
  if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
    local message=$(format_log_message "DEBUG" "$*")
    if supports_color; then
      echo -e "${COLOR_CYAN}${message}${COLOR_RESET}" >&2
    else
      echo "$message" >&2
    fi
  fi
}

log_info() {
  if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
    local message=$(format_log_message "INFO" "$*")
    if supports_color; then
      echo -e "${COLOR_BLUE}${message}${COLOR_RESET}" >&2
    else
      echo "$message" >&2
    fi
  fi
}

log_warn() {
  if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
    local message=$(format_log_message "WARN" "$*")
    if supports_color; then
      echo -e "${COLOR_YELLOW}${message}${COLOR_RESET}" >&2
    else
      echo "$message" >&2
    fi
  fi
}

log_error() {
  if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
    local message=$(format_log_message "ERROR" "$*")
    if supports_color; then
      echo -e "${COLOR_RED}${message}${COLOR_RESET}" >&2
    else
      echo "$message" >&2
    fi
  fi
}

success() {
  local message="$*"
  if supports_color; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${message}"
  else
    echo "✓ $message"
  fi
}

die() {
  log_error "$*"
  exit 1
}

error() {
  if supports_color; then
    echo -e "${COLOR_RED}Error:${COLOR_RESET} $*" >&2
  else
    echo "Error: $*" >&2
  fi
}

warn() {
  if supports_color; then
    echo -e "${COLOR_YELLOW}Warning:${COLOR_RESET} $*" >&2
  else
    echo "Warning: $*" >&2
  fi
}

info() {
  echo "$*"
}

set_log_level() {
  local level="${1,,}"
  
  case "$level" in
    trace)
      LOG_LEVEL=$LOG_LEVEL_TRACE
      ;;
    debug)
      LOG_LEVEL=$LOG_LEVEL_DEBUG
      ;;
    info)
      LOG_LEVEL=$LOG_LEVEL_INFO
      ;;
    warn|warning)
      LOG_LEVEL=$LOG_LEVEL_WARN
      ;;
    error)
      LOG_LEVEL=$LOG_LEVEL_ERROR
      ;;
    none|off)
      LOG_LEVEL=$LOG_LEVEL_NONE
      ;;
    *)
      log_warn "Unknown log level: $level"
      ;;
  esac
}

get_log_level() {
  case "$LOG_LEVEL" in
    $LOG_LEVEL_TRACE)
      echo "trace"
      ;;
    $LOG_LEVEL_DEBUG)
      echo "debug"
      ;;
    $LOG_LEVEL_INFO)
      echo "info"
      ;;
    $LOG_LEVEL_WARN)
      echo "warn"
      ;;
    $LOG_LEVEL_ERROR)
      echo "error"
      ;;
    $LOG_LEVEL_NONE)
      echo "none"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

show_progress() {
  local message="$1"
  if supports_color; then
    echo -ne "${COLOR_BLUE}⟳${COLOR_RESET} ${message}...\r"
  else
    echo -n "$message..."
  fi
}

clear_progress() {
  echo -ne "\033[2K\r"
}

show_spinner() {
  local pid=$1
  local message="${2:-Working}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local temp
  
  if ! supports_color; then
    echo -n "$message..."
    wait $pid
    echo " done"
    return
  fi
  
  while kill -0 $pid 2>/dev/null; do
    temp=${spinstr#?}
    printf "${COLOR_BLUE}%c${COLOR_RESET} %s...\r" "$spinstr" "$message"
    spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  
  clear_progress
  if wait $pid; then
    success "$message"
  else
    error "$message failed"
  fi
}
