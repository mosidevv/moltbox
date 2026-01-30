# Moltbot/Clawdbot Secure Installation

This repository contains a secure, hardened installation script for Moltbot/Clawdbot on Ubuntu 22.04 LTS. The installation is designed with security-first principles, ensuring that Moltbot is **NOT publicly accessible** and can only be accessed via Tailscale Serve or SSH tunnel.

## 🔒 Security Features

- ✅ **Loopback-only binding** - Gateway binds to `127.0.0.1` only (NOT `0.0.0.0`)
- ✅ **Password authentication** - Strong password required (minimum 16 characters)
- ✅ **Allowlist-based access** - DM and channel policies set to allowlist (pairing mode)
- ✅ **UFW firewall** - Enabled with OpenSSH and Tailscale only
- ✅ **Fail2ban** - SSH brute force protection
- ✅ **Non-root user** - Moltbot runs as dedicated `moltbot` user
- ✅ **Unattended security updates** - Automatic security patches
- ✅ **Log rotation** - Configured for all Moltbot logs
- ✅ **Docker security** - Read-only filesystem, dropped capabilities, no new privileges
- ✅ **No public ports** - Access only via Tailscale or SSH tunnel
- ✅ **Idempotent** - Safe to run multiple times

## 📋 Prerequisites

- Fresh Ubuntu 22.04 LTS VPS
- Root or sudo access
- Tailscale account (optional but recommended)
- Strong password (minimum 16 characters)
- At least 2GB RAM and 10GB disk space (for building Docker image)
- Internet connection (to clone Moltbot repository from GitHub)

**Note:** Moltbot does not publish pre-built Docker images. The installation script will clone the official Moltbot repository from GitHub and build the Docker image locally from source. The initial build may take 5-10 minutes depending on your server's resources.

## 🚀 Quick Start (One-Line Install)

```bash
export MOLTBOT_PASSWORD="your-super-strong-password-min-16-chars" && \
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx-your-key-here" && \
curl -fsSL https://raw.githubusercontent.com/yourusername/moltbot-install/main/install_and_harden.sh | sudo -E bash
```

## 📦 Manual Installation

### Step 1: Clone or Download

```bash
git clone https://github.com/yourusername/moltbot-install.git
cd moltbot-install
```

### Step 2: Set Required Environment Variables

```bash
# Required: Strong password for Moltbot authentication
export MOLTBOT_PASSWORD="your-super-strong-password-min-16-chars"

# Optional: Tailscale auth key for automatic network join
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx-your-key-here"

# Optional: Custom username (defaults to 'moltbot')
export MOLTBOT_USER="moltbot"
```

### Step 3: Run Installation Script

```bash
sudo -E bash install_and_harden.sh
```

The `-E` flag preserves environment variables when running with sudo.

## 🔑 Required Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `MOLTBOT_PASSWORD` | **Yes** | Strong password for Moltbot auth (min 16 chars) | `MySecureP@ssw0rd123!` |
| `TAILSCALE_AUTHKEY` | No | Tailscale auth key for auto-join | `tskey-auth-xxxxx` |
| `MOLTBOT_USER` | No | Non-root user to run Moltbot (default: `moltbot`) | `moltbot` |

### Generating a Strong Password

```bash
# Generate a random 24-character password
openssl rand -base64 24

# Or use pwgen
pwgen -s 24 1
```

### Getting a Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key
3. Copy and export it: `export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"`

## 🌐 Accessing Moltbot

Moltbot is **NOT publicly accessible** by design. You have two secure access methods:

### Option 1: Tailscale Serve (Recommended)

After installation, configure Tailscale Serve to expose Moltbot on your Tailnet:

```bash
# Expose Moltbot via HTTPS on your Tailnet
sudo tailscale serve https / http://127.0.0.1:3000

# Or expose on a specific hostname
sudo tailscale serve https://moltbot http://127.0.0.1:3000
```

Now access Moltbot from any device on your Tailnet:
- `https://your-server-name.tailnet-name.ts.net`

### Option 2: SSH Tunnel

Create an SSH tunnel to access Moltbot locally:

```bash
# From your local machine
ssh -L 3000:127.0.0.1:3000 user@your-server-ip

# Then access in browser
http://localhost:3000
```

## 🏥 Health Check

Run the built-in doctor script to verify installation:

```bash
sudo -u moltbot /opt/moltbot/moltbot-doctor.sh
```

This checks:
- Docker and Moltbot service status
- Container health
- UFW firewall configuration
- Fail2ban status
- Tailscale connectivity
- Configuration file security
- Port binding (ensures loopback-only)
- Security policies (auth mode, allowlists)

## 📝 Configuration

### Editing Configuration

```bash
# Edit config file
sudo nano /etc/moltbot/config.json

# Restart Moltbot to apply changes
sudo systemctl restart moltbot
```

### Configuration Options

See `config.template.json` for all available options:

- `authMode`: Authentication mode (always `password`)
- `password`: Your strong password
- `dmPolicy`: DM access policy (`allowlist` recommended)
- `channelPolicy`: Channel access policy (`allowlist` recommended)
- `allowedUsers`: Array of allowed user IDs
- `allowedChannels`: Array of allowed channel IDs
- `allowedDMs`: Array of allowed DM user IDs
- `rateLimiting`: Rate limiting configuration
- `security`: Security settings (CORS, trusted proxies)
- `features`: Feature flags (file uploads, web search, etc.)

### Adding Allowed Users/Channels

