#!/bin/bash

set -e

echo "[*] Starting Ubuntu upgrade from 16.04 to 20.04"

# Step 1: Ensure system is up to date
echo "[*] Updating current system (16.04)..."
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# Step 2: Install update-manager-core if missing
echo "[*] Ensuring update-manager-core is installed..."
sudo apt install -y update-manager-core

# Step 3: Set release upgrader to LTS mode
echo "[*] Configuring do-release-upgrade for LTS upgrades only..."
sudo sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades

# Step 4: Upgrade from 16.04 to 18.04
echo "[*] Initiating upgrade to 18.04 LTS..."
sudo do-release-upgrade -f DistUpgradeViewNonInteractive

# -- Manual reboot will be required here --
echo "[*] Please reboot the system to complete upgrade to 18.04 LTS, then re-run this script to continue to 20.04."
exit 0
