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

# Enable extended pattern matching for subshell-free string trimming
shopt -s extglob

# Strip leading/trailing whitespace and write result directly into target variable ($2)
trim() {
    local __trim_val="$1"
    __trim_val="${__trim_val##+([[:space:]])}"
    __trim_val="${__trim_val%%+([[:space:]])}"
    printf -v "$2" '%s' "$__trim_val"
}

# Prevent resolving relative destination paths against root filesystem
: "${WORKDIR:=.}"

# Switch to the container's working directory
cd "${WORKDIR}" || exit 1

# Load optional runtime configuration file if present
CONFIG_FILE="${RUNTIME_CONFIG:-$WORKDIR/.runtime.conf}"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Execute optional pre-startup lifecycle hooks
HOOKS_DIR="${HOOKS_DIR:-$WORKDIR/.entrypoint.d}"
if [[ -d "$HOOKS_DIR" ]]; then
    for script in "$HOOKS_DIR"/*.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            echo "[Runtime] Executing hook: $script"
            "$script"
        fi
    done
fi

# Synchronize files via rsync if RSYNC_MAP is configured
# Format: "SOURCE | DESTINATION | OPTIONAL_FLAGS" (newline or semicolon separated)
if [[ -n "$RSYNC_MAP" ]]; then
    echo "[Runtime] Initializing rsync synchronization..."

    # Parse arguments safely preserving quoted values with whitespace
    if [[ -n "$RSYNC_ARGS" ]]; then
        readarray -t RSYNC_BASE_ARGS < <(xargs -r printf "%s\n" <<< "$RSYNC_ARGS")
    else
        RSYNC_BASE_ARGS=("-av" "--no-owner" "--no-group" "--timeout=10")
    fi

    # Optional exclude file
    EXCLUDE_FILE="${RSYNC_EXCLUDE_FILE:-$WORKDIR/.rsync-exclude}"
    if [[ -f "$EXCLUDE_FILE" ]]; then
        RSYNC_BASE_ARGS+=("--exclude-from=$EXCLUDE_FILE")
    fi

    # Optional extra arguments from user
    if [[ -n "$RSYNC_EXTRA_ARGS" ]]; then
        readarray -t extra_args < <(xargs -r printf "%s\n" <<< "$RSYNC_EXTRA_ARGS")
        if [[ ${#extra_args[@]} -gt 0 ]]; then
            RSYNC_BASE_ARGS+=("${extra_args[@]}")
        fi
    fi

    RSYNC_FAIL_COUNT=0

    # Process individual mapping entries
    while IFS= read -r line || [[ -n "$line" ]]; do
        trim "$line" line
        [[ -z "$line" || "$line" == \#* ]] && continue

        IFS='|' read -r src dest flags <<< "$line"
        trim "$src" src
        trim "$dest" dest
        trim "$flags" flags

        [[ -z "$src" ]] && continue

        # Resolve relative destinations against WORKDIR
        if [[ -z "$dest" || "$dest" == "." ]]; then
            dest="$WORKDIR/"
        elif [[ "$dest" != /* ]]; then
            dest="$WORKDIR/$dest"
        fi

        # Create destination path if missing
        if [[ "$dest" == */ ]]; then
            mkdir -p "$dest"
        else
            mkdir -p "$(dirname "$dest")"
        fi

        echo "[Runtime] Syncing: $src -> $dest ${flags:+($flags)}"

        # Append per-entry custom flags to base options
        current_args=("${RSYNC_BASE_ARGS[@]}")
        if [[ -n "$flags" ]]; then
            readarray -t entry_flags < <(xargs -r printf "%s\n" <<< "$flags")
            if [[ ${#entry_flags[@]} -gt 0 ]]; then
                current_args+=("${entry_flags[@]}")
            fi
        fi

        if rsync "${current_args[@]}" "$src" "$dest"; then
            echo "[Runtime] Successfully synced: $src"
        else
            echo "[Runtime:WARNING] Rsync failed for: $src"
            RSYNC_FAIL_COUNT=$((RSYNC_FAIL_COUNT + 1))

            # Immediately abort execution on first error if configured
            if [[ "${RSYNC_FAIL_FAST,,}" =~ ^(true|1|yes)$ ]]; then
                echo "[Runtime:ERROR] Rsync failed for $src and RSYNC_FAIL_FAST is enabled. Aborting."
                exit 1
            fi
        fi
    done < <(tr ';' '\n' <<< "$RSYNC_MAP")

    if [[ "$RSYNC_FAIL_COUNT" -gt 0 ]]; then
        echo "[Runtime:WARNING] Total failed rsync tasks: $RSYNC_FAIL_COUNT"
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
