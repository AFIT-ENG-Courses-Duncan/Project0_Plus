#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup-upgrade-cache.sh
# Redirect and persist Ubuntu upgrade cache & temp space to a separate drive.
# Works on Ubuntu 16.04+ and any modern systemd-based Ubuntu release.
# -----------------------------------------------------------------------------
set -euo pipefail

## ─── CONFIGURABLE VARIABLES ──────────────────────────────────────────────── ##
# Block device or existing partition
DEVICE="/dev/sdb1"
# Mount point for the cache drive
CACHE_MOUNT="/mnt/upgrade-cache"
# Sub-directories on that drive
CACHE_ROOT="/upgrade-cache"
APT_CACHE_DIR="${CACHE_MOUNT}${CACHE_ROOT}/apt-archives"
TMP_DIR="${CACHE_MOUNT}${CACHE_ROOT}/tmp"          # comment out if you don't want /tmp offloaded
VAR_TMP_DIR="${CACHE_MOUNT}${CACHE_ROOT}/var-tmp"  # comment out if you don't want /var/tmp offloaded
# Filesystem type on $DEVICE (ext4 recommended)
FSTYPE="ext4"
# --------------------------------------------------------------------------- ##

log() { printf "\e[32m[*] %s\e[0m\n" "$*"; }
err() { printf "\e[31m[!] %s\e[0m\n" "$*" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then err "Run as root or with sudo."; exit 1; fi
}

check_device() {
  if ! lsblk -f | grep -q "$(basename "$DEVICE")"; then
    err "Device $DEVICE not found; edit the script variables."
    exit 1
  fi
}

backup_fstab() {
  local ts
  ts="$(date '+%Y%m%d_%H%M%S')"
  cp /etc/fstab "/etc/fstab.backup.${ts}"
  log "Backed up /etc/fstab to /etc/fstab.backup.${ts}"
}

ensure_formatted() {
  if ! blkid -o value -s TYPE "$DEVICE" | grep -q "$FSTYPE"; then
    read -rp "Format $DEVICE as $FSTYPE? **ALL DATA WILL BE LOST** [y/N]: " ans
    [[ $ans == [Yy]* ]] || { err "Aborting."; exit 1; }
    mkfs -t "$FSTYPE" -F "$DEVICE"
    log "Formatted $DEVICE as $FSTYPE."
  fi
}

mount_cache_drive() {
  mkdir -p "$CACHE_MOUNT"
  if ! mountpoint -q "$CACHE_MOUNT"; then
    mount "$DEVICE" "$CACHE_MOUNT"
    log "Mounted $DEVICE at $CACHE_MOUNT."
  fi
}

create_dirs() {
  mkdir -p "$APT_CACHE_DIR"
  mkdir -p "$TMP_DIR" "$VAR_TMP_DIR"
  sudo chmod 1777 "$TMP_DIR"
}

move_existing_cache() {
  if [[ -d /var/cache/apt/archives && -n "$(ls -A /var/cache/apt/archives)" ]]; then
    mv /var/cache/apt/archives/* "$APT_CACHE_DIR"/ || true
    log "Moved existing APT archive files to $APT_CACHE_DIR."
  fi
}

bind_mounts() {
  # Temporary runtime bind mounts
  mount --bind "$APT_CACHE_DIR" /var/cache/apt/archives
  mount --bind "$TMP_DIR" /tmp
  mount --bind "$VAR_TMP_DIR" /var/tmp
  log "Bind mounts active."
}

persist_fstab() {
  backup_fstab
  {
    echo ""
    echo "# === Upgrade cache / temp space (added by setup-upgrade-cache.sh) ==="
    echo "$DEVICE  $CACHE_MOUNT  $FSTYPE  defaults  0  2"
    echo "$APT_CACHE_DIR  /var/cache/apt/archives  none  bind  0  0"
    echo "$TMP_DIR         /tmp                      none  bind  0  0"
    echo "$VAR_TMP_DIR     /var/tmp                  none  bind  0  0"
  } >> /etc/fstab
  log "Added persistent mounts to /etc/fstab."
}

main() {
  require_root
  check_device
  ensure_formatted
  mount_cache_drive
  create_dirs
  move_existing_cache
  bind_mounts
  persist_fstab
  log "Setup complete. Verify with:  df -hT /var/cache/apt/archives /tmp /var/tmp"
  log "Reboot to confirm the bind mounts persist automatically."
}

main "$@"
