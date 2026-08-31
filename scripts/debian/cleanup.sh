#!/bin/sh
set -eu

# System cleanup
apt-get autoremove -y --purge
rm -rf /tmp/* /var/tmp/*
