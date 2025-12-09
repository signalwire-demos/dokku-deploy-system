#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# init-repo.sh
# Initialize a new repository with Dokku deployment files
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./init-repo.sh [directory]
#
# This script copies the template-repo files to your project,
# enabling automatic Dokku deployments.
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory (where template-repo is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template-repo"

# Target directory
TARGET_DIR="${1:-.}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Initialize Dokku Deployment"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo -e "${YELLOW}Template directory not found: $TEMPLATE_DIR${NC}"
    echo "Make sure you're running this from the dokku-deploy-system directory"
    exit 1
fi

# Create target directory if needed
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo -e "${BLUE}Initializing in: $(pwd)${NC}"
echo ""

# Copy files
copy_file() {
    local src="$1"
    local dest="$2"

    if [ -f "$dest" ]; then
        echo -e "  ${YELLOW}[skip]${NC} $dest (already exists)"
    else
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        echo -e "  ${GREEN}[create]${NC} $dest"
    fi
}

# Copy all template files
echo "Copying template files..."

copy_file "$TEMPLATE_DIR/.github/workflows/deploy.yml" ".github/workflows/deploy.yml"
copy_file "$TEMPLATE_DIR/.github/workflows/preview.yml" ".github/workflows/preview.yml"
copy_file "$TEMPLATE_DIR/.dokku/services.yml" ".dokku/services.yml"
copy_file "$TEMPLATE_DIR/.dokku/config.yml" ".dokku/config.yml"
copy_file "$TEMPLATE_DIR/Procfile" "Procfile"
copy_file "$TEMPLATE_DIR/runtime.txt" "runtime.txt"
copy_file "$TEMPLATE_DIR/CHECKS" "CHECKS"
copy_file "$TEMPLATE_DIR/app.json" "app.json"
copy_file "$TEMPLATE_DIR/.env.example" ".env.example"
copy_file "$TEMPLATE_DIR/.gitignore" ".gitignore"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Initialization Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "  1. Edit Procfile with your start command"
echo ""
echo "  2. Edit .dokku/services.yml to enable required services"
echo ""
echo "  3. Add GitHub Secrets:"
echo "     - DOKKU_HOST"
echo "     - DOKKU_SSH_PRIVATE_KEY"
echo "     - BASE_DOMAIN"
echo ""
echo "  4. Create GitHub Environments:"
echo "     - production"
echo "     - staging"
echo "     - development"
echo "     - preview"
echo ""
echo "  5. Push to GitHub to deploy!"
echo ""
