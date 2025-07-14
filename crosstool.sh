#!/bin/bash
#
# crosstool.sh
# Toolchain generation script
# This script automates the setup of a cross-compilation toolchain using crosstool-ng.
# Based on instructions from https://code.visualstudio.com/docs/remote/faq

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Configuration ---
CT_NG_VERSION="1.26.0"
CT_NG_INSTALL_DIR="$HOME/crosstool-ng"
CT_NG_BUILD_DIR="$HOME/crosstool-build"
CT_NG_BIN_DIR="$CT_NG_INSTALL_DIR/bin"
CT_NG_URL="http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-${CT_NG_VERSION}.tar.bz2"

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script Logic ---

log_info "Starting Crosstool-NG toolchain generation script."

# 1. Install dependencies
log_info "Updating package lists and installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq gcc g++ gperf bison flex texinfo help2man make libncurses5-dev \
    python3-dev autoconf automake libtool libtool-bin gawk wget bzip2 xz-utils unzip \
    patch rsync meson ninja-build

# 2. Check if crosstool-ng is installed, if not, install it
if ! [ -x "$CT_NG_BIN_DIR/ct-ng" ]; then
    log_info "crosstool-ng not found. Installing to $CT_NG_INSTALL_DIR..."

    # Create a temporary directory for the build
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    log_info "Downloading crosstool-ng v${CT_NG_VERSION}..."
    wget -q --show-progress -O "crosstool-ng-${CT_NG_VERSION}.tar.bz2" "$CT_NG_URL"

    log_info "Extracting..."
    tar -xjf "crosstool-ng-${CT_NG_VERSION}.tar.bz2"
    cd "crosstool-ng-${CT_NG_VERSION}"

    log_info "Configuring crosstool-ng to install to $CT_NG_INSTALL_DIR..."
    ./configure --prefix="$CT_NG_INSTALL_DIR"

    log_info "Building and installing crosstool-ng..."
    make
    make install

    # Go back to original directory and clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"

    log_info "crosstool-ng installed successfully."
else
    log_info "crosstool-ng is already installed in $CT_NG_INSTALL_DIR."
fi

# 3. Set environment variables for this script's session
export PATH="$CT_NG_BIN_DIR:$PATH"
log_info "Temporarily added $CT_NG_BIN_DIR to PATH for this session."

# 4. Check architecture and select appropriate config
ARCH=$(uname -m)
log_info "Detected architecture: $ARCH"

CONFIG_NAME=""
case "$ARCH" in
    "x86_64")
        CONFIG_NAME="x86_64-gcc-8.5.0-glibc-2.28"
        ;;
    "aarch64")
        CONFIG_NAME="aarch64-gcc-8.5.0-glibc-2.28"
        ;;
    "armv7l" | "armhf") # uname -m on 32-bit ARM often returns armv7l
        ARCH="armhf" # Normalize architecture name
        CONFIG_NAME="armhf-gcc-8.5.0-glibc-2.28"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH. Supported architectures are x86_64, aarch64, and armhf."
        ;;
esac
log_info "Selected config for $ARCH: ${CONFIG_NAME}.config"

# 5. Prepare build directory and download config
log_info "Preparing build directory: $CT_NG_BUILD_DIR"
mkdir -p "$CT_NG_BUILD_DIR"
cd "$CT_NG_BUILD_DIR"

log_info "Downloading configuration file..."
CONFIG_URL="https://raw.githubusercontent.com/microsoft/vscode-linux-build-agent/main/${CONFIG_NAME}.config"
wget -q -O .config "$CONFIG_URL"

# 6. Run the build
log_info "Starting the crosstool-ng build. This will take a very long time..."
log_info "Output will be in this directory and in the file build.log."
# The build should be run as the current user, not root.
ct-ng build

# 7. Provide final instructions for using the toolchain
TOOLCHAIN_PATH="$HOME/x-tools/${CONFIG_NAME}"
log_info "Build complete!"
log_info "The toolchain has been installed to: $TOOLCHAIN_PATH"
log_info "To use the new toolchain, you must add it and crosstool-ng to your PATH."
log_info "Add the following lines to your ~/.bashrc or ~/.profile:"
echo
echo "  export PATH=\"\$HOME/crosstool-ng/bin:\$HOME/x-tools/${CONFIG_NAME}/bin:\$PATH\""
echo
log_info "Then, run 'source ~/.bashrc' (or log out and log back in) to apply the changes."

exit 0
