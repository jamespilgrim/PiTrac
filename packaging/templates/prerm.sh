#!/bin/bash
set -e

case "$1" in
    remove|upgrade|deconfigure)
        # Stop services
        systemctl stop pitrac 2>/dev/null || true
        systemctl stop tomee 2>/dev/null || true
        systemctl disable pitrac 2>/dev/null || true
        systemctl disable tomee 2>/dev/null || true
        ;;
    
    failed-upgrade)
        ;;
    
    *)
        echo "prerm called with unknown argument: $1" >&2
        exit 1
        ;;
esac

exit 0