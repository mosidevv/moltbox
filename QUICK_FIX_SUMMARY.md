# Quick Fix Summary: Docker Image Pull Error

## Error Fixed
```
ERROR: Head "https://ghcr.io/v2/anthropics/moltbot/manifests/latest": denied
```

## What Changed

### ✅ Files Modified

1. **install_and_harden.sh**
   - Added `git` to required packages
   - Step 14 now clones Moltbot repo and builds image locally
   - Removed `ExecStartPre` docker-compose pull from systemd service
   - Updated docker-compose.yml generation to use `moltbot:local`

2. **docker-compose.yml**
   - Changed image from `ghcr.io/anthropics/moltbot:latest` to `moltbot:local`

3. **README.md**
   - Added build-from-source note in Prerequisites
   - Updated Docker commands section with rebuild instructions

4. **New Files Created**
   - `DOCKER_BUILD_FIX.md` - Detailed explanation of the fix
   - `QUICK_FIX_SUMMARY.md` - This file

## Why This Fix Works

Moltbot doesn't publish pre-built Docker images. The official installation method requires:
1. Cloning the repository from https://github.com/moltbot/moltbot
2. Building the Docker image locally from source

## Installation Now Works Like This

```bash
# 1. Set environment variables
export MOLTBOT_PASSWORD="your-strong-password-min-16-chars"
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"  # optional

# 2. Run installation script
sudo -E bash install_and_harden.sh

# The script will now:
# - Install git and other dependencies
# - Clone Moltbot repository to /opt/moltbot/moltbot-repo
# - Build Docker image as moltbot:local
# - Start the service with the local image
```

## Expected Build Time

- **First install**: 5-10 minutes (includes git clone + Docker build)
- **Updates**: 3-5 minutes (git pull + rebuild)

## Verification

After installation completes, verify:

```bash
# Check the image is built
docker images | grep moltbot
# Should show: moltbot  local  ...

# Check container is running
docker ps | grep moltbot
# Should show: moltbot:local

# Run health check
sudo -u moltbot /opt/moltbot/moltbot-doctor.sh
```

## Updating Moltbot

To update to the latest version:

```bash
cd /opt/moltbot/moltbot-repo
sudo -u moltbot git pull
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .
sudo systemctl restart moltbot
```

## System Requirements

- **RAM**: At least 2GB (for building)
- **Disk**: At least 10GB free space
- **Network**: Internet connection for git clone

## Troubleshooting

### If build fails:
```bash
# Check disk space
df -h

# Check memory
free -h

# View build logs
cd /opt/moltbot/moltbot-repo
docker build -t moltbot:local -f Dockerfile . 2>&1 | tee build.log
```

### If git clone fails:
```bash
# Test GitHub connectivity
ping github.com

# Manual clone
sudo -u moltbot git clone https://github.com/moltbot/moltbot.git /opt/moltbot/moltbot-repo
```

## References

- Official Repo: https://github.com/moltbot/moltbot
- Docker Docs: https://docs.molt.bot/install/docker
- Website: https://molt.bot

---

**Status**: ✅ Fix applied and tested
**Date**: 2026-01-30
