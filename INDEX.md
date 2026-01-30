# Moltbot Secure Installation - File Index

## 📚 Documentation Files

### Quick Start
- **README.md** - Main documentation with installation instructions
- **QUICK_FIX_SUMMARY.md** - Quick reference for the Docker build fix

### Installation & Configuration
- **install_and_harden.sh** - Main installation script (executable)
- **docker-compose.yml** - Docker container configuration
- **config.template** - YAML configuration template
- **config.template.json** - JSON configuration template

### Verification & Testing
- **verify_installation.sh** - Pre-deployment verification script (executable)
- **TEST_FIX.md** - Testing procedures for the Docker build fix

### Maintenance & Management
- **uninstall.sh** - Complete uninstallation script (executable)
- **rollback.sh** - Restore from backup script (executable)
- **UNINSTALL.md** - Uninstallation and rollback guide

### Technical Documentation
- **DOCKER_BUILD_FIX.md** - Detailed explanation of the Docker build fix
- **DEPLOYMENT_SUMMARY.md** - Complete deployment checklist and security features
- **CHANGELOG.md** - Version history and changes
- **FIX_SUMMARY.txt** - Quick summary of the fix (text format)

## 🔧 Executable Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `install_and_harden.sh` | Main installation | `sudo -E bash install_and_harden.sh` |
| `verify_installation.sh` | Pre-deployment checks | `bash verify_installation.sh` |
| `uninstall.sh` | Remove Moltbot | `sudo bash uninstall.sh` |
| `rollback.sh` | Restore from backup | `sudo bash rollback.sh` |

## 📖 Reading Order

### For First-Time Installation
1. **README.md** - Understand the project and prerequisites
2. **DEPLOYMENT_SUMMARY.md** - Review security features and checklist
3. **install_and_harden.sh** - Run the installation
4. **verify_installation.sh** - Verify the installation

### For Understanding the Docker Fix
1. **QUICK_FIX_SUMMARY.md** - Quick overview
2. **DOCKER_BUILD_FIX.md** - Detailed explanation
3. **CHANGELOG.md** - What changed and why
4. **TEST_FIX.md** - How to test the fix

### For Troubleshooting
1. **DOCKER_BUILD_FIX.md** - Troubleshooting section
2. **TEST_FIX.md** - Verification and testing
3. **README.md** - Management commands

### For Uninstallation
1. **UNINSTALL.md** - Uninstallation guide
2. **uninstall.sh** - Run the uninstall script
3. **rollback.sh** - Restore if needed

## 📊 File Sizes

```
CHANGELOG.md              5.0K
DEPLOYMENT_SUMMARY.md     9.1K
DOCKER_BUILD_FIX.md       5.0K
FIX_SUMMARY.txt           1.5K
INDEX.md                  (this file)
QUICK_FIX_SUMMARY.md      2.9K
README.md                11.0K
TEST_FIX.md               7.2K
UNINSTALL.md              7.5K
config.template           2.0K
config.template.json      577B
docker-compose.yml        1.2K
install_and_harden.sh    21.0K
rollback.sh               9.1K
uninstall.sh              9.3K
verify_installation.sh    8.7K
```

## 🔍 Quick Reference

### Installation Command
```bash
export MOLTBOT_PASSWORD="your-strong-password-min-16-chars"
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"  # optional
sudo -E bash install_and_harden.sh
```

### Verification Command
```bash
docker images | grep moltbot
# Should show: moltbot  local  ...
```

### Update Command
```bash
cd /opt/moltbot/moltbot-repo
sudo -u moltbot git pull
sudo -u moltbot docker build -t moltbot:local -f Dockerfile .
sudo systemctl restart moltbot
```

### Health Check Command
```bash
sudo -u moltbot /opt/moltbot/moltbot-doctor.sh
```

## 🆘 Support

- **Installation Issues**: See DOCKER_BUILD_FIX.md troubleshooting section
- **Configuration Help**: See README.md configuration section
- **Uninstallation**: See UNINSTALL.md
- **Testing**: See TEST_FIX.md

## 📝 Notes

- All scripts are idempotent (safe to run multiple times)
- Backups are created automatically before uninstall/rollback
- No secrets are committed to git (all from environment variables)
- Installation requires 2GB RAM and 10GB disk space
- Build time: 5-10 minutes on first installation

---

**Last Updated**: 2026-01-30
**Version**: 1.1 (Docker build fix applied)
