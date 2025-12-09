#!/bin/bash
#===============================================================================
# 05-global-config.sh
# Configure global Dokku settings
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
echo "  Global Dokku Configuration - Step 5/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

#---------------------------------------
# Zero-downtime deployment settings
#---------------------------------------
log_info "Configuring zero-downtime deployments..."

# Wait time before retiring old containers
dokku checks:set-property --global wait-to-retire 30

log_success "Zero-downtime: wait-to-retire set to 30 seconds"

#---------------------------------------
# NGINX configuration
#---------------------------------------
log_info "Configuring NGINX settings..."

# Increase client max body size (for file uploads)
dokku nginx:set --global client-max-body-size 50m
log_success "NGINX: client-max-body-size set to 50m"

# Set proxy timeouts
dokku nginx:set --global proxy-read-timeout 60s
dokku nginx:set --global proxy-connect-timeout 60s
log_success "NGINX: proxy timeouts set to 60s"

# Enable HSTS (HTTP Strict Transport Security)
dokku nginx:set --global hsts true
dokku nginx:set --global hsts-max-age 31536000
dokku nginx:set --global hsts-include-subdomains true
log_success "NGINX: HSTS enabled"

# Access logs
dokku nginx:set --global access-log-path /var/log/nginx/access.log
dokku nginx:set --global error-log-path /var/log/nginx/error.log
log_success "NGINX: logging configured"

#---------------------------------------
# Resource limits (optional)
#---------------------------------------
echo ""
read -p "Set default resource limits for apps? (Y/n): " SET_LIMITS
if [ "$SET_LIMITS" != "n" ] && [ "$SET_LIMITS" != "N" ]; then
    read -p "Default memory limit (e.g., 512m, 1g) [512m]: " MEMORY_LIMIT
    MEMORY_LIMIT="${MEMORY_LIMIT:-512m}"

    read -p "Default CPU limit (e.g., 1, 2) [1]: " CPU_LIMIT
    CPU_LIMIT="${CPU_LIMIT:-1}"

    dokku resource:limit --global --memory "$MEMORY_LIMIT"
    dokku resource:limit --global --cpu "$CPU_LIMIT"

    log_success "Resource limits: memory=$MEMORY_LIMIT, cpu=$CPU_LIMIT"
fi

#---------------------------------------
# Docker cleanup cron job
#---------------------------------------
log_info "Setting up Docker cleanup cron job..."

cat > /etc/cron.daily/dokku-cleanup << 'EOF'
#!/bin/bash
# Clean up unused Docker resources
docker system prune -af --filter "until=72h" 2>/dev/null || true
EOF

chmod +x /etc/cron.daily/dokku-cleanup
log_success "Docker cleanup cron job created"

#---------------------------------------
# Log rotation for Dokku
#---------------------------------------
log_info "Configuring log rotation..."

cat > /etc/logrotate.d/dokku << 'EOF'
/var/log/dokku/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 dokku dokku
    sharedscripts
}
EOF

log_success "Log rotation configured (14 days retention)"

#---------------------------------------
# Create security headers config
#---------------------------------------
log_info "Creating security headers configuration..."

mkdir -p /home/dokku/.nginx-includes

cat > /home/dokku/.nginx-includes/security-headers.conf << 'EOF'
# Security headers - include in app nginx configs
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
EOF

chown -R dokku:dokku /home/dokku/.nginx-includes
log_success "Security headers config created"

#---------------------------------------
# Summary
#---------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Global configuration complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Configuration applied:"
echo "  - Zero-downtime deployments enabled"
echo "  - NGINX optimized (timeouts, body size, HSTS)"
echo "  - Resource limits: ${MEMORY_LIMIT:-default}, ${CPU_LIMIT:-default} CPU"
echo "  - Docker cleanup: daily"
echo "  - Log rotation: 14 days"
echo "  - Security headers: available at /home/dokku/.nginx-includes/"
echo ""
echo "Next step: Run 06-server-hardening.sh"
echo ""
