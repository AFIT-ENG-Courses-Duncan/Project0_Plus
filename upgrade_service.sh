#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# auto-lts-upgrade.sh
# One-shot Ubuntu 16.04 → 20.04 unattended upgrader with automatic resume.
# Monitor status with journalctl -u lts-upgrader.service -f
# or tail -f /var/log/lts-upgrader.log
# or systemctl status lts-upgrader.service
# ---------------------------------------------------------------------------
set -euo pipefail

readonly TARGET="20.04"
readonly SELF="/usr/local/bin/lts-upgrader.sh"
readonly SERVICE="/etc/systemd/system/lts-upgrader.service"
readonly STATE="/var/lib/lts-upgrade/state"
readonly LOG_FILE="/var/log/lts-upgrader.log"

# ───── OPTIONAL: enable if you already created a cache drive ─────────────── #
USE_CACHE_DRIVE=true     # set to "false" to skip bind mounts on each boot
CACHE_DEVICE="/dev/sdb1"
CACHE_MOUNT="/mnt/upgrade-cache"
# -------------------------------------------------------------------------- #

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [*] $*"
}
die() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [!] $*" >&2; exit 1;
}

require_root() [[ $EUID -eq 0 ]] || die "Run as root."

get_ver() { lsb_release -rs; }   # e.g. 16.04
next_lts() {
  case "$1" in 16.04) echo 18.04 ;;
  18.04) echo 20.04 ;;
  *) echo "" ;;
  esac
}

setup_cache_binds() {
  $USE_CACHE_DRIVE || return 0
  mkdir -p "$CACHE_MOUNT"
  mountpoint -q "$CACHE_MOUNT" || mount "$CACHE_DEVICE" "$CACHE_MOUNT"
  for dir in apt-archives tmp var-tmp; do
    mkdir -p "$CACHE_MOUNT/$dir"
  done
  mount --bind "$CACHE_MOUNT/apt-archives" /var/cache/apt/archives
  mount --bind "$CACHE_MOUNT/tmp"          /tmp
  mount --bind "$CACHE_MOUNT/var-tmp"      /var/tmp
  sudo chmod 1777 "$CACHE_MOUNT/tmp"

}


create_service() {
cat > "$SERVICE" <<EOF
[Unit]
Description=Ubuntu LTS Auto-Upgrader
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$SELF --resume
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
TimeoutSec=infinity
Restart=no
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable lts-upgrader.service
}

disable_service() {
  systemctl disable --now lts-upgrader.service 2>/dev/null || true
  rm -f "$SERVICE" "$STATE"
}

upgrade_steps() {
  local from="$1" to="$2"

  if [[ -f /var/run/reboot-required ]]; then
    log "System requires a reboot before proceeding. Rebooting now..."
    # The service will restart the script after the reboot.
    reboot
    exit 0
  fi

  log "Upgrading $from → $to …"
  log "Detailed logs for the release upgrade will be in /var/log/dist-upgrade/"
  export DEBIAN_FRONTEND=noninteractive

  # --- Pre-configure GRUB to prevent interactive prompts ---
  # Find the boot disk (e.g., /dev/sda) from the root partition.
  # This prevents dpkg from halting on a GRUB configuration prompt during the upgrade.
  log "Attempting to pre-configure GRUB install device..."
  local root_part boot_disk
  root_part=$(findmnt -n -o SOURCE /)
  # lsblk -no pkname gives the parent kernel name (the disk) for a partition.
  boot_disk="/dev/$(lsblk -no pkname "$root_part" 2>/dev/null || echo "")"

  if [[ -z "$boot_disk" || ! -b "$boot_disk" ]]; then
      log "Warning: Could not determine boot disk. Unattended GRUB install may fail."
  else
      log "Pre-configuring GRUB to install to '$boot_disk' to prevent interactive prompts."
      # Pre-answer the questions for both MBR (grub-pc) and EFI (grub-efi) installs.
      echo "grub-pc grub-pc/install_devices multiselect $boot_disk" | debconf-set-selections
      echo "grub-efi-amd64 grub-efi/install_devices multiselect $boot_disk" | debconf-set-selections
  fi
  # ---------------------------------------------------------

  apt-get update
  apt-get -y upgrade
  apt-get -y dist-upgrade
  apt-get -y autoremove
  sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades

  if [[ -f /var/run/reboot-required ]]; then
    log "System requires a reboot before proceeding. Rebooting now..."
    # The service will restart the script after the reboot.
    reboot
    exit 0
  fi
  do-release-upgrade -f DistUpgradeViewNonInteractive
}

main() {
  require_root
  [[ ${1:-} == "--resume" ]] || {  # first run
    cp "$0" "$SELF"
    create_service
  }

  #setup_cache_binds

  local ver; ver=$(get_ver)
  if dpkg --compare-versions "$ver" ge "$TARGET"; then
    log "System is already on $ver (≥ $TARGET). Cleaning up."
    disable_service
    exit 0
  fi

  local next; next=$(next_lts "$ver") || die "Unsupported start version $ver."
  mkdir -p "$(dirname "$STATE")"
  echo "$next" > "$STATE"
  upgrade_steps "$ver" "$next"
  log "Rebooting to complete $ver → $next …"
  reboot
}



main "$@"
