#!/bin/bash
set -e

# Give everything time to initialize
sleep 1

# Default the TZ environment variable to UTC
TZ="${TZ:-UTC}"
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
INTERNAL_IP="${INTERNAL_IP:-127.0.0.1}"
export INTERNAL_IP

# Switch to the container's working directory
cd "${WORKDIR}" || exit 1

# Load optional runtime configuration file if present
CONFIG_FILE="${RUNTIME_CONFIG:-$WORKDIR/.runtime.conf}"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Launch target process
if [ "$#" -gt 0 ]; then
    exec "$@"
elif [ -n "${STARTUP}" ]; then
    # Convert "{{VARIABLE}}" syntax into standard shell "${VARIABLE}" format
    CMD_EXPANDED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

    # Display the command we're running in the output,
    # and then execute it with the env from the container itself.
    printf "\033[1m\033[33m%s@%s~ \033[0m%s\n" "${USER:-container}" "$(hostname)" "${CMD_EXPANDED}"
    eval "exec ${CMD_EXPANDED}"
else
    exec /bin/bash
fi
