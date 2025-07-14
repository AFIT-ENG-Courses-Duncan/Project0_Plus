#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# auto-lts-upgrade.sh
# One-shot Ubuntu 16.04 → 20.04 unattended upgrader with automatic resume.
# ---------------------------------------------------------------------------
set -euo pipefail

readonly TARGET="20.04"
readonly SELF="/usr/local/bin/lts-upgrader.sh"
readonly SERVICE="/etc/systemd/system/lts-upgrader.service"
readonly STATE="/var/lib/lts-upgrade/state"

# ───── OPTIONAL: enable if you already created a cache drive ─────────────── #
USE_CACHE_DRIVE=true     # set to "false" to skip bind mounts on each boot
CACHE_DEVICE="/dev/sdb1"
CACHE_MOUNT="/mnt/upgrade-cache"
# -------------------------------------------------------------------------- #

log() { printf "\e[32m[*] %s\e[0m\n" "$*"; }
die() { printf "\e[31m[!] %s\e[0m\n" "$*" >&2; exit 1; }

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
  mountpoint -q "$CACHE_MOUNT" || mount "$CACHE_DEVICE" "$CACHE_MOUNT"
  for dir in apt-archives tmp var-tmp; do
    mkdir -p "$CACHE_MOUNT/$dir"
  done
  mount --bind "$CACHE_MOUNT/apt-archives" /var/cache/apt/archives
  mount --bind "$CACHE_MOUNT/tmp"          /tmp
  mount --bind "$CACHE_MOUNT/var-tmp"      /var/tmp
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
TimeoutSec=infinity
Restart=on-failure

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
  log "Upgrading $from → $to …"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get -y upgrade
  apt-get -y dist-upgrade
  apt-get -y autoremove
  sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades
  do-release-upgrade -f DistUpgradeViewNonInteractive
}

main() {
  require_root
  [[ ${1:-} == "--resume" ]] || {  # first run
    cp "$0" "$SELF"
    create_service
  }

  setup_cache_binds

  local ver; ver=$(get_ver)
  if dpkg --compare-versions "$ver" ge "$TARGET"; then
    log "System is already on $ver (≥ $TARGET). Cleaning up."
    disable_service
    exit 0
  fi

  local next; next=$(next_lts "$ver") || die "Unsupported start version $ver."
  echo "$next" > "$STATE"
  upgrade_steps "$ver" "$next"
  log "Rebooting to complete $ver → $next …"
  reboot
}

main "$@"
