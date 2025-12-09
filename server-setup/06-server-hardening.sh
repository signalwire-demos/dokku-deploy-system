#!/bin/bash
#===============================================================================
# 06-server-hardening.sh
# Security hardening for Dokku server
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Server Security Hardening - Step 6/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

#---------------------------------------
# SSH hardening
#---------------------------------------
log_info "Hardening SSH configuration..."

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Disable root login
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
fi
log_success "SSH: Root login disabled"

# Disable password authentication (only if at least one SSH key exists)
if [ -f ~/.ssh/authorized_keys ] && [ -s ~/.ssh/authorized_keys ]; then
    read -p "Disable password authentication? (requires SSH keys) (y/N): " DISABLE_PASS
    if [ "$DISABLE_PASS" == "y" ] || [ "$DISABLE_PASS" == "Y" ]; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        log_success "SSH: Password authentication disabled"
    fi
else
    log_warning "SSH: No SSH keys found, keeping password authentication enabled"
    log_info "Add your SSH key to ~/.ssh/authorized_keys before disabling passwords"
fi

# Disable empty passwords
sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd
log_success "SSH configuration updated"

#---------------------------------------
# Install and configure fail2ban
#---------------------------------------
log_info "Installing fail2ban..."
apt install -y fail2ban

# Create jail.local configuration
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log_success "fail2ban installed and configured"

#---------------------------------------
# Install unattended-upgrades
#---------------------------------------
log_info "Configuring automatic security updates..."
apt install -y unattended-upgrades

# Configure unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

log_success "Automatic security updates configured"

#---------------------------------------
# Secure shared memory
#---------------------------------------
log_info "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
    log_success "Shared memory secured"
else
    log_info "Shared memory already secured"
fi

#---------------------------------------
# Set up basic audit logging
#---------------------------------------
log_info "Installing auditd for security auditing..."
apt install -y auditd

# Basic audit rules
cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Delete all existing rules
-D

# Set buffer size
-b 8192

# Failure mode
-f 1

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor SSH keys
-w /home -p wa -k user_homes
-w /root/.ssh -p wa -k root_ssh

# Monitor Dokku configuration
-w /home/dokku -p wa -k dokku_config

# Monitor system calls for privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid -k privilege_escalation
EOF

systemctl enable auditd
systemctl restart auditd
log_success "Audit logging configured"

#---------------------------------------
# Final security checks
#---------------------------------------
echo ""
log_info "Running final security checks..."

# Check if firewall is enabled
if ufw status | grep -q "active"; then
    log_success "Firewall: Active"
else
    log_warning "Firewall: Not active - run 'ufw enable'"
fi

# Check if fail2ban is running
if systemctl is-active --quiet fail2ban; then
    log_success "fail2ban: Running"
else
    log_warning "fail2ban: Not running"
fi

# Check SSH configuration
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    log_success "SSH root login: Disabled"
else
    log_warning "SSH root login: Still enabled"
fi

#---------------------------------------
# Summary
#---------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Server hardening complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Security measures applied:"
echo "  ✓ SSH hardened (root login disabled)"
echo "  ✓ fail2ban installed (brute-force protection)"
echo "  ✓ Automatic security updates enabled"
echo "  ✓ Shared memory secured"
echo "  ✓ Audit logging enabled"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SETUP COMPLETE!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Your Dokku server is ready for deployments!"
echo ""
echo "Next steps:"
echo "  1. Add SSH deploy key: echo 'PUBLIC_KEY' | dokku ssh-keys:add github-deploy"
echo "  2. Configure DNS wildcard: *.yourdomain.com → $(curl -s ifconfig.me)"
echo "  3. Create your first app: dokku apps:create myapp"
echo ""
