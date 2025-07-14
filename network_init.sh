#!/bin/bash

# network_init.sh
# This script automates the configuration of an unassigned network interface to use DHCP.
# It performs the following actions:
# 1. Enumerates network interfaces.
# 2. Identifies an Ethernet interface that has no IPv4 address.
# 3. Configures the interface for DHCP persistently across reboots.
#
# The script will attempt to use 'netplan' first, and fall back to '/etc/network/interfaces'.

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script Logic ---

# 1. Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root. Please use 'sudo'."
fi

log_info "Starting network initialization script..."

# 2. Enumerate interfaces and identify one with no IP address
log_info "Searching for an unconfigured network interface..."
TARGET_INTERFACE=""
# List all directories in /sys/class/net, which correspond to network interfaces
for iface in $(ls /sys/class/net); do
    # Skip the loopback interface
    if [ "$iface" == "lo" ]; then
        continue
    fi

    # Check if the interface has an IPv4 address assigned.
    # The '-q' flag silences grep's output. The exit code is 0 if a match is found.
    if ! ip -4 addr show dev "$iface" | grep -q 'inet'; then
        log_info "Found unconfigured interface: $iface"
        TARGET_INTERFACE=$iface
        break
    fi
done

if [ -z "$TARGET_INTERFACE" ]; then
    log_error "No unconfigured network interface found. Aborting."
fi

# 3. Configure the interface for DHCP persistently
log_info "Configuring $TARGET_INTERFACE for DHCP..."

if [ -d /etc/netplan ]; then
    # Modern Ubuntu/Debian systems use netplan
    log_info "Detected 'netplan' configuration system."
    CONFIG_FILE="/etc/netplan/99-dhcp-init.yaml"
    log_info "Creating netplan config file: $CONFIG_FILE"
    
    # Create a new configuration file for our interface
    cat > "$CONFIG_FILE" << EOF
network:
  version: 2
  ethernets:
    $TARGET_INTERFACE:
      dhcp4: true
EOF
    
    log_info "Applying new network configuration..."
    netplan apply

elif [ -f /etc/network/interfaces ]; then
    # Older Debian/Ubuntu systems use ifupdown
    log_info "Detected '/etc/network/interfaces' configuration system."
    log_info "Backing up /etc/network/interfaces to /etc/network/interfaces.bak"
    cp /etc/network/interfaces /etc/network/interfaces.bak

    log_info "Appending DHCP configuration for $TARGET_INTERFACE..."
    echo -e "\n# Added by network_init.sh\nauto $TARGET_INTERFACE\niface $TARGET_INTERFACE inet dhcp" >> /etc/network/interfaces
    
    log_info "Bringing up interface $TARGET_INTERFACE..."
    ifup "$TARGET_INTERFACE"
else
    log_error "Could not find a supported network configuration system (netplan or ifupdown). Aborting."
fi

log_info "Network initialization complete!"
log_info "Interface $TARGET_INTERFACE is now configured for DHCP and should persist after reboot."
exit 0