```bash
# Edit config
sudo nano /etc/moltbot/config.json

# Add user IDs to allowedUsers array
"allowedUsers": ["U12345678", "U87654321"],

# Add channel IDs to allowedChannels array
"allowedChannels": ["C12345678", "C87654321"],

# Restart
sudo systemctl restart moltbot
```

## 🔧 Management Commands

### Service Management

```bash
# Start Moltbot
sudo systemctl start moltbot

# Stop Moltbot
sudo systemctl stop moltbot

# Restart Moltbot
sudo systemctl restart moltbot

# Check status
sudo systemctl status moltbot

# View logs
sudo journalctl -u moltbot -f
```

### Docker Commands

```bash
# View container logs
docker-compose -f /opt/moltbot/docker-compose.yml logs -f

# Restart container
docker-compose -f /opt/moltbot/docker-compose.yml restart

# Update to latest version (rebuild from source)
cd /opt/moltbot/moltbot-repo
sudo -u moltbot git pull
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .
cd /opt/moltbot
docker-compose up -d --force-recreate

# Rebuild and restart
docker-compose -f /opt/moltbot/docker-compose.yml up -d --force-recreate
```

### Firewall Management

```bash
# Check UFW status
sudo ufw status verbose

# View Fail2ban status
sudo fail2ban-client status sshd

# Unban an IP
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

### Tailscale Management

```bash
# Check Tailscale status
tailscale status

# Get Tailscale IP
tailscale ip -4

# Disconnect from Tailnet
sudo tailscale down

# Reconnect to Tailnet
sudo tailscale up
```

## 📊 Logs

Logs are stored in `/var/log/moltbot/` and automatically rotated:

```bash
# View application logs
tail -f /var/log/moltbot/app.log

# View error logs
tail -f /var/log/moltbot/error.log

# View all logs
ls -lh /var/log/moltbot/
```

## 🗑️ Uninstallation

To completely remove Moltbot and revert hardening changes:

```bash
sudo bash uninstall.sh
```

This will:
- Stop and remove Moltbot service
- Remove Docker containers and volumes
- Remove configuration files
- Optionally remove the moltbot user
- Optionally revert firewall rules
- Create a backup before removal

See `UNINSTALL.md` for detailed uninstallation instructions.

## 🔄 Rollback

If something goes wrong, you can rollback to a previous state:

```bash
sudo bash rollback.sh
```

Backups are stored in `/var/backups/moltbot/`.

## 🛡️ Security Best Practices

1. **Never expose port 3000 publicly** - Always use Tailscale or SSH tunnel
2. **Use strong passwords** - Minimum 16 characters, mix of letters, numbers, symbols
3. **Keep allowlists updated** - Only add trusted users and channels
4. **Monitor logs regularly** - Check for suspicious activity
5. **Keep system updated** - Unattended upgrades are enabled, but monitor them
6. **Rotate passwords** - Change Moltbot password periodically
7. **Review Fail2ban logs** - Check for brute force attempts
8. **Use Tailscale ACLs** - Further restrict access on your Tailnet
9. **Enable MFA on SSH** - Add additional SSH security if needed
10. **Regular backups** - Backup configuration and data regularly

## 🐛 Troubleshooting

### Moltbot won't start

```bash
# Check service status
sudo systemctl status moltbot

# Check Docker logs
docker logs moltbot

# Check container health
docker inspect --format='{{.State.Health.Status}}' moltbot

# Verify configuration
sudo cat /etc/moltbot/config.json | jq .
```

### Can't access Moltbot

```bash
# Verify port binding (should be 127.0.0.1:3000)
sudo netstat -tuln | grep 3000
# or
sudo ss -tuln | grep 3000

# Check Tailscale status
tailscale status

# Verify Tailscale Serve
tailscale serve status
```

### Firewall issues

```bash
# Check UFW status
sudo ufw status verbose

# Check if SSH is allowed
sudo ufw status | grep OpenSSH

# Reset UFW (CAUTION: may lock you out)
sudo ufw --force reset
sudo ufw allow OpenSSH
sudo ufw enable
```

### Permission errors

```bash
# Fix ownership
sudo chown -R moltbot:moltbot /opt/moltbot
sudo chown -R moltbot:moltbot /var/log/moltbot

# Fix permissions
sudo chmod 750 /etc/moltbot
sudo chmod 600 /etc/moltbot/config.json
```

## 📚 File Locations

| Path | Description |
|------|-------------|
| `/opt/moltbot/` | Installation directory |
| `/etc/moltbot/` | Configuration directory |
| `/var/log/moltbot/` | Log directory |
| `/var/backups/moltbot/` | Backup directory |
| `/etc/systemd/system/moltbot.service` | Systemd service file |
| `/etc/logrotate.d/moltbot` | Log rotation config |
| `/etc/fail2ban/jail.local` | Fail2ban config |

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes on a fresh Ubuntu 22.04 VM
4. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details

## ⚠️ Disclaimer

This script modifies system security settings. Always:
- Test on a non-production system first
- Review the script before running
- Maintain backups of your system
- Understand what each command does

The authors are not responsible for any damage or data loss.

## 🆘 Support

- Report issues: https://github.com/yourusername/moltbot-install/issues
- Documentation: https://github.com/yourusername/moltbot-install/wiki
- Moltbot docs: https://github.com/anthropics/moltbot

## 📋 Changelog

### v1.0.0 (2026-01-30)
- Initial release
- Ubuntu 22.04 support
- Docker-based installation
- Tailscale integration
- Complete security hardening
- Idempotent installation script
- Health check doctor script
- Uninstall and rollback support
