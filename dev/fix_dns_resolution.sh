#!/bin/bash

# fix_dns_resolution.sh — Diagnoses and fixes DNS resolution issues via systemd-resolved

set -e

echo "==> Checking current DNS resolution status..."
ping -c 1 www.google.com > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ DNS resolution appears to be working."
    exit 0
else
    echo "⚠️  DNS resolution failed. Attempting to fix..."
fi

echo -e "\n==> Restarting systemd-resolved..."
sudo systemctl restart systemd-resolved

echo -e "\n==> Waiting 2 seconds for systemd-resolved to stabilize..."
sleep 2

echo -e "\n==> Current DNS configuration (resolvectl):"
resolvectl status

echo -e "\n==> Retesting DNS resolution..."
ping -c 2 www.google.com

if [ $? -eq 0 ]; then
    echo "✅ DNS resolution successfully restored."
    exit 0
else
    echo "❌ DNS resolution still failing after restart."
    echo "💡 Consider checking /etc/resolv.conf, systemd-resolved logs, or setting DNS manually."
    exit 1
fi
