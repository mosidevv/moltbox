#!/bin/bash
set -euo pipefail

#############################################################################
# Moltbot/Clawdbot Rollback Script
# 
# This script restores Moltbot from a previous backup.
#
# Usage:
#   sudo bash rollback.sh [backup_directory]
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

BACKUP_DIR="/var/backups/moltbot"
INSTALL_DIR="/opt/moltbot"
CONFIG_DIR="/etc/moltbot"
LOG_DIR="/var/log/moltbot"

echo "========================================="
echo "Moltbot/Clawdbot Rollback"
echo "========================================="
echo ""

#############################################################################
# Select Backup
#############################################################################

if [[ -n "${1:-}" ]]; then
    BACKUP_PATH="$1"
    if [[ ! -d "$BACKUP_PATH" ]]; then
        log_error "Backup directory not found: $BACKUP_PATH"
        exit 1
    fi
else
    # List available backups
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    fi
    
    log_info "Available backups:"
    echo ""
    
    BACKUPS=($(ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | head -10))
    
    if [[ ${#BACKUPS[@]} -eq 0 ]]; then
        log_error "No backups found"
        exit 1
    fi
    
    for i in "${!BACKUPS[@]}"; do
        BACKUP_NAME=$(basename "${BACKUPS[$i]}")
        BACKUP_SIZE=$(du -sh "${BACKUPS[$i]}" | cut -f1)
        echo "  [$i] $BACKUP_NAME ($BACKUP_SIZE)"
    done
    
    echo ""
    log_question "Select backup number to restore (0-$((${#BACKUPS[@]}-1))):"
    read -r -p "> " BACKUP_NUM
    
    if [[ ! "$BACKUP_NUM" =~ ^[0-9]+$ ]] || [[ "$BACKUP_NUM" -ge ${#BACKUPS[@]} ]]; then
        log_error "Invalid backup number"
        exit 1
    fi
    
    BACKUP_PATH="${BACKUPS[$BACKUP_NUM]}"
fi

log_info "Selected backup: $BACKUP_PATH"
echo ""

# Verify backup contents
if [[ ! -d "$BACKUP_PATH/config" ]] && [[ ! -d "$BACKUP_PATH/install" ]]; then
    log_error "Invalid backup: missing required directories"
    exit 1
fi

#############################################################################
# Confirmation
#############################################################################

log_warn "This will restore Moltbot from the selected backup."
log_warn "Current configuration and data will be backed up first."
echo ""
log_question "Continue with rollback? (y/N)"
read -r -p "> " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelled"
    exit 0
fi

#############################################################################
# Backup Current State
#############################################################################

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_BACKUP="$BACKUP_DIR/pre_rollback_$TIMESTAMP"

log_info "Backing up current state to $CURRENT_BACKUP..."
mkdir -p "$CURRENT_BACKUP"

# Backup current config
if [[ -d "$CONFIG_DIR" ]]; then
    cp -r "$CONFIG_DIR" "$CURRENT_BACKUP/config" 2>/dev/null || true
fi

# Backup current logs
if [[ -d "$LOG_DIR" ]]; then
    cp -r "$LOG_DIR" "$CURRENT_BACKUP/logs" 2>/dev/null || true
fi

# Backup current installation
if [[ -d "$INSTALL_DIR" ]]; then
    cp -r "$INSTALL_DIR" "$CURRENT_BACKUP/install" 2>/dev/null || true
fi

# Export current Docker volumes
if docker volume ls | grep -q moltbot-data; then
    log_info "Backing up current Docker volume..."
    docker run --rm -v moltbot-data:/data -v "$CURRENT_BACKUP":/backup alpine tar czf /backup/moltbot-data.tar.gz -C /data . 2>/dev/null || true
fi

log_info "Current state backed up"

#############################################################################
# Stop Services
#############################################################################

log_info "Stopping Moltbot service..."

if systemctl is-active --quiet moltbot; then
    systemctl stop moltbot
    log_info "Moltbot service stopped"
fi

#############################################################################
# Restore Configuration
#############################################################################

log_info "Restoring configuration..."

if [[ -d "$BACKUP_PATH/config" ]]; then
    rm -rf "$CONFIG_DIR"
    cp -r "$BACKUP_PATH/config" "$CONFIG_DIR"
    chown -R root:root "$CONFIG_DIR"
    chmod 750 "$CONFIG_DIR"
    chmod 600 "$CONFIG_DIR/config.json" 2>/dev/null || true
    log_info "Configuration restored"
fi

#############################################################################
# Restore Installation Files
#############################################################################

log_info "Restoring installation files..."

if [[ -d "$BACKUP_PATH/install" ]]; then
    rm -rf "$INSTALL_DIR"
    cp -r "$BACKUP_PATH/install" "$INSTALL_DIR"
    
    MOLTBOT_USER=$(grep -oP 'User=\K[^ ]+' /etc/systemd/system/moltbot.service 2>/dev/null || echo "moltbot")
    chown -R "$MOLTBOT_USER:$MOLTBOT_USER" "$INSTALL_DIR"
    chmod 640 "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || true
    
    log_info "Installation files restored"
fi

#############################################################################
# Restore Docker Volumes
#############################################################################

if [[ -f "$BACKUP_PATH/moltbot-data.tar.gz" ]]; then
    log_info "Restoring Docker volume data..."
    
    # Remove existing volume
    docker volume rm moltbot-data 2>/dev/null || true
    
    # Create new volume
    docker volume create moltbot-data
    
    # Restore data
    docker run --rm -v moltbot-data:/data -v "$BACKUP_PATH":/backup alpine tar xzf /backup/moltbot-data.tar.gz -C /data
    
    log_info "Docker volume data restored"
fi

#############################################################################
# Restore Logs (Optional)
#############################################################################

if [[ -d "$BACKUP_PATH/logs" ]]; then
    log_question "Do you want to restore logs? (y/N)"
    read -r -p "> " RESTORE_LOGS
    
    if [[ "$RESTORE_LOGS" =~ ^[Yy]$ ]]; then
        rm -rf "$LOG_DIR"
        cp -r "$BACKUP_PATH/logs" "$LOG_DIR"
        
        MOLTBOT_USER=$(grep -oP 'User=\K[^ ]+' /etc/systemd/system/moltbot.service 2>/dev/null || echo "moltbot")
        chown -R "$MOLTBOT_USER:$MOLTBOT_USER" "$LOG_DIR"
        
        log_info "Logs restored"
    else
        log_info "Logs not restored"
    fi
fi

#############################################################################
# Restart Services
#############################################################################

log_info "Restarting Moltbot service..."

systemctl daemon-reload

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    cd "$INSTALL_DIR"
    
    MOLTBOT_USER=$(grep -oP 'User=\K[^ ]+' /etc/systemd/system/moltbot.service 2>/dev/null || echo "moltbot")
    sudo -u "$MOLTBOT_USER" docker-compose pull
fi

systemctl start moltbot

# Wait for service to start
sleep 5

if systemctl is-active --quiet moltbot; then
    log_info "Moltbot service started successfully"
else
    log_error "Failed to start Moltbot service"
    log_error "Check logs: journalctl -u moltbot -n 50"
    exit 1
fi

#############################################################################
# Verify Restoration
#############################################################################

log_info "Verifying restoration..."

ISSUES=0

# Check service
if ! systemctl is-active --quiet moltbot; then
    log_error "Moltbot service is not running"
    ((ISSUES++))
fi

# Check container
if ! docker ps | grep -q moltbot; then
    log_error "Moltbot container is not running"
    ((ISSUES++))
fi

# Check config
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    log_error "Configuration file missing"
    ((ISSUES++))
fi

if [[ $ISSUES -eq 0 ]]; then
    log_info "Verification passed"
else
    log_warn "Verification found $ISSUES issue(s)"
fi

#############################################################################
# Rollback Complete
#############################################################################

echo ""
echo "========================================="
log_info "Rollback Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✓ Restored from: $BACKUP_PATH"
echo "  ✓ Current state backed up to: $CURRENT_BACKUP"
echo "  ✓ Moltbot service restarted"
echo ""
echo "Next steps:"
echo "  1. Run health check: sudo -u $MOLTBOT_USER $INSTALL_DIR/moltbot-doctor.sh"
echo "  2. Check logs: docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f"
echo "  3. Verify configuration: sudo cat $CONFIG_DIR/config.json"
echo ""

if [[ $ISSUES -gt 0 ]]; then
    log_warn "Some issues were detected. Please review the logs."
    exit 1
fi

log_info "Rollback completed successfully"
