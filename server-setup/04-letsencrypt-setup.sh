#!/bin/bash
#===============================================================================
# 04-letsencrypt-setup.sh
# Configure Let's Encrypt for automatic SSL certificates
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
echo "  Let's Encrypt Configuration - Step 4/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

# Check if letsencrypt plugin is installed
if ! dokku plugin:installed letsencrypt 2>/dev/null; then
    log_error "Let's Encrypt plugin is not installed"
    log_info "Install it with: dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git"
    exit 1
fi

#---------------------------------------
# Get email address
#---------------------------------------
read -p "Enter email address for Let's Encrypt notifications: " LE_EMAIL
if [ -z "$LE_EMAIL" ]; then
    log_error "Email address is required for Let's Encrypt"
    exit 1
fi

# Validate email format (basic check)
if ! echo "$LE_EMAIL" | grep -qE "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
    log_warning "Email format looks invalid, but continuing..."
fi

#---------------------------------------
# Set global email
#---------------------------------------
log_info "Setting global Let's Encrypt email..."
dokku letsencrypt:set --global email "$LE_EMAIL"
log_success "Email set: $LE_EMAIL"

#---------------------------------------
# Configure auto-renewal cron job
#---------------------------------------
log_info "Setting up auto-renewal cron job..."
dokku letsencrypt:cron-job --add
log_success "Auto-renewal cron job configured"

#---------------------------------------
# Optional: Use staging server for testing
#---------------------------------------
echo ""
read -p "Use Let's Encrypt staging server for testing? (y/N): " USE_STAGING
if [ "$USE_STAGING" == "y" ] || [ "$USE_STAGING" == "Y" ]; then
    dokku letsencrypt:set --global server staging
    log_warning "Staging server enabled (certificates won't be trusted by browsers)"
    log_info "To switch to production: dokku letsencrypt:set --global server default"
else
    dokku letsencrypt:set --global server default
    log_success "Using production Let's Encrypt server"
fi

#---------------------------------------
# Show configuration
#---------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Let's Encrypt configuration complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  Email: $LE_EMAIL"
echo "  Auto-renewal: Enabled (daily cron job)"
echo "  Server: $(dokku letsencrypt:get --global server 2>/dev/null || echo 'production')"
echo ""
echo "Usage:"
echo "  Enable SSL for an app:  dokku letsencrypt:enable <app-name>"
echo "  Check certificate:      dokku letsencrypt:ls"
echo "  Manual renewal:         dokku letsencrypt:auto-renew"
echo ""
echo "Next step: Run 05-global-config.sh"
echo ""
