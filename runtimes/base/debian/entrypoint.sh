#!/bin/bash

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
cd "${HOME:-/home/container}" || exit 1

# If STARTUP variable is defined, parse and execute it; otherwise handle command arguments
if [ -n "${STARTUP}" ]; then
    # Convert "{{VARIABLE}}" syntax into standard shell "${VARIABLE}" format
    CMD_EXPANDED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

    # Display the command we're running in the output,
    # and then execute it with the env from the container itself.
    printf "\033[1m\033[33m%s@%s~ \033[0m%s\n" "${USER:-container}" "$(hostname)" "${CMD_EXPANDED}"
    eval "exec ${CMD_EXPANDED}"
elif [ $# -gt 0 ]; then
    exec "$@"
else
    exec /bin/bash
fi
