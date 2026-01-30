# Moltbot/Clawdbot Uninstallation and Rollback Guide

This guide covers how to safely uninstall Moltbot/Clawdbot and restore from backups if needed.

## Table of Contents

1. [Quick Uninstall](#quick-uninstall)
2. [Interactive Uninstall](#interactive-uninstall)
3. [Rollback from Backup](#rollback-from-backup)
4. [Manual Cleanup](#manual-cleanup)
5. [Troubleshooting](#troubleshooting)

---

## Quick Uninstall

For a complete automated uninstallation (non-interactive):

```bash
sudo FORCE_MODE=true bash uninstall.sh
```

This will:
- Create a backup before removal
- Stop and remove all Docker containers
- Remove the bot user and data
- Clean up configuration files
- Reset firewall rules (keeping SSH access)
- Remove log rotation configuration

---

## Interactive Uninstall

For a guided uninstallation with prompts:

```bash
sudo bash uninstall.sh
```

You will be prompted to:
- Confirm uninstallation
- Choose whether to remove installed packages (Docker, Fail2ban, etc.)
- Choose whether to remove Tailscale
- Choose whether to disable UFW firewall
- Choose whether to keep the backup

### What Gets Removed

**Always Removed:**
- Moltbot/Clawdbot Docker containers and volumes
- Bot user (with confirmation)
- Configuration files in `/etc/moltbot` and `/opt/moltbot`
- Log files in `/var/log/moltbot`
- Systemd service files
- Log rotation configuration

**Optionally Removed:**
- Docker and Docker Compose
- Fail2ban and its configuration
- Tailscale
- UFW firewall rules
- Unattended-upgrades configuration

**Never Removed:**
- SSH access (always maintained)
- System packages (unless explicitly chosen)
- Backups (unless explicitly chosen)

---

## Rollback from Backup

If you need to restore Moltbot from a previous backup:

### List Available Backups

```bash
sudo bash rollback.sh
```

This will show all available backups and let you choose which one to restore.

### Restore Specific Backup

```bash
sudo bash rollback.sh /var/backups/moltbot/uninstall_backup_20260130_120000
```

### What Gets Restored

- Configuration files
- Docker Compose setup
- Installation scripts
- Docker volume data
- Optionally: log files

### Rollback Process

1. **Current State Backup**: Before rollback, your current state is backed up to `/var/backups/moltbot/pre_rollback_TIMESTAMP`
2. **Service Stop**: Moltbot service is stopped
3. **Restoration**: Files and volumes are restored from the selected backup
4. **Service Restart**: Moltbot service is restarted
5. **Verification**: System checks that everything is running correctly

---

## Manual Cleanup

If the automated scripts fail, you can manually clean up:

### Stop Services

```bash
sudo systemctl stop moltbot
sudo systemctl disable moltbot
```

### Remove Docker Containers

```bash
# Using docker-compose
cd /opt/moltbot
sudo docker-compose down -v

# Or manually
sudo docker stop moltbot clawdbot
sudo docker rm moltbot clawdbot
sudo docker volume rm moltbot-data
sudo docker network rm moltbot-internal
```

### Remove Files

```bash
sudo rm -rf /opt/moltbot
sudo rm -rf /etc/moltbot
sudo rm -rf /var/log/moltbot
sudo rm /etc/systemd/system/moltbot.service
sudo rm /etc/logrotate.d/moltbot
sudo systemctl daemon-reload
```

### Remove User

```bash
sudo userdel -r moltbot
```

### Reset Firewall (Optional)

```bash
# Remove Tailscale rule
sudo ufw delete allow 41641/udp

# Or completely reset UFW
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable
```

---

## Troubleshooting

### Uninstall Script Fails

**Problem**: Script exits with errors

**Solution**:
1. Check the error message
2. Run with verbose output: `sudo bash -x uninstall.sh`
3. Try manual cleanup (see above)
4. Check if services are running: `systemctl status moltbot`

### Docker Containers Won't Stop

**Problem**: Containers remain running after uninstall

**Solution**:
```bash
# Force stop all moltbot containers
sudo docker ps -a | grep moltbot | awk '{print $1}' | xargs sudo docker rm -f

# Remove all moltbot volumes
sudo docker volume ls | grep moltbot | awk '{print $2}' | xargs sudo docker volume rm
```

### User Can't Be Removed

**Problem**: `userdel` fails with "user is currently used by process"

**Solution**:
```bash
# Kill all processes owned by the user
sudo pkill -u moltbot
sudo killall -u moltbot

# Wait a moment
sleep 2

# Try again
sudo userdel -r moltbot
```

### Backup Restoration Fails

**Problem**: Rollback script can't restore from backup

**Solution**:
1. Verify backup exists: `ls -la /var/backups/moltbot/`
2. Check backup contents: `ls -la /var/backups/moltbot/uninstall_backup_*/`
3. Manually restore files:
   ```bash
   BACKUP_DIR="/var/backups/moltbot/uninstall_backup_TIMESTAMP"
   sudo cp -r "$BACKUP_DIR/config" /etc/moltbot
   sudo cp -r "$BACKUP_DIR/install" /opt/moltbot
   ```

### Firewall Locked Out

**Problem**: Can't access server after firewall changes

**Solution**:
- If you have console access:
  ```bash
  sudo ufw allow OpenSSH
  sudo ufw --force enable
  ```
- If completely locked out, use your VPS provider's console/recovery mode

### Tailscale Won't Disconnect

**Problem**: `tailscale down` fails

**Solution**:
```bash
# Force stop Tailscale
sudo systemctl stop tailscaled
sudo systemctl disable tailscaled

# Remove completely
sudo apt-get remove --purge tailscale
```

---

## Backup Locations

All backups are stored in `/var/backups/moltbot/` with timestamps:

- **Uninstall backups**: `/var/backups/moltbot/uninstall_backup_YYYYMMDD_HHMMSS/`
- **Pre-rollback backups**: `/var/backups/moltbot/pre_rollback_YYYYMMDD_HHMMSS/`

### Backup Contents

Each backup directory contains:
- `config/`: Configuration files
- `logs/`: Log files
- `install/`: Installation files and scripts
- `moltbot-data.tar.gz`: Docker volume data (if exists)

### Managing Backups

```bash
# List all backups
ls -lh /var/backups/moltbot/

# Check backup size
du -sh /var/backups/moltbot/*

# Remove old backups (keep last 5)
cd /var/backups/moltbot
ls -t | tail -n +6 | xargs rm -rf

# Manually create backup
BACKUP_DIR="/var/backups/moltbot/manual_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/moltbot "$BACKUP_DIR/config"
cp -r /opt/moltbot "$BACKUP_DIR/install"
cp -r /var/log/moltbot "$BACKUP_DIR/logs"
```

---

## Verification After Uninstall

To verify complete removal:

```bash
# Check for running containers
docker ps -a | grep moltbot

# Check for volumes
docker volume ls | grep moltbot

# Check for user
id moltbot

# Check for files
ls /opt/moltbot
ls /etc/moltbot
ls /var/log/moltbot

# Check for service
systemctl status moltbot
```

All commands should return "not found" or similar errors.

---

## Re-installation After Uninstall

To reinstall Moltbot after uninstallation:

```bash
# Download and run the install script again
curl -fsSL https://raw.githubusercontent.com/your-repo/install/main/install_and_harden.sh | \
  BOT_PASSWORD="your-strong-password" bash
```

Or restore from a backup using `rollback.sh`.

---

## Support

If you encounter issues not covered in this guide:

1. Check the main README.md for general troubleshooting
2. Review system logs: `journalctl -xe`
3. Check Docker logs: `docker logs moltbot`
4. Review the backup contents before attempting restoration

---

## Safety Notes

- **Always create backups** before uninstalling
- **Keep at least one backup** until you're sure you won't need to restore
- **Test rollback** in a non-production environment first
- **Verify SSH access** is maintained before making firewall changes
- **Document any custom changes** you made to the configuration