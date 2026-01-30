# Moltbot/Clawdbot Secure Installation

This repository contains scripts to securely install Moltbot/Clawdbot on a fresh Ubuntu 22.04 VPS with comprehensive hardening.

## One-Line Installation Command

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/install/main/install_and_harden.sh | BOT_PASSWORD="your-strong-password-here" bash
```

## Required Environment Variables

- `BOT_PASSWORD`: Strong password for bot authentication (required)
- `TAILSCALE_AUTH_KEY`: Tailscale auth key for automated setup (optional, can be set manually)

## What This Does

### Security Hardening
- Enables UFW firewall (allows only SSH and Tailscale)
- Installs and configures Fail2ban for SSH brute force protection
- Enables unattended security updates
- Configures log rotation
- Creates non-root user for bot operations

### Bot Installation
- Installs Docker and Docker Compose
- Sets up Moltbot/Clawdbot in Docker containers
- Configures bot to bind only to loopback/Tailnet (no public ports)
- Sets up password authentication with channel allowlist
- Restricts DM policy to prevent open access

### Access Methods
- **Tailscale Serve**: Access via Tailscale network
- **SSH Tunnel**: Tunnel through SSH for local access
- **No Public Ports**: Gateway never exposed publicly

## Files Included

- `install_and_harden.sh`: Main installation and hardening script (idempotent)
- `docker-compose.yml`: Docker Compose configuration
- `config.template`: Bot configuration template
- `uninstall.sh`: Rollback and cleanup script

## Post-Installation

After installation, the script runs a "doctor check" that verifies:
- UFW is active with correct rules
- Fail2ban is running
- Unattended upgrades are enabled
- Docker and Tailscale are installed
- Bot user exists
- Containers are running

## Manual Configuration Required

After installation, update `config.yml` with:
- Your specific channel IDs in the allowlist
- Any additional bot-specific settings

## Troubleshooting

If the doctor check shows warnings:
1. Review the warning messages
2. Check service status: `systemctl status <service>`
3. View logs: `journalctl -u <service>`
4. Re-run the install script (it's idempotent)

## Uninstallation

To completely remove Moltbot/Clawdbot and revert hardening:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and remove Docker containers
- Remove bot user and data
- Reset firewall rules
- Remove installed packages (optional)

## Security Notes

- Never commit secrets to version control
- Use strong, unique passwords
- Regularly update the system
- Monitor logs for suspicious activity
- Keep Tailscale updated for security patches