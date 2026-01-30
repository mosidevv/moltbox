# Testing the Docker Build Fix

## Pre-Test Verification

Before running the installation, verify these changes are in place:

### 1. Check docker-compose.yml
```bash
grep "image:" docker-compose.yml
# Expected output: image: moltbot:local
```

### 2. Check install script has git
```bash
grep '"git"' install_and_harden.sh
# Expected output: "git"
```

### 3. Check install script has git clone
```bash
grep "git clone" install_and_harden.sh
# Expected output: sudo -u "$MOLTBOT_USER" git clone https://github.com/moltbot/moltbot.git "$MOLTBOT_REPO_DIR"
```

### 4. Check install script has docker build
```bash
grep "docker build" install_and_harden.sh
# Expected output: sudo -u "$MOLTBOT_USER" docker build -t moltbot:local -f Dockerfile .
```

### 5. Check systemd service has no pull
```bash
grep "ExecStartPre.*pull" install_and_harden.sh
# Expected output: (empty - no matches)
```

## Test Installation (Dry Run)

To test without actually installing on a production server:

### Option 1: Test in a VM or Container

```bash
# Launch Ubuntu 22.04 container/VM
docker run -it --privileged ubuntu:22.04 bash

# Inside container:
apt-get update && apt-get install -y git sudo

# Clone your repository
git clone <your-repo-url>
cd <repo-directory>

# Set environment variables
export MOLTBOT_PASSWORD="TestPassword123456789"
export MOLTBOT_USER="moltbot"

# Run installation (will take 5-10 minutes)
bash install_and_harden.sh
```

### Option 2: Test Script Syntax

```bash
# Check for syntax errors
bash -n install_and_harden.sh
# Expected: (no output = no errors)

# Check for common issues
shellcheck install_and_harden.sh
# (if shellcheck is installed)
```

## Expected Installation Flow

When you run the fixed installation script, you should see:

```
[INFO] Starting Moltbot/Clawdbot secure installation...
[INFO] Installation directory: /opt/moltbot
[INFO] Running as user: moltbot

[INFO] Step 1: Updating system packages...
[INFO] Step 2: Installing required packages...
  - Installing: docker.io docker-compose ufw fail2ban git ...
[INFO] Step 3: Creating moltbot user...
[INFO] Step 4: Configuring UFW firewall...
[INFO] Step 5: Configuring Fail2ban...
[INFO] Step 6: Installing Docker...
[INFO] Step 7: Configuring unattended security updates...
[INFO] Step 8: Configuring log rotation...
[INFO] Step 9: Installing Tailscale...
[INFO] Step 10: Creating Moltbot configuration...
[INFO] Step 11: Creating Docker Compose configuration...
[INFO] Step 12: Creating systemd service...
[INFO] Step 13: Creating helper scripts...
[INFO] Step 14: Cloning Moltbot repository and building Docker image...
  [INFO] Cloning Moltbot repository from GitHub...
  Cloning into '/opt/moltbot/moltbot-repo'...
  [INFO] Repository cloned successfully
  [INFO] Building Moltbot Docker image (this may take several minutes)...
  Step 1/15 : FROM node:22-bookworm
  Step 2/15 : WORKDIR /app
  ...
  [INFO] Moltbot Docker image built successfully
[INFO] Step 15: Starting Moltbot service...
[INFO] Moltbot service started successfully
[INFO] Step 16: Running final security checks...
[INFO] Installation complete!
```

## Post-Installation Verification

After installation completes, run these checks:

### 1. Verify Docker Image Exists
```bash
docker images | grep moltbot
# Expected output:
# moltbot  local  <image-id>  X minutes ago  XXX MB
```

### 2. Verify Container is Running
```bash
docker ps | grep moltbot
# Expected output:
# <container-id>  moltbot:local  ...  Up X minutes  127.0.0.1:3000->3000/tcp
```

### 3. Verify Repository was Cloned
```bash
ls -la /opt/moltbot/moltbot-repo
# Expected: Directory exists with Moltbot source code
```

### 4. Verify Service is Active
```bash
systemctl status moltbot
# Expected: Active: active (running)
```

### 5. Run Doctor Check
```bash
sudo -u moltbot /opt/moltbot/moltbot-doctor.sh
# Expected: All checks should pass
```

### 6. Verify No Public Port Exposure
```bash
netstat -tuln | grep 3000
# Expected: tcp  0  0  127.0.0.1:3000  0.0.0.0:*  LISTEN
# (Note: 127.0.0.1, NOT 0.0.0.0)
```

### 7. Check Docker Compose Configuration
```bash
cat /opt/moltbot/docker-compose.yml | grep image
# Expected: image: moltbot:local
```

## Troubleshooting Test Failures

### If git clone fails:
```bash
# Test GitHub connectivity
ping -c 3 github.com

# Test DNS resolution
nslookup github.com

# Manual clone test
git clone https://github.com/moltbot/moltbot.git /tmp/test-clone
```

### If Docker build fails:
```bash
# Check disk space
df -h
# Need at least 10GB free

# Check memory
free -h
# Need at least 2GB RAM

# Try manual build
cd /opt/moltbot/moltbot-repo
docker build -t moltbot:local -f Dockerfile . 2>&1 | tee /tmp/build.log
```

### If service won't start:
```bash
# Check Docker logs
docker-compose -f /opt/moltbot/docker-compose.yml logs

# Check systemd logs
journalctl -u moltbot -n 50

# Check if image exists
docker images | grep moltbot
```

## Performance Benchmarks

Expected timings on a typical VPS (2 vCPU, 4GB RAM):

| Step | Time | Notes |
|------|------|-------|
| System updates | 1-2 min | Depends on package count |
| Package installation | 2-3 min | Includes Docker |
| Git clone | 30-60 sec | Depends on network speed |
| Docker build | 5-8 min | First build, no cache |
| Service start | 10-20 sec | Container initialization |
| **Total** | **10-15 min** | First-time installation |

## Success Criteria

The fix is successful if:

- ✅ No "denied" error when pulling Docker image
- ✅ Moltbot repository cloned to `/opt/moltbot/moltbot-repo`
- ✅ Docker image `moltbot:local` exists
- ✅ Container running with `moltbot:local` image
- ✅ Service active and healthy
- ✅ Port 3000 bound to 127.0.0.1 only
- ✅ Doctor check passes all tests
- ✅ No public port exposure

## Rollback Test

Test the rollback functionality:

```bash
# Create a test backup
sudo bash rollback.sh

# Verify backup was created
ls -la /var/backups/moltbot/
```

## Update Test

Test updating Moltbot:

```bash
# Navigate to repository
cd /opt/moltbot/moltbot-repo

# Pull latest changes
sudo -u moltbot git pull

# Rebuild image
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .

# Restart service
sudo systemctl restart moltbot

# Verify
docker ps | grep moltbot
```

## Clean Test Environment

To clean up after testing:

```bash
# Run uninstall script
sudo bash uninstall.sh

# Verify cleanup
docker ps -a | grep moltbot  # Should be empty
docker images | grep moltbot  # Should be empty
systemctl status moltbot  # Should be inactive/not found
```

---

**Test Status**: Ready for testing
**Last Updated**: 2026-01-30
