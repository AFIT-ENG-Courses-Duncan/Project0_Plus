#!/bin/bash
#
# vm_setup_main.sh
# Class project vm configuration orchestrator script
# This script automates the setup of a remote development target for a class project that will support Visual Studio Code.
# Each setup script runs sequentially with system reboots between steps to ensure proper initialization.
#
# Usage:
#   sudo ./vm_setup_main.sh         - Start the setup process
#   sudo ./vm_setup_main.sh --resume - Resume after reboot (handled automatically by service)
#
# Monitor progress with:
#   journalctl -u vm-setup-orchestrator.service -f
#   tail -f /var/log/vm-setup-orchestrator.log
#   systemctl status vm-setup-orchestrator.service

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly SETUP_SCRIPTS_DIR="setup_scripts"
readonly SELF="/usr/local/bin/vm-setup-orchestrator.sh"
readonly SERVICE="/etc/systemd/system/vm-setup-orchestrator.service"
readonly STATE_DIR="/var/lib/vm-setup"
readonly STATE_FILE="$STATE_DIR/current_step"
readonly COMPLETION_FILE="$STATE_DIR/completed_steps"
readonly LOG_FILE="/var/log/vm-setup-orchestrator.log"

# RUNTIME_SCRIPTS will be a list of scripts that will be run at runtime.
readonly RUNTIME_SCRIPTS=(
    "setup_drive_initialization.sh"
    "setup_network_configuration.sh"
    "setup_upgrade_cache.sh"
    "upgrade_service.sh"
    "setup_class_dependencies.sh"
)
# This directory contains the setup scripts for the class project.
# It should be relative to the current working directory.
# --- End Configuration ---

# --- Logging and Utility Functions ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ORCHESTRATOR] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

die() {
    error "$*"
    exit 1
}

require_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root. Use: sudo $0"
}

# --- State Management Functions ---
get_current_step() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "0"
}

set_current_step() {
    local step="$1"
    mkdir -p "$STATE_DIR"
    echo "$step" > "$STATE_FILE"
}

mark_step_completed() {
    local step="$1"
    local script_name="$2"
    mkdir -p "$STATE_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Step $step: $script_name" >> "$COMPLETION_FILE"
}

is_setup_complete() {
    local current_step
    current_step=$(get_current_step)
    [[ $current_step -ge ${#RUNTIME_SCRIPTS[@]} ]]
}

# --- Service Management Functions ---
create_orchestrator_service() {
    log "Creating VM setup orchestrator service..."
    cat > "$SERVICE" <<EOF
[Unit]
Description=VM Setup Orchestrator Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c "$SELF --resume >> $LOG_FILE 2>&1"
TimeoutSec=infinity
Restart=no
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable vm-setup-orchestrator.service
    log "Orchestrator service created and enabled"
}

disable_orchestrator_service() {
    log "Disabling VM setup orchestrator service..."
    systemctl disable --now vm-setup-orchestrator.service 2>/dev/null || true
    rm -f "$SERVICE"
    systemctl daemon-reload
    log "Orchestrator service disabled and removed"
}

# --- Script Execution Functions ---
execute_setup_script() {
    local script_name="$1"
    local script_path="$SETUP_SCRIPTS_DIR/$script_name"
    
    log "Executing setup script: $script_name"
    
    if [[ ! -f "$script_path" ]]; then
        error "Setup script not found: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    # Special handling for upgrade_service.sh which manages its own service and reboots
    if [[ "$script_name" == "upgrade_service.sh" ]]; then
        log "Executing upgrade service script (handles its own reboots and service management)"
        bash "$script_path"
        # If we reach here, the upgrade is complete or failed
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log "Upgrade service completed successfully"
            return 0
        else
            error "Upgrade service failed with exit code: $exit_code"
            return $exit_code
        fi
    else
        # Regular script execution
        log "Running: bash $script_path"
        bash "$script_path"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log "Script $script_name completed successfully"
            return 0
        else
            error "Script $script_name failed with exit code: $exit_code"
            return $exit_code
        fi
    fi
}

needs_reboot_after_script() {
    local script_name="$1"
    
    # Check if system requires reboot
    [[ -f /var/run/reboot-required ]] && return 0
    
    # Always reboot after these scripts to ensure clean state
    case "$script_name" in
        "setup_drive_initialization.sh"|"setup_network_configuration.sh"|"setup_upgrade_cache.sh"|"upgrade_service.sh")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# --- Main Orchestration Logic ---
run_next_step() {
    local current_step
    current_step=$(get_current_step)
    
    if is_setup_complete; then
        log "All setup steps completed successfully!"
        log "Completed steps:"
        [[ -f "$COMPLETION_FILE" ]] && cat "$COMPLETION_FILE" | tee -a "$LOG_FILE"
        disable_orchestrator_service
        log "VM setup orchestration complete. System is ready for use."
        return 0
    fi
    
    local script_name="${RUNTIME_SCRIPTS[$current_step]}"
    log "Starting step $((current_step + 1))/${#RUNTIME_SCRIPTS[@]}: $script_name"
    
    if execute_setup_script "$script_name"; then
        log "Step $((current_step + 1)) completed: $script_name"
        mark_step_completed "$((current_step + 1))" "$script_name"
        set_current_step "$((current_step + 1))"
        
        if needs_reboot_after_script "$script_name"; then
            log "System reboot required after $script_name. Rebooting now..."
            log "The orchestrator service will automatically resume after reboot."
            reboot
            exit 0
        else
            log "No reboot required. Proceeding to next step..."
            run_next_step
        fi
    else
        error "Step $((current_step + 1)) failed: $script_name"
        error "Setup process halted. Check logs for details."
        exit 1
    fi
}

# --- Main Function ---
main() {
    require_root
    
    # Ensure log file exists and is writable
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "=== VM Setup Orchestrator Starting ==="
    log "Process ID: $$"
    log "Working directory: $(pwd)"
    log "Script location: $0"
    
    case "${1:-}" in
        "--resume")
            log "Resuming setup process after reboot..."
            ;;
        "")
            log "Starting new VM setup process..."
            # Copy script to system location for service execution
            cp "$0" "$SELF"
            create_orchestrator_service
            # Initialize state
            set_current_step "0"
            log "Orchestrator initialized. Starting first step..."
            ;;
        *)
            echo "Usage: $0 [--resume]"
            echo "  --resume   Resume setup after reboot (used by service)"
            exit 1
            ;;
    esac
    
    # Verify all setup scripts exist before starting
    log "Verifying setup scripts..."
    for script in "${RUNTIME_SCRIPTS[@]}"; do
        local script_path="$SETUP_SCRIPTS_DIR/$script"
        if [[ ! -f "$script_path" ]]; then
            die "Required setup script not found: $script_path"
        fi
        log "Found: $script_path"
    done
    
    # Start or resume the setup process
    run_next_step
}

# Execute main function with all arguments
main "$@"

