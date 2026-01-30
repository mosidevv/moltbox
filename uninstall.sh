#!/bin/bash
set -euo pipefail

#############################################################################
# Moltbot/Clawdbot Uninstallation Script
# 
# This script safely removes Moltbot/Clawdbot and optionally reverts
# system hardening changes. A backup is created before removal.
#
# Usage:
#   sudo bash uninstall.sh
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_question() {
    echo -e "${BLUE}[?]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
INSTALL_DIR="/opt/moltbot"
CONFIG_DIR="/etc/moltbot"
LOG_DIR="/var/log/moltbot"
BACKUP_DIR="/var/backups/moltbot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/uninstall_backup_$TIMESTAMP"

echo "========================================="
echo "Moltbot/Clawdbot Uninstallation"
echo "========================================="
echo ""
log_warn "This will remove Moltbot/Clawdbot from your system."
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

#############################################################################
# Backup Current State
#############################################################################
log_info "Creating backup at $BACKUP_PATH..."

# Backup configuration
if [[ -d "$CONFIG_DIR" ]]; then
    cp -r "$CONFIG_DIR" "$BACKUP_PATH/config" 2>/dev/null || true
    log_info "Backed up configuration"
fi

# Backup logs
if [[ -d "$LOG_DIR" ]]; then
    cp -r "$LOG_DIR" "$BACKUP_PATH/logs" 2>/dev/null || true
    log_info "Backed up logs"
fi

# Backup docker-compose and scripts
if [[ -d "$INSTALL_DIR" ]]; then
    cp -r "$INSTALL_DIR" "$BACKUP_PATH/install" 2>/dev/null || true
    log_info "Backed up installation files"
fi

# Export Docker volumes
if docker volume ls | grep -q moltbot-data; then
    log_info "Backing up Docker volume data..."
    docker run --rm -v moltbot-data:/data -v "$BACKUP_PATH":/backup alpine tar czf /backup/moltbot-data.tar.gz -C /data . 2>/dev/null || true
fi

log_info "Backup completed: $BACKUP_PATH"
echo ""

#############################################################################
# Stop Services
#############################################################################
log_info "Stopping Moltbot service..."

if systemctl is-active --quiet moltbot; then
    systemctl stop moltbot
    log_info "Moltbot service stopped"
else
    log_info "Moltbot service not running"
fi

if systemctl is-enabled --quiet moltbot 2>/dev/null; then
    systemctl disable moltbot
    log_info "Moltbot service disabled"
fi

#############################################################################
# Remove Docker Containers and Volumes
#############################################################################
log_info "Removing Docker containers and volumes..."

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    cd "$INSTALL_DIR"
    docker-compose down -v 2>/dev/null || true
    log_info "Docker containers removed"
else
    # Manual cleanup if docker-compose.yml is missing
    docker stop moltbot 2>/dev/null || true
    docker rm moltbot 2>/dev/null || true
    log_info "Docker containers removed (manual)"
fi

# Remove Docker volumes
if docker volume ls | grep -q moltbot-data; then
    docker volume rm moltbot-data 2>/dev/null || true
    log_info "Docker volumes removed"
fi

# Remove Docker network
if docker network ls | grep -q moltbot-internal; then
    docker network rm moltbot-internal 2>/dev/null || true
    log_info "Docker network removed"
fi

#############################################################################
# Remove Systemd Service
#############################################################################
log_info "Removing systemd service..."

if [[ -f /etc/systemd/system/moltbot.service ]]; then
    rm /etc/systemd/system/moltbot.service
    systemctl daemon-reload
    log_info "Systemd service removed"
fi

#############################################################################
# Remove Files and Directories
#############################################################################
log_info "Removing installation files..."

if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    log_info "Removed $INSTALL_DIR"
fi

if [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR"
    log_info "Removed $CONFIG_DIR"
fi

if [[ -d "$LOG_DIR" ]]; then
    rm -rf "$LOG_DIR"
    log_info "Removed $LOG_DIR"
fi

# Remove log rotation config
if [[ -f /etc/logrotate.d/moltbot ]]; then
    rm /etc/logrotate.d/moltbot
    log_info "Removed log rotation config"
fi

#############################################################################
# Optional: Remove User
#############################################################################
echo ""
log_question "Do you want to remove the '$MOLTBOT_USER' user? (y/N)"
read -r -p "> " REMOVE_USER

if [[ "$REMOVE_USER" =~ ^[Yy]$ ]]; then
    if id "$MOLTBOT_USER" &>/dev/null; then
        userdel -r "$MOLTBOT_USER" 2>/dev/null || userdel "$MOLTBOT_USER"
        log_info "User $MOLTBOT_USER removed"
    fi
else
    log_info "User $MOLTBOT_USER kept"
fi

#############################################################################
# Optional: Revert Firewall Rules
#############################################################################
echo ""
log_question "Do you want to revert UFW firewall rules? (y/N)"
log_warn "This will remove Tailscale firewall rules but keep SSH access"
read -r -p "> " REVERT_FIREWALL

if [[ "$REVERT_FIREWALL" =~ ^[Yy]$ ]]; then
    # Remove Tailscale rule
    ufw delete allow 41641/udp 2>/dev/null || true
    log_info "Removed Tailscale firewall rule"
    
    log_question "Do you want to disable UFW entirely? (y/N)"
    read -r -p "> " DISABLE_UFW
    
    if [[ "$DISABLE_UFW" =~ ^[Yy]$ ]]; then
        ufw --force disable
        log_warn "UFW disabled"
    else
        log_info "UFW kept enabled with current rules"
    fi
else
    log_info "Firewall rules kept unchanged"
fi

#############################################################################
# Optional: Remove Fail2ban Configuration
#############################################################################
echo ""
log_question "Do you want to remove Fail2ban configuration? (y/N)"
read -r -p "> " REMOVE_FAIL2BAN

if [[ "$REMOVE_FAIL2BAN" =~ ^[Yy]$ ]]; then
    if [[ -f /etc/fail2ban/jail.local ]]; then
        rm /etc/fail2ban/jail.local
        systemctl restart fail2ban 2>/dev/null || true
        log_info "Fail2ban configuration removed"
    fi
    
    log_question "Do you want to uninstall Fail2ban entirely? (y/N)"
    read -r -p "> " UNINSTALL_FAIL2BAN
    
    if [[ "$UNINSTALL_FAIL2BAN" =~ ^[Yy]$ ]]; then
        apt-get remove -y fail2ban
        log_info "Fail2ban uninstalled"
    fi
else
    log_info "Fail2ban configuration kept"
fi

#############################################################################
# Optional: Remove Docker
#############################################################################
echo ""
log_question "Do you want to uninstall Docker? (y/N)"
log_warn "Only do this if you're not using Docker for anything else!"
read -r -p "> " REMOVE_DOCKER

if [[ "$REMOVE_DOCKER" =~ ^[Yy]$ ]]; then
    apt-get remove -y docker.io docker-compose
    log_warn "Docker uninstalled"
else
    log_info "Docker kept installed"
fi

#############################################################################
# Optional: Disconnect from Tailscale
#############################################################################
echo ""
log_question "Do you want to disconnect from Tailscale? (y/N)"
read -r -p "> " DISCONNECT_TAILSCALE

if [[ "$DISCONNECT_TAILSCALE" =~ ^[Yy]$ ]]; then
    if command -v tailscale &> /dev/null; then
        tailscale down
        log_info "Disconnected from Tailscale"
        
        log_question "Do you want to uninstall Tailscale? (y/N)"
        read -r -p "> " UNINSTALL_TAILSCALE
        
        if [[ "$UNINSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
            apt-get remove -y tailscale
            log_info "Tailscale uninstalled"
        fi
    fi
else
    log_info "Tailscale kept connected"
fi

#############################################################################
# Cleanup Summary
#############################################################################
echo ""
echo "========================================="
log_info "Uninstallation Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✓ Moltbot service stopped and removed"
echo "  ✓ Docker containers and volumes removed"
echo "  ✓ Configuration and log files removed"
echo "  ✓ Backup created at: $BACKUP_PATH"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_PATH"
echo ""
log_info "To restore from backup, see UNINSTALL.md"
echo ""

# Optional: Remove backup directory
echo ""
log_question "Do you want to keep the backup? (Y/n)"
read -r -p "> " KEEP_BACKUP

if [[ "$KEEP_BACKUP" =~ ^[Nn]$ ]]; then
    rm -rf "$BACKUP_PATH"
    log_warn "Backup removed"
else
    log_info "Backup kept at: $BACKUP_PATH"
fi

echo ""
log_info "Uninstallation completed successfully"
