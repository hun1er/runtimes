# Base image
FROM debian:stable-slim

# Build-time variables
ARG TZ="UTC" \
    USER="container" \
    DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV TZ="${TZ}" \
    USER="${USER}" \
    HOME="/home/${USER}" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    DEBUGINFOD_URLS="https://debuginfod.debian.net"

# Copy system configuration
COPY --chown=root:root --chmod=644 etc/ /etc/

# Copy entrypoint script
COPY --chown=root:root --chmod=755 entrypoint.sh /entrypoint.sh

# Container setup
RUN --mount=type=bind,from=scripts,target=/mnt/scripts \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eu; \
    \
    # Preserve APT package cache
    rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache; \
    \
    # Enable 32-bit architecture support
    dpkg --add-architecture i386; \
    \
    # System update
    sh /mnt/scripts/upgrade.sh; \
    \
    # Install packages
    apt-get install -y --no-install-recommends \
    binutils \
    elfutils \
    ca-certificates \
    curl \
    iproute2 \
    rsync \
    tar \
    tzdata; \
    \
    # Configure timezone
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime; \
    echo "${TZ}" > /etc/timezone; \
    \
    # Create user
    useradd -m -d "/home/${USER}" -s /bin/bash "${USER}"; \
    \
    # System cleanup
    sh /mnt/scripts/cleanup.sh

# Runtime user context
USER ${USER}
WORKDIR /home/${USER}

# Runtime entrypoint
CMD [ "/bin/bash", "/entrypoint.sh" ]
