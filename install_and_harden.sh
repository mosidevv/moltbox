#!/bin/bash
set -euo pipefail

#############################################################################
# Moltbot/Clawdbot Secure Installation & Ubuntu Hardening Script
# 
# This script is IDEMPOTENT and can be run multiple times safely.
# It installs Moltbot/Clawdbot with Docker, hardens Ubuntu 22.04,
# and configures secure access via Tailscale or SSH tunnel only.
#
# Required Environment Variables:
#   MOLTBOT_PASSWORD    - Strong password for Moltbot auth (min 16 chars)
#   TAILSCALE_AUTHKEY   - Tailscale auth key (optional, for auto-join)
#   MOLTBOT_USER        - Non-root user to run Moltbot (default: moltbot)
#
# Usage:
#   export MOLTBOT_PASSWORD="your-strong-password-here"
#   export TAILSCALE_AUTHKEY="tskey-auth-xxxxx" # optional
#   sudo -E bash install_and_harden.sh
#############################################################################

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo -E)"
   exit 1
fi

# Validate required environment variables
if [[ -z "${MOLTBOT_PASSWORD:-}" ]]; then
    log_error "MOLTBOT_PASSWORD environment variable is required"
    log_error "Example: export MOLTBOT_PASSWORD='your-strong-password-here'"
    exit 1
fi

