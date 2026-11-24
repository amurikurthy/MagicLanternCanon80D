#!/usr/bin/env bash
# Host dependencies for building Magic Lantern (80D) + qemu-eos, and for the
# container-friendly SD-image build. Debian/Ubuntu. Run as root (or via sudo).
set -euo pipefail

apt-get update

# ARM cross toolchain for building ML, gdb for the emulation patch boot
apt-get install -y \
    gcc-arm-none-eabi binutils-arm-none-eabi gdb-multiarch \
    zip unzip xz-utils

# Module docs step in the ML build needs rst2html (docutils)
apt-get install -y python3-docutils || pip install docutils

# qemu-eos build deps
apt-get install -y \
    build-essential ninja-build pkg-config \
    libglib2.0-dev libpixman-1-dev zlib1g-dev flex bison python3-venv

# SD-image build without libguestfs (which can't run in a container):
# mtools writes into the FAT image directly; qemu-img converts qcow2<->raw.
apt-get install -y mtools qemu-utils

# For screenshots / image inspection in the boot driver
pip install pillow gdown || true

echo "Deps installed. arm-none-eabi-gcc: $(arm-none-eabi-gcc --version | head -1)"
