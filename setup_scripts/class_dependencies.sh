#!/bin/bash
#
# class_dependencies.sh
# Class project workflow dependencies installation script
# This script automates the setup of a remote development target for a class project that will support Visual Studio Code.
# Based on instructions from https://code.visualstudio.com/docs/remote/faq

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Configuration ---
#APT_PACKAGES will be a list of packages to install via apt-get.
APT_PACKAGES="gcc g++ gdbteams build-essential libpthread-stubs0-dev"
# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script Logic ---

log_info "Starting class dependencies installation script."

# 1. Install dependencies
log_info "Updating package lists and installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq $APT_PACKAGES

exit 0