# Validate password strength (min 16 characters)
if [[ ${#MOLTBOT_PASSWORD} -lt 16 ]]; then
    log_error "MOLTBOT_PASSWORD must be at least 16 characters long"
    exit 1
fi

# Set defaults
MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
INSTALL_DIR="/opt/moltbot"
CONFIG_DIR="/etc/moltbot"
LOG_DIR="/var/log/moltbot"
BACKUP_DIR="/var/backups/moltbot"

log_info "Starting Moltbot/Clawdbot secure installation..."
log_info "Installation directory: $INSTALL_DIR"
log_info "Running as user: $MOLTBOT_USER"

#############################################################################
# 1. System Updates & Security Patches
#############################################################################
log_info "Step 1: Updating system packages..."

export DEBIAN_FRONTEND=noninteractive

if ! dpkg -l | grep -q unattended-upgrades; then
    apt-get update -qq
    apt-get upgrade -y -qq
else
    log_info "System already updated, skipping..."
fi

#############################################################################
# 2. Install Required Packages
#############################################################################
log_info "Step 2: Installing required packages..."

REQUIRED_PACKAGES=(
    "docker.io"
    "docker-compose"
    "ufw"
    "fail2ban"
    "unattended-upgrades"
    "apt-listchanges"
    "logrotate"
    "curl"
    "git"
    "gnupg"
    "ca-certificates"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package"; then
        log_info "Installing $package..."
        apt-get install -y -qq "$package"
    else
        log_info "$package already installed"
    fi
done

#############################################################################
# 3. Create Non-Root User
#############################################################################
log_info "Step 3: Creating non-root user '$MOLTBOT_USER'..."

if ! id "$MOLTBOT_USER" &>/dev/null; then
    useradd -r -m -s /bin/bash -d "/home/$MOLTBOT_USER" "$MOLTBOT_USER"
    log_info "User $MOLTBOT_USER created"
else
    log_info "User $MOLTBOT_USER already exists"
fi

# Add user to docker group
if ! groups "$MOLTBOT_USER" | grep -q docker; then
    usermod -aG docker "$MOLTBOT_USER"
    log_info "Added $MOLTBOT_USER to docker group"
fi

#############################################################################
# 4. Create Directory Structure
#############################################################################
log_info "Step 4: Creating directory structure..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

chown -R "$MOLTBOT_USER:$MOLTBOT_USER" "$INSTALL_DIR"
chown -R "$MOLTBOT_USER:$MOLTBOT_USER" "$LOG_DIR"
chown -R root:root "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"

#############################################################################
# 5. Configure UFW Firewall
#############################################################################
log_info "Step 5: Configuring UFW firewall..."

# Reset UFW to default if this is first run
if ! ufw status | grep -q "Status: active"; then
    log_info "Configuring UFW for the first time..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (OpenSSH)
    ufw allow OpenSSH
    log_info "UFW: Allowed OpenSSH"
    
    # Allow Tailscale (UDP 41641)
    ufw allow 41641/udp comment 'Tailscale'
    log_info "UFW: Allowed Tailscale UDP 41641"
    
    # Enable UFW
    ufw --force enable
    log_info "UFW enabled"
else
    log_info "UFW already configured and active"
fi

#############################################################################
# 6. Configure Fail2ban
#############################################################################
log_info "Step 6: Configuring Fail2ban for SSH protection..."

if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 7200
EOF
    log_info "Created Fail2ban configuration"
fi

systemctl enable fail2ban
systemctl restart fail2ban
log_info "Fail2ban enabled and started"

#############################################################################
# 7. Configure Unattended Security Updates
#############################################################################
log_info "Step 7: Configuring unattended security updates..."

if [[ ! -f /etc/apt/apt.conf.d/50unattended-upgrades.bak ]]; then
    cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak 2>/dev/null || true
fi

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

log_info "Unattended security updates configured"

#############################################################################
# 8. Configure Log Rotation
#############################################################################
log_info "Step 8: Configuring log rotation..."

cat > /etc/logrotate.d/moltbot <<EOF
$LOG_DIR/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 $MOLTBOT_USER $MOLTBOT_USER
    sharedscripts
    postrotate
        docker-compose -f $INSTALL_DIR/docker-compose.yml restart > /dev/null 2>&1 || true
    endscript
}
EOF

log_info "Log rotation configured for Moltbot logs"

#############################################################################
# 9. Install Tailscale
#############################################################################
log_info "Step 9: Installing Tailscale..."

if ! command -v tailscale &> /dev/null; then
    log_info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    log_info "Tailscale installed"
else
    log_info "Tailscale already installed"
fi

# Start Tailscale if not running
if ! systemctl is-active --quiet tailscaled; then
    systemctl enable tailscaled
    systemctl start tailscaled
    log_info "Tailscale daemon started"
fi

# Auto-join Tailnet if auth key provided
if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    if ! tailscale status &>/dev/null; then
        log_info "Joining Tailscale network..."
        tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
        log_info "Joined Tailscale network"
    else
        log_info "Already connected to Tailscale"
    fi
else
    log_warn "TAILSCALE_AUTHKEY not provided. Run 'tailscale up' manually to join your Tailnet"
fi

#############################################################################
# 10. Create Moltbot Configuration
#############################################################################
log_info "Step 10: Creating Moltbot configuration..."

# Create config.json template
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "authMode": "password",
  "password": "$MOLTBOT_PASSWORD",
  "dmPolicy": "allowlist",
  "channelPolicy": "allowlist",
  "allowedUsers": [],
  "allowedChannels": [],
  "allowedDMs": [],
  "logLevel": "info",
  "maxConcurrentChats": 5,
  "rateLimiting": {
    "enabled": true,
    "maxRequestsPerMinute": 10
  }
}
EOF

chmod 600 "$CONFIG_DIR/config.json"
chown root:root "$CONFIG_DIR/config.json"

log_info "Configuration created at $CONFIG_DIR/config.json"

#############################################################################
# 11. Create Docker Compose File
#############################################################################
log_info "Step 11: Creating Docker Compose configuration..."

cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:
  moltbot:
    image: moltbot:local
    container_name: moltbot
    restart: unless-stopped
    user: "$(id -u $MOLTBOT_USER):$(id -g $MOLTBOT_USER)"
    
    # Bind to loopback only (127.0.0.1) - NOT publicly accessible
    ports:
      - "127.0.0.1:3000:3000"
    
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=info
    
    volumes:
      - $CONFIG_DIR/config.json:/app/config.json:ro
      - $LOG_DIR:/app/logs
      - moltbot-data:/app/data
    
    networks:
      - moltbot-internal
    
    security_opt:
      - no-new-privileges:true
    
    cap_drop:
      - ALL
    
    cap_add:
      - NET_BIND_SERVICE
    
    read_only: true
    
    tmpfs:
      - /tmp:noexec,nosuid,nodev,size=100m
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  moltbot-data:
    driver: local

networks:
  moltbot-internal:
    driver: bridge
    internal: false
EOF

chown "$MOLTBOT_USER:$MOLTBOT_USER" "$INSTALL_DIR/docker-compose.yml"
chmod 640 "$INSTALL_DIR/docker-compose.yml"

log_info "Docker Compose file created"

#############################################################################
# 12. Create Systemd Service
#############################################################################
log_info "Step 12: Creating systemd service..."

cat > /etc/systemd/system/moltbot.service <<EOF
[Unit]
Description=Moltbot/Clawdbot Service
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
User=$MOLTBOT_USER
Group=$MOLTBOT_USER

ExecStart=/usr/bin/docker-compose -f $INSTALL_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $INSTALL_DIR/docker-compose.yml down

Restart=on-failure
RestartSec=10s

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable moltbot.service

log_info "Systemd service created and enabled"

#############################################################################
# 13. Create Helper Scripts
#############################################################################
log_info "Step 13: Creating helper scripts..."

# Doctor script
cat > "$INSTALL_DIR/moltbot-doctor.sh" <<'DOCTOR_EOF'
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "Moltbot/Clawdbot Health Check"
echo "========================================="
echo ""

WARNINGS=0
ERRORS=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    check_warn "Running as root (should run as moltbot user)"
fi

# Check Docker
if systemctl is-active --quiet docker; then
    check_pass "Docker service is running"
else
    check_fail "Docker service is NOT running"
fi

# Check Moltbot service
if systemctl is-active --quiet moltbot; then
    check_pass "Moltbot service is running"
else
    check_fail "Moltbot service is NOT running"
fi

# Check container health
if docker ps | grep -q moltbot; then
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' moltbot 2>/dev/null || echo "unknown")
    if [[ "$HEALTH" == "healthy" ]]; then
        check_pass "Moltbot container is healthy"
    elif [[ "$HEALTH" == "unknown" ]]; then
        check_warn "Moltbot container health status unknown"
    else
        check_fail "Moltbot container is unhealthy: $HEALTH"
    fi
else
    check_fail "Moltbot container is not running"
fi

# Check UFW
if ufw status | grep -q "Status: active"; then
    check_pass "UFW firewall is active"
    
    # Check that port 3000 is NOT publicly exposed
    if ! ufw status | grep -q "3000"; then
        check_pass "Port 3000 is NOT publicly exposed (correct)"
    else
        check_fail "Port 3000 appears in UFW rules (should only bind to loopback)"
    fi
else
    check_fail "UFW firewall is NOT active"
fi

# Check Fail2ban
if systemctl is-active --quiet fail2ban; then
    check_pass "Fail2ban is running"
else
    check_warn "Fail2ban is NOT running"
fi

# Check Tailscale
if systemctl is-active --quiet tailscaled; then
    check_pass "Tailscale daemon is running"
    
    if tailscale status &>/dev/null; then
        check_pass "Connected to Tailscale network"
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        echo "  Tailscale IP: $TS_IP"
    else
        check_warn "Tailscale daemon running but not connected to network"
    fi
else
    check_warn "Tailscale is NOT running"
fi

# Check config file
if [[ -f /etc/moltbot/config.json ]]; then
    check_pass "Configuration file exists"
    
    # Check permissions
    PERMS=$(stat -c "%a" /etc/moltbot/config.json)
    if [[ "$PERMS" == "600" ]]; then
        check_pass "Config file has secure permissions (600)"
    else
        check_warn "Config file permissions are $PERMS (should be 600)"
    fi
    
    # Check auth mode
    if grep -q '"authMode": "password"' /etc/moltbot/config.json; then
        check_pass "Auth mode is set to password"
    else
        check_warn "Auth mode may not be set to password"
    fi
    
    # Check dmPolicy
    if grep -q '"dmPolicy": "allowlist"' /etc/moltbot/config.json; then
        check_pass "DM policy is set to allowlist (secure)"
    else
        check_warn "DM policy is NOT set to allowlist"
    fi
    
    # Check channelPolicy
    if grep -q '"channelPolicy": "allowlist"' /etc/moltbot/config.json; then
        check_pass "Channel policy is set to allowlist (secure)"
    else
        check_warn "Channel policy is NOT set to allowlist"
    fi
else
    check_fail "Configuration file NOT found"
fi

# Check logs
if [[ -d /var/log/moltbot ]]; then
    LOG_COUNT=$(find /var/log/moltbot -name "*.log" 2>/dev/null | wc -l)
    if [[ $LOG_COUNT -gt 0 ]]; then
        check_pass "Log directory exists with $LOG_COUNT log file(s)"
    else
        check_warn "Log directory exists but no log files found"
    fi
else
    check_warn "Log directory does not exist"
fi

# Check for public port exposure
if netstat -tuln 2>/dev/null | grep -q "0.0.0.0:3000" || ss -tuln 2>/dev/null | grep -q "0.0.0.0:3000"; then
    check_fail "Port 3000 is bound to 0.0.0.0 (PUBLICLY ACCESSIBLE - INSECURE!)"
elif netstat -tuln 2>/dev/null | grep -q "127.0.0.1:3000" || ss -tuln 2>/dev/null | grep -q "127.0.0.1:3000"; then
    check_pass "Port 3000 is bound to 127.0.0.1 (loopback only - secure)"
else
    check_warn "Could not determine port 3000 binding status"
fi

# Check unattended upgrades
if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null || [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    check_pass "Unattended security updates are configured"
else
    check_warn "Unattended security updates may not be configured"
fi

echo ""
echo "========================================="
echo "Summary:"
echo "  Errors: $ERRORS"
echo "  Warnings: $WARNINGS"
echo "========================================="

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}System has critical issues that need attention${NC}"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}System is operational but has warnings${NC}"
    exit 0
else
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
fi
DOCTOR_EOF

chmod +x "$INSTALL_DIR/moltbot-doctor.sh"
chown "$MOLTBOT_USER:$MOLTBOT_USER" "$INSTALL_DIR/moltbot-doctor.sh"

log_info "Helper scripts created"

#############################################################################
# 14. Clone Moltbot Repository and Build Docker Image
#############################################################################
log_info "Step 14: Cloning Moltbot repository and building Docker image..."

MOLTBOT_REPO_DIR="$INSTALL_DIR/moltbot-repo"

# Clone repository if not already present
if [[ ! -d "$MOLTBOT_REPO_DIR" ]]; then
    log_info "Cloning Moltbot repository from GitHub..."
    sudo -u "$MOLTBOT_USER" git clone https://github.com/moltbot/moltbot.git "$MOLTBOT_REPO_DIR"
    log_info "Repository cloned successfully"
else
    log_info "Repository already exists, pulling latest changes..."
    cd "$MOLTBOT_REPO_DIR"
    sudo -u "$MOLTBOT_USER" git pull origin main || sudo -u "$MOLTBOT_USER" git pull origin master || true
fi

# Build Docker image from source
cd "$MOLTBOT_REPO_DIR"
log_info "Building Moltbot Docker image (this may take several minutes)..."

if [[ -f "Dockerfile" ]]; then
    sudo -u "$MOLTBOT_USER" docker build -t moltbot:local -f Dockerfile .
    log_info "Moltbot Docker image built successfully"
else
    log_error "Dockerfile not found in repository"
    exit 1
fi

# Build sandbox images if needed
if [[ -f "scripts/sandbox-setup.sh" ]]; then
    log_info "Building sandbox images..."
    sudo -u "$MOLTBOT_USER" bash scripts/sandbox-setup.sh || log_warn "Sandbox setup script failed, continuing..."
fi

# Start service
cd "$INSTALL_DIR"
systemctl start moltbot.service

# Wait for service to be ready
sleep 10

if systemctl is-active --quiet moltbot; then
    log_info "Moltbot service started successfully"
else
    log_error "Failed to start Moltbot service"
    systemctl status moltbot.service
    docker-compose -f "$INSTALL_DIR/docker-compose.yml" logs --tail=50
    exit 1
fi

#############################################################################
# 15. Final Security Checks
#############################################################################
log_info "Step 15: Running final security checks..."

# Ensure no public port exposure
if netstat -tuln 2>/dev/null | grep -q "0.0.0.0:3000" || ss -tuln 2>/dev/null | grep -q "0.0.0.0:3000"; then
    log_error "SECURITY ISSUE: Port 3000 is publicly exposed!"
    log_error "This should only bind to 127.0.0.1"
    exit 1
fi

log_info "Security checks passed"

#############################################################################
# Installation Complete
#############################################################################
echo ""
echo "========================================="
log_info "Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure Tailscale Serve to expose Moltbot:"
echo "   sudo tailscale serve https / http://127.0.0.1:3000"
echo ""
echo "2. Or use SSH tunnel for access:"
echo "   ssh -L 3000:127.0.0.1:3000 user@this-server"
echo ""
echo "3. Run health check:"
echo "   sudo -u $MOLTBOT_USER $INSTALL_DIR/moltbot-doctor.sh"
echo ""
echo "4. View logs:"
echo "   docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f"
echo ""
echo "5. Edit configuration:"
echo "   sudo nano $CONFIG_DIR/config.json"
echo "   sudo systemctl restart moltbot"
echo ""
echo "Security Status:"
echo "  ✓ UFW firewall enabled"
echo "  ✓ Fail2ban protecting SSH"
echo "  ✓ Unattended security updates enabled"
echo "  ✓ Moltbot bound to loopback only (127.0.0.1)"
echo "  ✓ Auth mode: password"
echo "  ✓ DM/Channel policy: allowlist"
echo "  ✓ Running as non-root user: $MOLTBOT_USER"
echo ""
log_warn "Remember: Moltbot is NOT publicly accessible by design."
log_warn "Access only via Tailscale Serve or SSH tunnel."
echo ""
echo "========================================="
