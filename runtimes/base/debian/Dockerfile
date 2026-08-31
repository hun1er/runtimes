# Base image
FROM debian:stable-slim

# Build-time variables
ARG TZ="UTC" \
    DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV TZ="${TZ}" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    DEBUGINFOD_URLS="https://debuginfod.debian.net"

# Copy system configuration
COPY --chown=root:root --chmod=644 etc/ /etc/

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
    /mnt/scripts/upgrade.sh; \
    \
    # Install packages
    apt-get install -y --no-install-recommends \
    binutils \
    elfutils \
    ca-certificates \
    curl \
    tar \
    tzdata; \
    \
    # Configure timezone
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime; \
    echo "${TZ}" > /etc/timezone; \
    \
    # System cleanup
    /mnt/scripts/cleanup.sh
