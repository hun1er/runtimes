# Base image name
ARG BASE_IMAGE=runtime:base-debian

# Base image
FROM ${BASE_IMAGE}

# Build-time variables
ARG DEBIAN_FRONTEND=noninteractive

# Container setup
RUN --mount=type=bind,from=scripts,target=/mnt/scripts \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eu; \
    \
    # System update
    sh /mnt/scripts/upgrade.sh; \
    \
    # Install packages
    apt-get install -y --no-install-recommends \
    libc6:i386 \
    libstdc++6:i386 \
    libgcc-s1:i386 \
    zlib1g:i386 \
    libcurl4:i386 \
    libssl3:i386 \
    libtinfo6:i386 \
    libc6-dbg:i386 \
    gdb \
    gdbserver \
    iproute2; \
    \
    # System cleanup
    sh /mnt/scripts/cleanup.sh
