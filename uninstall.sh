#!/bin/bash
set -euo pipefail

# Moltbot/Clawdbot Uninstallation and Rollback Script
# This script safely removes the bot and reverts system changes

# Configuration variables
BOT_USER="${BOT_USER:-moltbot}"
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-docker-compose.yml}"
CONFIG_FILE="${CONFIG_FILE:-config.yml}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
}

# Function to check if a user exists
user_exists() {
    id "$1" &> /dev/null
}

# Stop and remove Docker containers
stop_containers() {
    log "Stopping and removing Docker containers..."
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans || true
    fi

    # Remove any remaining containers
    docker rm -f moltbot clawdbot 2>/dev/null || true

    # Remove images
    docker rmi moltbot/moltbot:latest moltbot/clawdbot:latest 2>/dev/null || true

    # Remove volumes
    docker volume rm $(docker volume ls -q | grep moltbot || true) 2>/dev/null || true
}

# Remove bot user and data
remove_bot_user() {
    log "Removing bot user and data..."
    if user_exists "$BOT_USER"; then
        # Kill any processes owned by the user
        pkill -u "$BOT_USER" || true

        # Remove user and home directory
        userdel -r "$BOT_USER" 2>/dev/null || true
        log "Removed user '$BOT_USER'"
    else
        log "User '$BOT_USER' does not exist"
    fi

    # Remove log directory
    rm -rf /var/log/moltbot
}

# Remove configuration files
remove_config() {
    log "Removing configuration files..."
    rm -f "$CONFIG_FILE"
    rm -f "$CONFIG_FILE".backup 2>/dev/null || true
}

# Reset UFW firewall
reset_firewall() {
    log "Resetting UFW firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow OpenSSH
    warn "Firewall reset to default. Only SSH is allowed."
}

# Remove installed packages (optional)
remove_packages() {
    read -p "Remove installed packages (Docker, Fail2ban, etc.)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing installed packages..."
        apt remove -y fail2ban unattended-upgrades docker.io docker-compose-plugin 2>/dev/null || true
        apt autoremove -y
        apt autoclean
    else
        log "Keeping installed packages"
    fi
}

# Remove Tailscale (optional)
remove_tailscale() {
    if command -v tailscale &> /dev/null; then
        read -p "Remove Tailscale? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Removing Tailscale..."
            tailscale down
            apt remove -y tailscale
        else
            log "Keeping Tailscale installed"
        fi
    fi
}

# Remove logrotate configuration
remove_logrotate() {
    log "Removing logrotate configuration..."
    rm -f /etc/logrotate.d/moltbot
}

# Main uninstallation function
main() {
    log "Starting Moltbot/Clawdbot uninstallation..."

    warn "This will remove Moltbot/Clawdbot and revert system hardening."
    warn "Make sure you have backed up any important data."
    read -p "Continue with uninstallation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Uninstallation cancelled."
        exit 0
    fi

    stop_containers
    remove_bot_user
    remove_config
    reset_firewall
    remove_logrotate
    remove_tailscale
    remove_packages

    log "Uninstallation completed successfully!"
    log "System has been reset to a basic hardened state."
    log "SSH access is still available, but other services have been removed."
}

# Run main function
main "$@"