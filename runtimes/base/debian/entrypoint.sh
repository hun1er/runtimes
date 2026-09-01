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

# Execute optional pre-startup lifecycle hooks
HOOKS_DIR="${HOOKS_DIR:-$WORKDIR/.entrypoint.d}"
if [ -d "$HOOKS_DIR" ]; then
    for script in "$HOOKS_DIR"/*.sh; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            echo "[Runtime] Executing hook: $script"
            "$script"
        fi
    done
fi

# Synchronize files via rsync if RSYNC_SOURCE is configured
if [ -n "$RSYNC_SOURCE" ]; then
    echo "[Runtime] Starting rsync from source: $RSYNC_SOURCE"

    # Use custom RSYNC_ARGS if provided, otherwise fallback to sensible defaults
    if [ -n "$RSYNC_ARGS" ]; then
        # shellcheck disable=SC2206
        RSYNC_EXEC_ARGS=($RSYNC_ARGS)
    else
        RSYNC_EXEC_ARGS=("-av" "--no-owner" "--no-group" "--timeout=10")
    fi

    # Optional exclude file
    EXCLUDE_FILE="${RSYNC_EXCLUDE_FILE:-$WORKDIR/.rsync-exclude}"
    if [ -f "$EXCLUDE_FILE" ]; then
        RSYNC_EXEC_ARGS+=("--exclude-from=$EXCLUDE_FILE")
    fi

    # Optional extra arguments from user
    if [ -n "$RSYNC_EXTRA_ARGS" ]; then
        # shellcheck disable=SC2206
        RSYNC_EXEC_ARGS+=($RSYNC_EXTRA_ARGS)
    fi

    if rsync "${RSYNC_EXEC_ARGS[@]}" "$RSYNC_SOURCE" "$WORKDIR/"; then
        echo "[Runtime] Synchronization completed successfully."
    else
        echo "[Runtime:WARNING] Rsync failed, continuing with existing files..."
    fi
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
