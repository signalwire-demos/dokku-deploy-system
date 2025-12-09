#!/bin/bash
#===============================================================================
# setup-all.sh
# Run all Dokku server setup scripts in sequence
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              DOKKU SERVER COMPLETE SETUP                      ║"
echo "║                                                               ║"
echo "║  This will run all setup scripts in sequence:                 ║"
echo "║                                                               ║"
echo "║    1. Server initialization                                   ║"
echo "║    2. Dokku installation                                      ║"
echo "║    3. Plugin installation                                     ║"
echo "║    4. Let's Encrypt configuration                             ║"
echo "║    5. Global Dokku configuration                              ║"
echo "║    6. Security hardening                                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please run as root (sudo $0)"
    exit 1
fi

read -p "Continue with full setup? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Starting setup..."
echo ""

#---------------------------------------
# Run each script
#---------------------------------------
SCRIPTS=(
    "01-server-init.sh"
    "02-dokku-install.sh"
    "03-dokku-plugins.sh"
    "04-letsencrypt-setup.sh"
    "05-global-config.sh"
    "06-server-hardening.sh"
)

for script in "${SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"

    if [ -f "$script_path" ]; then
        echo ""
        echo "───────────────────────────────────────────────────────────────"
        echo "  Running: $script"
        echo "───────────────────────────────────────────────────────────────"
        echo ""

        bash "$script_path"

        if [ $? -ne 0 ]; then
            echo -e "${RED}[ERROR]${NC} $script failed"
            exit 1
        fi
    else
        echo -e "${YELLOW}[WARNING]${NC} Script not found: $script_path"
    fi
done

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              SETUP COMPLETE!                                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Your Dokku server is fully configured and ready for deployments!"
echo ""
echo "Quick reference:"
echo "  - Create app:     dokku apps:create <name>"
echo "  - Deploy:         git push dokku main"
echo "  - Enable SSL:     dokku letsencrypt:enable <app>"
echo "  - View logs:      dokku logs <app> -t"
echo ""
