#!/bin/bash
set -euo pipefail

#############################################################################
# Moltbot/Clawdbot Installation Verification Script
# 
# This script verifies that all installation files are present and valid
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "========================================="
echo "Moltbot/Clawdbot Installation Verification"
echo "========================================="
echo ""

#############################################################################
# Check Required Files
#############################################################################

log_info "Checking required files..."
echo ""

# Installation script
if [[ -f "install_and_harden.sh" ]] && [[ -x "install_and_harden.sh" ]]; then
    log_pass "install_and_harden.sh exists and is executable"
else
    log_fail "install_and_harden.sh missing or not executable"
fi

# Uninstall script
if [[ -f "uninstall.sh" ]] && [[ -x "uninstall.sh" ]]; then
    log_pass "uninstall.sh exists and is executable"
else
    log_fail "uninstall.sh missing or not executable"
fi

# Rollback script
if [[ -f "rollback.sh" ]] && [[ -x "rollback.sh" ]]; then
    log_pass "rollback.sh exists and is executable"
else
    log_fail "rollback.sh missing or not executable"
fi

# Docker Compose file
if [[ -f "docker-compose.yml" ]]; then
    log_pass "docker-compose.yml exists"
else
    log_fail "docker-compose.yml missing"
fi

# Config template
if [[ -f "config.template" ]]; then
    log_pass "config.template exists"
else
    log_fail "config.template missing"
fi

# README
if [[ -f "README.md" ]]; then
    log_pass "README.md exists"
else
    log_fail "README.md missing"
fi

# UNINSTALL guide
if [[ -f "UNINSTALL.md" ]]; then
    log_pass "UNINSTALL.md exists"
else
    log_fail "UNINSTALL.md missing"
fi

echo ""

#############################################################################
# Validate Script Content
#############################################################################

log_info "Validating script content..."
echo ""

# Check install script has required functions
if grep -q "doctor_check()" install_and_harden.sh; then
    log_pass "install_and_harden.sh contains doctor_check function"
else
    log_fail "install_and_harden.sh missing doctor_check function"
fi

if grep -q "configure_ufw()" install_and_harden.sh; then
    log_pass "install_and_harden.sh contains UFW configuration"
else
    log_fail "install_and_harden.sh missing UFW configuration"
fi

if grep -q "configure_fail2ban()" install_and_harden.sh; then
    log_pass "install_and_harden.sh contains Fail2ban configuration"
else
    log_fail "install_and_harden.sh missing Fail2ban configuration"
fi

if grep -q "install_tailscale()" install_and_harden.sh; then
    log_pass "install_and_harden.sh contains Tailscale installation"
else
    log_fail "install_and_harden.sh missing Tailscale installation"
fi

# Check uninstall script has backup functionality
if grep -q "BACKUP_PATH\|backup" uninstall.sh; then
    log_pass "uninstall.sh contains backup functionality"
else
    log_warn "uninstall.sh may be missing backup functionality"
fi

if grep -q "docker.*down\|docker.*rm" uninstall.sh; then
    log_pass "uninstall.sh contains container cleanup"
else
    log_fail "uninstall.sh missing container cleanup"
fi

echo ""

#############################################################################
# Validate Docker Compose Configuration
#############################################################################

log_info "Validating Docker Compose configuration..."
echo ""

# Check for internal network
if grep -q "internal: true" docker-compose.yml; then
    log_pass "Docker network is configured as internal"
else
    log_warn "Docker network may not be internal"
fi

# Check for no public ports
if grep -q "ports: \[\]" docker-compose.yml; then
    log_pass "No public ports exposed"
else
    log_warn "Public ports may be exposed"
fi

# Check for logging configuration
if grep -q "logging:" docker-compose.yml; then
    log_pass "Logging is configured"
else
    log_warn "Logging configuration missing"
fi

echo ""

#############################################################################
# Validate Config Template
#############################################################################

log_info "Validating config template..."
echo ""

# Check for password placeholder
if grep -q "PASSWORD_PLACEHOLDER" config.template; then
    log_pass "Config template has password placeholder"
else
    log_fail "Config template missing password placeholder"
fi

# Check for security settings
if grep -q "tailnet_only: true" config.template; then
    log_pass "Config template enforces Tailnet-only access"
else
    log_warn "Config template may allow public access"
fi

# Check for allowlist mode
if grep -q "mode: allowlist" config.template; then
    log_pass "Config template uses allowlist mode"
else
    log_warn "Config template may not use allowlist mode"
fi

# Check for pairing mode
if grep -q "mode: pairing" config.template; then
    log_pass "Config template uses pairing mode for DMs"
else
    log_warn "Config template may allow open DMs"
fi

echo ""

#############################################################################
# Check for Security Best Practices
#############################################################################

log_info "Checking security best practices..."
echo ""

# Check that scripts don't echo passwords
if grep -q "echo.*PASSWORD" install_and_harden.sh; then
    log_warn "install_and_harden.sh may echo passwords"
else
    log_pass "install_and_harden.sh doesn't echo passwords"
fi

# Check for set -euo pipefail
if head -5 install_and_harden.sh | grep -q "set -euo pipefail"; then
    log_pass "install_and_harden.sh uses strict error handling"
else
    log_warn "install_and_harden.sh may not use strict error handling"
fi

if head -5 uninstall.sh | grep -q "set -euo pipefail"; then
    log_pass "uninstall.sh uses strict error handling"
else
    log_warn "uninstall.sh may not use strict error handling"
fi

# Check for idempotency checks
if grep -q "is_package_installed\|is_service_running\|user_exists" install_and_harden.sh; then
    log_pass "install_and_harden.sh has idempotency checks"
else
    log_warn "install_and_harden.sh may not be idempotent"
fi

echo ""

#############################################################################
# Validate Documentation
#############################################################################

log_info "Validating documentation..."
echo ""

# Check README has required sections
if grep -q "One-Line Installation Command" README.md; then
    log_pass "README.md has installation command"
else
    log_fail "README.md missing installation command"
fi

if grep -q "Required Environment Variables" README.md; then
    log_pass "README.md documents required env vars"
else
    log_fail "README.md missing env vars documentation"
fi

if grep -q "BOT_PASSWORD" README.md; then
    log_pass "README.md documents BOT_PASSWORD"
else
    log_fail "README.md missing BOT_PASSWORD documentation"
fi

# Check UNINSTALL.md has required sections
if grep -q "Rollback from Backup" UNINSTALL.md; then
    log_pass "UNINSTALL.md has rollback instructions"
else
    log_fail "UNINSTALL.md missing rollback instructions"
fi

if grep -q "Manual Cleanup" UNINSTALL.md; then
    log_pass "UNINSTALL.md has manual cleanup instructions"
else
    log_fail "UNINSTALL.md missing manual cleanup instructions"
fi

echo ""

#############################################################################
# Summary
#############################################################################

echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Installation package is ready for deployment."
    echo ""
    echo "Next steps:"
    echo "  1. Review the README.md for usage instructions"
    echo "  2. Set required environment variables (BOT_PASSWORD)"
    echo "  3. Run: sudo bash install_and_harden.sh"
    exit 0
else
    echo -e "${RED}✗ Some critical checks failed!${NC}"
    echo ""
    echo "Please fix the issues above before deployment."
    exit 1
fi