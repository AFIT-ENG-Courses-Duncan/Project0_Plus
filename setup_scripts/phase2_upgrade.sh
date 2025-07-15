#!/bin/bash

set -e

echo "[*] Upgrading Ubuntu 18.04 → 20.04..."

# Step 1: Update 18.04 system
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# Step 2: Confirm LTS prompt
sudo sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades

# Step 3: Run upgrade to 20.04
sudo do-release-upgrade -f DistUpgradeViewNonInteractive

echo "[*] Upgrade initiated. System will reboot on completion."
