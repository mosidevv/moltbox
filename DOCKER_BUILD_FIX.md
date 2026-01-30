# Docker Image Build Fix

## Problem

The installation script was attempting to pull a pre-built Moltbot Docker image from `ghcr.io/anthropics/moltbot:latest`, which resulted in the following error:

```
ERROR: Head "https://ghcr.io/v2/anthropics/moltbot/manifests/latest": denied
```

## Root Cause

Moltbot (formerly Clawdbot) **does not publish pre-built Docker images** to any container registry (ghcr.io, docker.io, etc.). According to the official documentation at https://docs.molt.bot/install/docker, users must:

1. Clone the Moltbot repository from GitHub
2. Build the Docker image locally from source

## Solution

The installation script has been updated to:

### 1. Clone the Moltbot Repository

The script now clones the official repository from `https://github.com/moltbot/moltbot.git` into `/opt/moltbot/moltbot-repo`.

### 2. Build Docker Image Locally

The script builds the Docker image from source using:
```bash
docker build -t moltbot:local -f Dockerfile .
```

### 3. Use Local Image

The `docker-compose.yml` file now references `moltbot:local` instead of `ghcr.io/anthropics/moltbot:latest`.

## Changes Made

### File: `install_and_harden.sh`

1. **Added `git` to required packages** (line ~95)
   - Required for cloning the repository

2. **Updated Step 14** (line ~620)
   - Changed from "Pull Docker image" to "Clone repository and build image"
   - Added repository cloning logic
   - Added Docker image build from source
   - Added optional sandbox image builds
   - Increased startup wait time to 10 seconds (build takes longer)

3. **Updated docker-compose.yml generation** (line ~330)
   - Changed image from `ghcr.io/anthropics/moltbot:latest` to `moltbot:local`

4. **Updated systemd service** (line ~400)
   - Removed `ExecStartPre` that attempted to pull the image
   - Service now only starts containers (no pull)

### File: `docker-compose.yml`

1. **Updated image reference**
   - Changed from `ghcr.io/anthropics/moltbot:latest` to `moltbot:local`

### File: `README.md`

1. **Updated Prerequisites section**
   - Added note about building from source
   - Added resource requirements (2GB RAM, 10GB disk)
   - Added note about 5-10 minute build time

2. **Updated Docker Commands section**
   - Changed "Pull latest image" to "Update to latest version (rebuild from source)"
   - Added instructions for updating: git pull + rebuild

## Installation Flow

The updated installation process now follows this flow:

```
1. System updates & package installation (including git)
2. Create moltbot user
3. Configure UFW firewall
4. Configure Fail2ban
5. Install Docker
6. Configure security updates
7. Configure log rotation
8. Install Tailscale
9. Create Moltbot configuration
10. Create docker-compose.yml (with moltbot:local image)
11. Create systemd service
12. Create helper scripts
13. Clone Moltbot repository from GitHub ← NEW
14. Build Docker image from source ← NEW
15. Start Moltbot service
16. Run security checks
17. Display access instructions
```

## Build Time Expectations

- **First installation**: 5-10 minutes (depending on server resources)
- **Subsequent updates**: 3-5 minutes (git pull + rebuild)

## Updating Moltbot

To update to the latest version:

```bash
# Navigate to repository
cd /opt/moltbot/moltbot-repo

# Pull latest changes
sudo -u moltbot git pull

# Rebuild image
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .

# Restart service
sudo systemctl restart moltbot
```

## Verification

After installation, verify the correct image is being used:

```bash
# Check running containers
docker ps

# Should show:
# CONTAINER ID   IMAGE           ...
# xxxxx          moltbot:local   ...

# Check available images
docker images | grep moltbot

# Should show:
# moltbot        local    xxxxx   X minutes ago   XXX MB
```

## Troubleshooting

### Build Fails

If the Docker build fails:

1. Check available disk space: `df -h`
2. Check available memory: `free -h`
3. Review build logs: `docker build -t moltbot:local -f Dockerfile . 2>&1 | tee build.log`
4. Ensure git repository cloned successfully: `ls -la /opt/moltbot/moltbot-repo`

### Repository Clone Fails

If git clone fails:

1. Check internet connectivity: `ping github.com`
2. Check DNS resolution: `nslookup github.com`
3. Manually clone: `git clone https://github.com/moltbot/moltbot.git /opt/moltbot/moltbot-repo`

### Service Won't Start

If the service fails to start after build:

1. Check Docker logs: `docker-compose -f /opt/moltbot/docker-compose.yml logs`
2. Verify image exists: `docker images | grep moltbot`
3. Check systemd status: `systemctl status moltbot`
4. Run doctor script: `/opt/moltbot/moltbot-doctor.sh`

## References

- **Official Moltbot Repository**: https://github.com/moltbot/moltbot
- **Official Docker Documentation**: https://docs.molt.bot/install/docker
- **Moltbot Website**: https://molt.bot

## Summary

The installation script now correctly builds Moltbot from source instead of attempting to pull a non-existent pre-built image. This aligns with Moltbot's official installation method and ensures a successful deployment.
