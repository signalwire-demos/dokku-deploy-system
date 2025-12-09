#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# generate-deploy-key.sh
# Generate SSH keypair for GitHub Actions → Dokku deployments
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_NAME="${1:-dokku_deploy}"
KEY_PATH="./${KEY_NAME}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Generating Deploy Key"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    echo -e "${YELLOW}Warning: Key already exists at $KEY_PATH${NC}"
    read -p "Overwrite? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

# Generate key
echo -e "${BLUE}Generating Ed25519 keypair...${NC}"
ssh-keygen -t ed25519 -C "github-actions-deploy" -f "$KEY_PATH" -N ""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Keys Generated Successfully!${NC}"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 1: Add PUBLIC key to Dokku server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run this on your Dokku server:"
echo ""
echo -e "${BLUE}echo '$(cat ${KEY_PATH}.pub)' | dokku ssh-keys:add github-deploy${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 2: Add PRIVATE key to GitHub Secrets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Go to: GitHub Repo → Settings → Secrets → Actions"
echo "Create secret: DOKKU_SSH_PRIVATE_KEY"
echo ""
echo "Copy this entire private key (including BEGIN/END lines):"
echo ""
echo "─────────────────────────────────────────────────────────────────"
cat "$KEY_PATH"
echo "─────────────────────────────────────────────────────────────────"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 3: Clean up"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Important: Delete these key files after adding to GitHub and Dokku!${NC}"
echo ""
echo "  rm ${KEY_PATH} ${KEY_PATH}.pub"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
