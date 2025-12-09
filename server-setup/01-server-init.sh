#!/bin/bash
#===============================================================================
# 01-server-init.sh
# Initial server setup for Dokku deployment
# Run this first on a fresh Ubuntu 22.04 server
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Dokku Server Initialization - Step 1/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu 22" /etc/os-release 2>/dev/null; then
    log_warning "This script is designed for Ubuntu 22.04"
    read -p "Continue anyway? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

#---------------------------------------
# Update system
#---------------------------------------
log_info "Updating system packages..."
apt update
apt upgrade -y
log_success "System updated"

#---------------------------------------
# Install essential packages
#---------------------------------------
log_info "Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    htop \
    ncdu \
    tree

log_success "Essential packages installed"

#---------------------------------------
# Set hostname
#---------------------------------------
read -p "Enter hostname for this server (e.g., dokku.yourdomain.com): " HOSTNAME
if [ -n "$HOSTNAME" ]; then
    hostnamectl set-hostname "$HOSTNAME"
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
    log_success "Hostname set to: $HOSTNAME"
else
    log_warning "Hostname not changed"
fi

#---------------------------------------
# Configure firewall
#---------------------------------------
log_info "Configuring firewall (UFW)..."

# Install UFW if not present
apt install -y ufw

# Reset and configure
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important - don't lock yourself out!)
ufw allow OpenSSH

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

log_success "Firewall configured (SSH, HTTP, HTTPS allowed)"

#---------------------------------------
# Set timezone
#---------------------------------------
log_info "Setting timezone to UTC..."
timedatectl set-timezone UTC
log_success "Timezone set to UTC"

#---------------------------------------
# Configure swap (if needed)
#---------------------------------------
if [ ! -f /swapfile ]; then
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 4096 ]; then
        log_info "Low memory detected. Creating 2GB swap file..."
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_success "Swap file created and enabled"
    fi
else
    log_info "Swap file already exists"
fi

#---------------------------------------
# Create dokku user (if doesn't exist)
#---------------------------------------
if ! id "dokku" &>/dev/null; then
    log_info "Dokku user will be created during Dokku installation"
else
    log_info "Dokku user already exists"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Server initialization complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next step: Run 02-dokku-install.sh"
echo ""
