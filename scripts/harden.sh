#!/usr/bin/env bash

set -euo pipefail

LOG_DIR="/var/log/ubuntu-hardening"
BACKUP_DIR="/var/backups/ubuntu-hardening"
SSH_CONFIG="/etc/ssh/sshd_config"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/hardening-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Please run with sudo."
        exit 1
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d-%H%M%S).bak"
    fi
}

update_system() {
    log "Updating package lists..."
    apt-get update
    log "Applying upgrades..."
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
    log "Removing obsolete packages..."
    apt-get -y autoremove
}

configure_ssh() {
    log "Backing up SSH config..."
    backup_file "$SSH_CONFIG"

    log "Hardening SSH configuration..."
    # Use a helper function to set config values safely
    set_ssh_config() {
        local key="$1"
        local value="$2"
        if grep -q "^${key}\b" "$SSH_CONFIG"; then
            sed -i "s/^${key}\b.*/${key} ${value}/" "$SSH_CONFIG"
        else
            echo "${key} ${value}" >> "$SSH_CONFIG"
        fi
    }

    set_ssh_config "PermitRootLogin" "no"
    set_ssh_config "PasswordAuthentication" "no"
    set_ssh_config "PubkeyAuthentication" "yes"
    set_ssh_config "PermitEmptyPasswords" "no"
    set_ssh_config "MaxAuthTries" "4"
    set_ssh_config "LoginGraceTime" "60"
    set_ssh_config "X11Forwarding" "no"
    set_ssh_config "AllowTcpForwarding" "no"
    set_ssh_config "AllowAgentForwarding" "no"
    set_ssh_config "ClientAliveInterval" "300"
    set_ssh_config "ClientAliveCountMax" "3"
    set_ssh_config "DebianBanner" "no"
    set_ssh_config "MACs" "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com"

    log "Validating SSH configuration..."
    sshd -t

    log "Restarting SSH service..."
    systemctl restart ssh
}

configure_firewall() {
    log "Installing UFW..."
    apt-get install -y ufw

    log "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing

    log "Allowing SSH..."
    ufw allow 22/tcp

    # Optional: allow web server
    # ufw allow 80/tcp
    # ufw allow 443/tcp

    log "Enabling UFW..."
    ufw --force enable
}

configure_automatic_updates() {
    log "Installing unattended-upgrades..."
    apt-get install -y unattended-upgrades
    log "Enabling automatic updates..."
    dpkg-reconfigure -f noninteractive unattended-upgrades
}

disable_unnecessary_services() {
    local services=("ModemManager" "fwupd" "multipathd" "udisks2" "upower")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            log "Disabling $svc..."
            systemctl disable --now "$svc"
        fi
    done
}

install_fail2ban() {
    log "Installing fail2ban..."
    apt-get install -y fail2ban
    log "Enabling fail2ban..."
    systemctl enable --now fail2ban
}

review_users() {
    log "Listing interactive users..."
    getent passwd | awk -F: '$7 ~ /\/bash$/ {print $1, $3, $6}'
    echo "Review these users and remove any that are not needed."
}

main() {
    require_root

    log "Starting Ubuntu server hardening..."

    update_system
    configure_ssh
    configure_firewall
    configure_automatic_updates
    disable_unnecessary_services
    install_fail2ban
    review_users

    log "Hardening completed. Please review logs at $LOG_FILE"
}

main "$@"