#!/bin/sh
set -eu

# System update
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
