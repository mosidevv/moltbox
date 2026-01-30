# Changelog

## [2026-01-30] - Docker Build Fix

### Fixed
- **Docker image pull error**: Fixed "ERROR: Head 'https://ghcr.io/v2/anthropics/moltbot/manifests/latest': denied" error at Step 14

### Root Cause
Moltbot does not publish pre-built Docker images to any container registry. The official installation method requires building from source.

### Changes

#### Modified Files

1. **install_and_harden.sh**
   - Added `git` to `REQUIRED_PACKAGES` array
   - Rewrote Step 14 to clone Moltbot repository and build Docker image locally
   - Updated docker-compose.yml generation to use `moltbot:local` instead of `ghcr.io/anthropics/moltbot:latest`
   - Removed `ExecStartPre` docker-compose pull from systemd service definition
   - Increased service startup wait time from 5 to 10 seconds
   - Added repository cloning to `/opt/moltbot/moltbot-repo`
   - Added Docker image build command: `docker build -t moltbot:local -f Dockerfile .`
   - Added optional sandbox image builds

2. **docker-compose.yml**
   - Changed `image:` from `ghcr.io/anthropics/moltbot:latest` to `moltbot:local`

3. **README.md**
   - Added note about building from source in Prerequisites section
   - Added resource requirements (2GB RAM, 10GB disk space)
   - Added note about 5-10 minute build time
   - Updated "Docker Commands" section with rebuild instructions
   - Changed "Pull latest image" to "Update to latest version (rebuild from source)"

4. **DEPLOYMENT_SUMMARY.md**
   - Added resource requirements to Prerequisites
   - Added note about building from source
   - Added build time expectations

#### New Files

1. **DOCKER_BUILD_FIX.md**
   - Comprehensive documentation of the fix
   - Detailed explanation of root cause
   - Step-by-step changes made
   - Troubleshooting guide
   - Verification steps

2. **QUICK_FIX_SUMMARY.md**
   - Quick reference guide for the fix
   - What changed summary
   - Verification commands
   - Update instructions
   - Troubleshooting tips

3. **CHANGELOG.md** (this file)
   - Version history and changes

### Installation Flow (Updated)

```
Step 1:  System updates & security patches
Step 2:  Install required packages (docker, ufw, fail2ban, git, etc.)
Step 3:  Create non-root moltbot user
Step 4:  Configure UFW firewall
Step 5:  Configure Fail2ban for SSH protection
Step 6:  Install and configure Docker
Step 7:  Configure unattended security updates
Step 8:  Configure log rotation
Step 9:  Install Tailscale
Step 10: Create Moltbot configuration
Step 11: Create docker-compose.yml (with moltbot:local)
Step 12: Create systemd service
Step 13: Create helper scripts (doctor check)
Step 14: Clone Moltbot repository and build Docker image ← CHANGED
Step 15: Start Moltbot service
Step 16: Run final security checks
Step 17: Display access instructions
```

### Build Process

The installation now performs these additional steps:

1. **Clone Repository**
   ```bash
   git clone https://github.com/moltbot/moltbot.git /opt/moltbot/moltbot-repo
   ```

2. **Build Docker Image**
   ```bash
   cd /opt/moltbot/moltbot-repo
   docker build -t moltbot:local -f Dockerfile .
   ```

3. **Build Sandbox Images** (optional)
   ```bash
   bash scripts/sandbox-setup.sh
   ```

### Performance Impact

- **First installation**: +5-10 minutes (for git clone and Docker build)
- **Disk space**: +500MB-1GB (for repository and built image)
- **Memory**: Requires at least 2GB RAM during build

### Updating Moltbot

To update to the latest version:

```bash
cd /opt/moltbot/moltbot-repo
sudo -u moltbot git pull
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .
sudo systemctl restart moltbot
```

### Verification

After installation, verify the fix:

```bash
# Check image is built locally
docker images | grep moltbot
# Expected: moltbot  local  ...

# Check container is running
docker ps | grep moltbot
# Expected: moltbot:local

# Run health check
sudo -u moltbot /opt/moltbot/moltbot-doctor.sh
```

### Backward Compatibility

- ✅ All existing configuration files remain compatible
- ✅ Uninstall and rollback scripts work without changes
- ✅ Environment variables unchanged
- ✅ Access methods (Tailscale, SSH tunnel) unchanged

### Testing

Tested on:
- Ubuntu 22.04 LTS (fresh installation)
- Docker version 24.0+
- Docker Compose version 1.29+

### References

- Official Moltbot Repository: https://github.com/moltbot/moltbot
- Official Docker Documentation: https://docs.molt.bot/install/docker
- Moltbot Website: https://molt.bot

### Contributors

- Fix implemented: 2026-01-30
- Issue: Docker image pull denied error
- Solution: Build from source instead of pulling pre-built image

---

## Previous Versions

### [Initial Release] - 2026-01-30

Initial release of secure Moltbot/Clawdbot installation package with:
- Idempotent installation script
- Docker-based deployment
- UFW firewall configuration
- Fail2ban SSH protection
- Tailscale integration
- Unattended security updates
- Log rotation
- Uninstall and rollback capabilities
- Doctor health check script
