#!/bin/bash
set -euo pipefail

# Moltbot/Clawdbot Installation and Ubuntu Hardening Script
# This script is idempotent and can be run multiple times safely

# Configuration variables (set these via environment variables)
BOT_PASSWORD="${BOT_PASSWORD:-}"  # Required: Strong password for bot auth
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"  # Optional: For automated Tailscale setup
BOT_USER="${BOT_USER:-moltbot}"  # Non-root user for running the bot
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-docker-compose.yml}"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-config.template}"
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

# Validate required environment variables
if [[ -z "$BOT_PASSWORD" ]]; then
    error "BOT_PASSWORD environment variable is required"
    exit 1
fi

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
}

# Function to check if a service is running
is_service_running() {
    systemctl is-active --quiet "$1"
}

# Function to check if a user exists
user_exists() {
    id "$1" &> /dev/null
}

# Doctor check function
doctor_check() {
    log "Running doctor check..."

    local warnings=0

    # Check UFW status
    if ! ufw status | grep -q "Status: active"; then
        warn "UFW firewall is not active"
        ((warnings++))
    fi

    # Check if only allowed ports are open
    if ufw status | grep -q "22/tcp\|41641/udp"; then
        : # SSH and Tailscale are allowed
    else
        warn "SSH (22) or Tailscale (41641) ports not properly configured in UFW"
        ((warnings++))
    fi

    # Check Fail2ban
    if ! is_service_running fail2ban; then
        warn "Fail2ban service is not running"
        ((warnings++))
    fi

    # Check unattended-upgrades
    if ! is_service_running unattended-upgrades; then
        warn "Unattended security updates are not enabled"
        ((warnings++))
    fi

    # Check Docker
    if ! docker --version &> /dev/null; then
        warn "Docker is not installed"
        ((warnings++))
    fi

    # Check Tailscale
    if ! tailscale version &> /dev/null; then
        warn "Tailscale is not installed"
        ((warnings++))
    fi

    # Check bot user
    if ! user_exists "$BOT_USER"; then
        warn "Bot user '$BOT_USER' does not exist"
        ((warnings++))
    fi

    # Check Docker containers
    if ! docker ps | grep -q "moltbot\|clawdbot"; then
        warn "Moltbot/Clawdbot containers are not running"
        ((warnings++))
    fi

    if [[ $warnings -eq 0 ]]; then
        log "All checks passed! System is properly hardened and bot is installed."
    else
        warn "Found $warnings warning(s). Please review the output above."
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    local packages=(ufw fail2ban unattended-upgrades logrotate docker.io docker-compose-plugin curl)

    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            apt install -y "$package"
        else
            log "$package is already installed"
        fi
    done
}

# Configure UFW firewall
configure_ufw() {
    log "Configuring UFW firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow OpenSSH
    ufw allow 41641/udp  # Tailscale
    ufw --force enable
}

# Configure Fail2ban
configure_fail2ban() {
    log "Configuring Fail2ban for SSH protection..."
    if [[ ! -f /etc/fail2ban/jail.local ]]; then
        cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
        systemctl restart fail2ban
    else
        log "Fail2ban is already configured"
    fi
}

# Enable unattended security updates
enable_unattended_upgrades() {
    log "Enabling unattended security updates..."
    if [[ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
        systemctl restart unattended-upgrades
    else
        log "Unattended upgrades are already enabled"
    fi
}

# Configure log rotation
configure_logrotate() {
    log "Configuring log rotation..."
    if [[ ! -f /etc/logrotate.d/moltbot ]]; then
        cat > /etc/logrotate.d/moltbot << EOF
/var/log/moltbot/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 $BOT_USER $BOT_USER
}
EOF
    else
        log "Log rotation for moltbot is already configured"
    fi
}

# Install and configure Tailscale
install_tailscale() {
    log "Installing Tailscale..."
    if ! tailscale version &> /dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
        if [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
            tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --accept-routes
        else
            warn "TAILSCALE_AUTH_KEY not provided. Please run 'tailscale up' manually to authenticate."
        fi
    else
        log "Tailscale is already installed"
    fi
}

# Create non-root user for bot
create_bot_user() {
    log "Creating non-root user for bot..."
    if ! user_exists "$BOT_USER"; then
        useradd -m -s /bin/bash "$BOT_USER"
        usermod -aG docker "$BOT_USER"
        log "Created user '$BOT_USER' and added to docker group"
    else
        log "User '$BOT_USER' already exists"
    fi
}

# Install and configure bot
install_bot() {
    log "Installing Moltbot/Clawdbot..."

    # Create config from template
    if [[ -f "$CONFIG_TEMPLATE" ]]; then
        cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
        # Replace password placeholder
        sed -i "s/PASSWORD_PLACEHOLDER/$BOT_PASSWORD/g" "$CONFIG_FILE"
        chown "$BOT_USER:$BOT_USER" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    else
        error "Config template '$CONFIG_TEMPLATE' not found"
        exit 1
    fi

    # Create log directory
    mkdir -p /var/log/moltbot
    chown "$BOT_USER:$BOT_USER" /var/log/moltbot

    # Run docker-compose as bot user
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        su - "$BOT_USER" -c "docker-compose -f $DOCKER_COMPOSE_FILE up -d"
    else
        error "Docker Compose file '$DOCKER_COMPOSE_FILE' not found"
        exit 1
    fi
}

# Main installation function
main() {
    log "Starting Ubuntu hardening and Moltbot/Clawdbot installation..."

    update_system
    install_packages
    configure_ufw
    configure_fail2ban
    enable_unattended_upgrades
    configure_logrotate
    install_tailscale
    create_bot_user
    install_bot

    log "Installation completed successfully!"
    doctor_check
}

# Run main function
main "$@"