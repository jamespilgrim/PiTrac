#!/bin/bash
# TomEE startup wrapper with Java auto-detection

# Auto-detect JAVA_HOME if not set
if [ -z "$JAVA_HOME" ]; then
    # Try common locations in order of preference
    if [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
    elif [ -d "/usr/lib/jvm/java-17-openjdk-arm64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-arm64"
    elif [ -d "/usr/lib/jvm/java-11-openjdk-arm64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64"
    elif [ -x "/usr/bin/java" ]; then
        # Fallback: detect from java binary
        export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
    fi
fi

# Verify JAVA_HOME is valid
if [ ! -d "$JAVA_HOME" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
    echo "ERROR: Cannot find valid Java installation" >&2
    echo "Tried JAVA_HOME=$JAVA_HOME" >&2
    exit 1
fi

echo "Using JAVA_HOME=$JAVA_HOME"

# Execute the requested command
case "$1" in
    start)
        exec /opt/tomee/bin/startup.sh
        ;;
    stop)
        exec /opt/tomee/bin/shutdown.sh
        ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac