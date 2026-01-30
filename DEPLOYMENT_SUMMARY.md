# Moltbot/Clawdbot Secure Installation Package

## Package Contents

This package contains everything needed to securely install and manage Moltbot/Clawdbot on Ubuntu 22.04.

### Core Files

| File | Size | Purpose |
|------|------|---------|
| `install_and_harden.sh` | 20KB | Main installation and hardening script |
| `uninstall.sh` | 9.3KB | Complete uninstallation with backup |
| `rollback.sh` | 9.1KB | Restore from backup |
| `docker-compose.yml` | 1.3KB | Docker container configuration |
| `config.template` | 2.0KB | Bot configuration template (YAML) |
| `config.template.json` | 577B | Bot configuration template (JSON) |
| `README.md` | 11KB | Main documentation |
| `UNINSTALL.md` | 7.5KB | Uninstallation and rollback guide |
| `verify_installation.sh` | 8.7KB | Installation verification script |

## Security Features Implemented

### ✅ Network Security
- **No Public Ports**: Gateway binds only to loopback (127.0.0.1) or Tailnet
- **UFW Firewall**: Enabled with strict rules (SSH + Tailscale only)
- **Internal Docker Network**: Containers isolated from external access
- **Tailscale Integration**: Secure access via Tailscale Serve

### ✅ Authentication & Authorization
- **Password Authentication**: Strong password from environment variable
- **Channel Allowlist**: Only specified channels permitted
- **DM Policy**: Pairing mode (not open access)
- **No Secrets in Git**: All sensitive data from environment variables

### ✅ System Hardening
- **Fail2ban**: SSH brute force protection (3 attempts, 1-hour ban)
- **Unattended Security Updates**: Automatic security patches
- **Log Rotation**: Configured for /var/log/moltbot (7-day retention)
- **Non-Root User**: Bot runs as dedicated 'moltbot' user
- **Docker User Isolation**: Containers run with non-root UID

### ✅ Operational Safety
- **Idempotent Scripts**: Can be run multiple times safely
- **Automatic Backups**: Created before uninstall/rollback
- **Doctor Check**: Validates installation and security posture
- **Rollback Capability**: Restore from any backup point
- **Verification Script**: Checks all components before deployment

## Quick Start

### Prerequisites
- Fresh Ubuntu 22.04 VPS
- Root or sudo access
- Strong password for bot authentication

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/install/main/install_and_harden.sh | \
  BOT_PASSWORD="your-strong-password-here" \
  TAILSCALE_AUTH_KEY="tskey-auth-xxx" \
  bash
```

### Required Environment Variables

- `BOT_PASSWORD` (required): Strong password for bot authentication
- `TAILSCALE_AUTH_KEY` (optional): For automated Tailscale setup
- `BOT_USER` (optional): Non-root user name (default: moltbot)

### Post-Installation

1. **Verify Installation**:
   ```bash
   sudo bash verify_installation.sh
   ```

2. **Run Doctor Check**:
   ```bash
   # Included in install script, or run manually:
   sudo systemctl status moltbot
   sudo docker ps
   sudo ufw status
   ```

3. **Configure Channels**:
   Edit `/etc/moltbot/config.yml` to add your channel IDs to the allowlist

4. **Access via Tailscale**:
   ```bash
   tailscale serve https / http://127.0.0.1:8080
   ```

## Access Methods

### Option 1: Tailscale Serve (Recommended)
```bash
tailscale serve https / http://127.0.0.1:8080
```
Access at: `https://your-machine.tailnet-name.ts.net`

### Option 2: SSH Tunnel
```bash
ssh -L 8080:127.0.0.1:8080 user@your-vps
```
Access at: `http://localhost:8080`

### Option 3: Tailscale Funnel (Public, Use with Caution)
```bash
tailscale funnel 8080
```
Only use if you need public access and have strong authentication

## Uninstallation

### Interactive Uninstall
```bash
sudo bash uninstall.sh
```

### Non-Interactive Uninstall
```bash
sudo FORCE_MODE=true bash uninstall.sh
```

### Rollback to Previous State
```bash
sudo bash rollback.sh
```

## Verification Checklist

Before deploying to production, verify:

- [ ] All scripts are executable (`chmod +x *.sh`)
- [ ] `BOT_PASSWORD` is strong and unique
- [ ] `config.template` has correct placeholders
- [ ] `docker-compose.yml` has no public ports
- [ ] UFW rules allow only SSH and Tailscale
- [ ] Fail2ban is configured for SSH
- [ ] Unattended upgrades are enabled
- [ ] Log rotation is configured
- [ ] Doctor check passes all tests
- [ ] Backup/rollback procedures tested

## Doctor Check Output

