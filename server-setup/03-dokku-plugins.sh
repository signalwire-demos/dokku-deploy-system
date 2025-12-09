#!/bin/bash
#===============================================================================
# 03-dokku-plugins.sh
# Install essential Dokku plugins
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
echo "  Dokku Plugin Installation - Step 3/6"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo $0)"
    exit 1
fi

# Check if Dokku is installed
if ! command -v dokku &>/dev/null; then
    log_error "Dokku is not installed. Run 02-dokku-install.sh first."
    exit 1
fi

#---------------------------------------
# Define plugins to install
#---------------------------------------
declare -A PLUGINS=(
    # SSL - Let's Encrypt (required)
    ["letsencrypt"]="https://github.com/dokku/dokku-letsencrypt.git"

    # Databases
    ["postgres"]="https://github.com/dokku/dokku-postgres.git"
    ["redis"]="https://github.com/dokku/dokku-redis.git"
    ["mysql"]="https://github.com/dokku/dokku-mysql.git"
    ["mongo"]="https://github.com/dokku/dokku-mongo.git"

    # Message queues
    ["rabbitmq"]="https://github.com/dokku/dokku-rabbitmq.git"

    # Search
    ["elasticsearch"]="https://github.com/dokku/dokku-elasticsearch.git"

    # Utilities
    ["http-auth"]="https://github.com/dokku/dokku-http-auth.git"
    ["maintenance"]="https://github.com/dokku/dokku-maintenance.git"
    ["redirect"]="https://github.com/dokku/dokku-redirect.git"
)

#---------------------------------------
# Interactive plugin selection
#---------------------------------------
echo "Select plugins to install:"
echo ""
echo "  [Required]"
echo "    - letsencrypt (SSL certificates)"
echo ""
echo "  [Databases]"
echo "    - postgres"
echo "    - redis"
echo "    - mysql"
echo "    - mongo"
echo ""
echo "  [Other]"
echo "    - rabbitmq"
echo "    - elasticsearch"
echo "    - http-auth"
echo "    - maintenance"
echo "    - redirect"
echo ""

read -p "Install all plugins? (Y/n): " INSTALL_ALL

if [ "$INSTALL_ALL" == "n" ] || [ "$INSTALL_ALL" == "N" ]; then
    # Selective installation
    SELECTED_PLUGINS=("letsencrypt")  # Always install letsencrypt

    read -p "Install PostgreSQL? (Y/n): " p
    [ "$p" != "n" ] && [ "$p" != "N" ] && SELECTED_PLUGINS+=("postgres")

    read -p "Install Redis? (Y/n): " p
    [ "$p" != "n" ] && [ "$p" != "N" ] && SELECTED_PLUGINS+=("redis")

    read -p "Install MySQL? (y/N): " p
    [ "$p" == "y" ] || [ "$p" == "Y" ] && SELECTED_PLUGINS+=("mysql")

    read -p "Install MongoDB? (y/N): " p
    [ "$p" == "y" ] || [ "$p" == "Y" ] && SELECTED_PLUGINS+=("mongo")

    read -p "Install RabbitMQ? (y/N): " p
    [ "$p" == "y" ] || [ "$p" == "Y" ] && SELECTED_PLUGINS+=("rabbitmq")

    read -p "Install Elasticsearch? (y/N): " p
    [ "$p" == "y" ] || [ "$p" == "Y" ] && SELECTED_PLUGINS+=("elasticsearch")

    read -p "Install HTTP Auth? (Y/n): " p
    [ "$p" != "n" ] && [ "$p" != "N" ] && SELECTED_PLUGINS+=("http-auth")

    read -p "Install Maintenance mode? (Y/n): " p
    [ "$p" != "n" ] && [ "$p" != "N" ] && SELECTED_PLUGINS+=("maintenance")

    read -p "Install Redirect plugin? (y/N): " p
    [ "$p" == "y" ] || [ "$p" == "Y" ] && SELECTED_PLUGINS+=("redirect")
else
    SELECTED_PLUGINS=("${!PLUGINS[@]}")
fi

#---------------------------------------
# Install selected plugins
#---------------------------------------
echo ""
log_info "Installing ${#SELECTED_PLUGINS[@]} plugins..."
echo ""

for plugin in "${SELECTED_PLUGINS[@]}"; do
    url="${PLUGINS[$plugin]}"
    if [ -n "$url" ]; then
        log_info "Installing: $plugin"

        # Check if already installed
        if dokku plugin:installed "$plugin" 2>/dev/null; then
            log_warning "  Already installed, skipping"
        else
            dokku plugin:install "$url" "$plugin"
            log_success "  Installed: $plugin"
        fi
    fi
done

#---------------------------------------
# List installed plugins
#---------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Plugin installation complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Installed plugins:"
dokku plugin:list
echo ""
echo "Next step: Run 04-letsencrypt-setup.sh"
echo ""
