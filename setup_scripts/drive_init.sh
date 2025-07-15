#!/bin/bash

# drive_init.sh
# This script automates the process of setting up a new data drive for the /home directory.
# It performs the following actions:
# 1. Finds a disk with no existing partitions.
# 2. Creates a single partition that uses the entire disk.
# 3. Formats the new partition with the ext4 filesystem.
# 4. Moves the existing /home directory contents to the new partition.
# 5. Configures /etc/fstab to mount the new partition at /home persistently.
# 6. TODO: Configure /etc/fstab to mount space on the new partition at /tmp persistently.
#
# WARNING: This script is destructive and will format an entire disk.
# It is intended for use in a controlled environment like a new VM setup.
# Review the script carefully and ensure you have backups if running on a system with important data.

# --- Configuration ---
FILESYSTEM_TYPE="ext4"
TEMP_MOUNT_POINT="/mnt/newhome"

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

log_info "Starting drive initialization script..."

# 2. Enumerate hard disk devices and identify one with no partitions
log_info "Searching for an unpartitioned disk..."
TARGET_DISK_NAME=""
for disk in $(lsblk -d -n -o NAME,TYPE | grep 'disk' | awk '{print $1}'); do
    # Check if the disk has any partitions by counting the number of block devices associated with it.
    # If the count is 1, it's just the disk itself with no partitions.
    if [ "$(lsblk -l -n "/dev/$disk" | wc -l)" -eq 1 ]; then
        TARGET_DISK_NAME=$disk
        log_info "Found unpartitioned disk: /dev/$TARGET_DISK_NAME"
        break
    fi
done

if [ -z "$TARGET_DISK_NAME" ]; then
    log_error "No unpartitioned disk found. Aborting."
fi

TARGET_DEVICE="/dev/$TARGET_DISK_NAME"

# 3. Create a single partition spanning the entire device
log_info "Creating a new GPT partition table on $TARGET_DEVICE..."
parted -s "$TARGET_DEVICE" mklabel gpt

log_info "Creating a single primary partition..."
parted -s -a opt "$TARGET_DEVICE" mkpart primary $FILESYSTEM_TYPE 0% 100%

# Give the kernel a moment to recognize the new partition table
sleep 2
partprobe "$TARGET_DEVICE"

NEW_PARTITION_NAME=$(lsblk -l -n -o NAME "$TARGET_DEVICE" | tail -n 1)
NEW_PARTITION_PATH="/dev/$NEW_PARTITION_NAME"

if [ ! -b "$NEW_PARTITION_PATH" ]; then
    log_error "Failed to identify the newly created partition. Aborting."
fi
log_info "Successfully created partition: $NEW_PARTITION_PATH"

# 4. Format the partition
log_info "Formatting $NEW_PARTITION_PATH with $FILESYSTEM_TYPE..."
mkfs.$FILESYSTEM_TYPE "$NEW_PARTITION_PATH"

# 5. Move /home to the newly formatted filesystem and mount it persistently
log_info "Preparing to move /home to the new partition..."

mkdir -p "$TEMP_MOUNT_POINT"
mount "$NEW_PARTITION_PATH" "$TEMP_MOUNT_POINT"

log_info "Copying /home contents to new drive. This may take a while..."
rsync -aqx /home/ "$TEMP_MOUNT_POINT/"

umount "$TEMP_MOUNT_POINT"
rmdir "$TEMP_MOUNT_POINT"

log_info "Renaming original /home to /home.old..."
mv /home /home.old

mkdir /home
mount "$NEW_PARTITION_PATH" /home

log_info "Updating /etc/fstab for persistent mounting..."
NEW_HOME_UUID=$(blkid -s UUID -o value "$NEW_PARTITION_PATH")
if [ -z "$NEW_HOME_UUID" ]; then
    log_error "Could not get UUID for $NEW_PARTITION_PATH. You must add it to /etc/fstab manually."
fi

# Backup fstab before modifying, just in case
cp /etc/fstab /etc/fstab.bak
echo "UUID=$NEW_HOME_UUID /home $FILESYSTEM_TYPE defaults 0 2" >> /etc/fstab

log_info "Drive initialization complete!"
log_info "The new partition is now mounted at /home."
log_info "The original home directory is backed up at /home.old."
log_info "Please reboot and verify everything is working before removing it with 'sudo rm -rf /home.old'."

exit 0