The installation script includes a `doctor_check()` function that validates:

```
✓ UFW firewall is active
✓ SSH (22) and Tailscale (41641) ports configured
✓ Fail2ban service is running
✓ Unattended security updates enabled
✓ Docker is installed
✓ Tailscale is installed
✓ Bot user 'moltbot' exists
✓ Moltbot/Clawdbot containers are running
```

## Backup Locations

All backups stored in: `/var/backups/moltbot/`

- **Uninstall backups**: `uninstall_backup_YYYYMMDD_HHMMSS/`
- **Pre-rollback backups**: `pre_rollback_YYYYMMDD_HHMMSS/`

Each backup contains:
- Configuration files
- Installation scripts
- Log files
- Docker volume data (compressed)

## Troubleshooting

### Installation Fails
1. Check system requirements (Ubuntu 22.04)
2. Verify internet connectivity
3. Ensure BOT_PASSWORD is set
4. Review logs: `journalctl -xe`

### Containers Won't Start
1. Check Docker status: `systemctl status docker`
2. View container logs: `docker logs moltbot`
3. Verify config file: `cat /etc/moltbot/config.yml`

### Can't Access Bot
1. Verify Tailscale is connected: `tailscale status`
2. Check firewall rules: `sudo ufw status`
3. Confirm containers are running: `docker ps`
4. Test local access: `curl http://127.0.0.1:8080`

### Doctor Check Warnings
Run the doctor check and address each warning:
```bash
# Re-run installation (idempotent)
sudo BOT_PASSWORD="your-password" bash install_and_harden.sh
```

## Security Considerations

### ⚠️ Important Security Notes

1. **Never commit secrets**: All passwords and keys must be in environment variables
2. **Use strong passwords**: Minimum 16 characters, mixed case, numbers, symbols
3. **Rotate credentials**: Change passwords regularly
4. **Monitor logs**: Check `/var/log/moltbot/` for suspicious activity
5. **Keep updated**: Run `apt update && apt upgrade` regularly
6. **Backup regularly**: Automated backups before changes, manual backups weekly
7. **Test rollback**: Verify rollback procedure works before production use
8. **Limit access**: Use Tailscale ACLs to restrict who can access the bot
9. **Review allowlists**: Regularly audit channel and user allowlists
10. **Monitor Fail2ban**: Check banned IPs: `sudo fail2ban-client status sshd`

### Default Security Posture

- **Firewall**: Deny all incoming except SSH and Tailscale
- **Authentication**: Password-based (not open)
- **Channels**: Allowlist only (not open)
- **DMs**: Pairing required (not open)
- **Network**: Internal only (no public ports)
- **Updates**: Automatic security patches
- **Logging**: All activity logged and rotated

## File Permissions

Correct permissions are automatically set:

```
/opt/moltbot/                     - 750 moltbot:moltbot
/opt/moltbot/docker-compose.yml   - 640 moltbot:moltbot
/etc/moltbot/                     - 750 root:root
/etc/moltbot/config.yml           - 600 moltbot:moltbot
/var/log/moltbot/                 - 755 moltbot:moltbot
```

## Testing Recommendations

Before production deployment:

1. **Test in staging**: Deploy to a test VPS first
2. **Verify idempotency**: Run install script twice, check for errors
3. **Test uninstall**: Uninstall and verify complete removal
4. **Test rollback**: Create backup, make changes, rollback
5. **Test firewall**: Verify only SSH and Tailscale ports are open
6. **Test Fail2ban**: Attempt failed SSH logins, verify banning
7. **Test access**: Verify bot is NOT accessible publicly
8. **Test Tailscale**: Verify access via Tailscale works
9. **Test doctor check**: Ensure all checks pass
10. **Load test**: Verify bot handles expected traffic

## Support and Maintenance

### Regular Maintenance Tasks

- **Weekly**: Review logs for errors or suspicious activity
- **Monthly**: Update system packages, rotate credentials
- **Quarterly**: Test backup/rollback procedures
- **Annually**: Security audit, review access controls

### Monitoring Commands

```bash
# Check service status
sudo systemctl status moltbot

# View container logs
sudo docker logs -f moltbot

# Check firewall status
sudo ufw status verbose

# Check Fail2ban status
sudo fail2ban-client status sshd

# View recent security updates
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log

# Check disk usage
df -h /var/log/moltbot
```

## License and Disclaimer

This installation package is provided as-is. Always review scripts before running with root privileges. Test in a non-production environment first.

---

**Package Version**: 1.0.0  
**Last Updated**: January 30, 2026  
**Tested On**: Ubuntu 22.04 LTS  
**Minimum Requirements**: 1GB RAM, 10GB disk, Ubuntu 22.04+