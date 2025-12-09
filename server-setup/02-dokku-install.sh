#!/bin/bash
#===============================================================================
# 02-dokku-install.sh
# Install Dokku on Ubuntu server
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
echo "  Dokku Installation - Step 2/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

# Configuration
DOKKU_VERSION="${DOKKU_VERSION:-v0.34.4}"

#---------------------------------------
# Prompt for domain
#---------------------------------------
read -p "Enter your global domain (e.g., yourdomain.com): " GLOBAL_DOMAIN
if [ -z "$GLOBAL_DOMAIN" ]; then
    log_error "Domain is required"
    exit 1
fi

#---------------------------------------
# Check if Dokku is already installed
#---------------------------------------
if command -v dokku &>/dev/null; then
    CURRENT_VERSION=$(dokku version 2>/dev/null || echo "unknown")
    log_warning "Dokku is already installed: $CURRENT_VERSION"
    read -p "Reinstall/upgrade? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 0
    fi
fi

#---------------------------------------
# Install Dokku
#---------------------------------------
log_info "Downloading Dokku installer (${DOKKU_VERSION})..."
wget -NP . "https://dokku.com/install/${DOKKU_VERSION}/bootstrap.sh"

log_info "Installing Dokku (this may take several minutes)..."
DOKKU_TAG=${DOKKU_VERSION} bash bootstrap.sh

#---------------------------------------
# Set global domain
#---------------------------------------
log_info "Setting global domain: $GLOBAL_DOMAIN"
dokku domains:set-global "$GLOBAL_DOMAIN"

#---------------------------------------
# Basic Dokku configuration
#---------------------------------------
log_info "Applying basic configuration..."

# Disable anonymous stats reporting (optional)
dokku config:set --global DOKKU_DISABLE_ANSI_PREFIX=true 2>/dev/null || true

#---------------------------------------
# Verify installation
#---------------------------------------
log_info "Verifying installation..."
dokku version

echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Dokku installation complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Dokku version: $(dokku version)"
echo "Global domain: $GLOBAL_DOMAIN"
echo ""
echo "Next step: Run 03-dokku-plugins.sh"
echo ""

# Cleanup
rm -f bootstrap.sh
