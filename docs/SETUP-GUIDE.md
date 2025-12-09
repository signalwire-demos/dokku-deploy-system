# Complete Setup Guide

Step-by-step instructions for setting up the Dokku deployment system in the `signalwire-demos` organization.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Create GitHub Fine-Grained Token](#create-github-fine-grained-token)
3. [Configure gh CLI](#configure-gh-cli)
4. [Set Up the Dokku Server](#set-up-the-dokku-server)
5. [Generate and Configure SSH Keys](#generate-and-configure-ssh-keys)
6. [Configure GitHub Organization Secrets](#configure-github-organization-secrets)
7. [Create GitHub Environments](#create-github-environments)
8. [Set Up DNS](#set-up-dns)
9. [Test the Setup](#test-the-setup)
10. [Initialize Your First Project](#initialize-your-first-project)

---

## Prerequisites

Before starting, ensure you have:

- [ ] A fresh Ubuntu 22.04 server with:
  - Public IP address
  - SSH access as root or sudo user
  - 4+ GB RAM (8+ recommended)
  - 50+ GB SSD
- [ ] Domain name with DNS access
- [ ] Admin access to the `signalwire-demos` GitHub organization
- [ ] `gh` CLI installed locally (`brew install gh` or see [cli.github.com](https://cli.github.com))

---

## Step 1: Create GitHub Fine-Grained Token

### 1.1 Navigate to Token Settings

```
https://github.com/settings/tokens?type=beta
```

Or: GitHub Profile → Settings → Developer settings → Personal access tokens → Fine-grained tokens

### 1.2 Click "Generate new token"

### 1.3 Configure Token Settings

| Setting | Value |
|---------|-------|
| **Token name** | `dokku-deploy-signalwire-demos` |
| **Expiration** | 90 days (or custom) |
| **Description** | Dokku deployment system for signalwire-demos |
| **Resource owner** | `signalwire-demos` (select from dropdown) |
| **Repository access** | "All repositories" |

### 1.4 Set Repository Permissions

| Permission | Access Level |
|------------|--------------|
| **Actions** | Read and write |
| **Contents** | Read and write |
| **Deployments** | Read and write |
| **Environments** | Read and write |
| **Metadata** | Read (auto-selected) |
| **Pull requests** | Read and write |
| **Secrets** | Read and write |
| **Variables** | Read and write |
| **Workflows** | Read and write |

### 1.5 Set Organization Permissions

| Permission | Access Level |
|------------|--------------|
| **Members** | Read |
| **Organization secrets** | Read and write |
| **Organization variables** | Read and write |

### 1.6 Generate and Save Token

1. Click "Generate token"
2. **IMPORTANT**: Copy the token immediately - you won't see it again!
3. Save it temporarily in a secure location (password manager, etc.)

---

## Step 2: Configure gh CLI

### 2.1 Check Current Login Status

```bash
gh auth status
```

### 2.2 Option A: Switch to Token-Based Auth (Recommended for Org Work)

```bash
# Logout of current session (if needed)
gh auth logout

# Login with your new token
gh auth login
```

When prompted:
- Select: `GitHub.com`
- Select: `Paste an authentication token`
- Paste your fine-grained token

### 2.2 Option B: Use Environment Variable (Keep Existing Auth)

If you want to keep your personal account logged in:

```bash
# Export the token for this terminal session
export GH_TOKEN="github_pat_your_token_here"

# All gh commands will now use this token
gh auth status  # Should show organization access
```

Add to your shell profile for persistence:
```bash
# Add to ~/.zshrc or ~/.bashrc
export DOKKU_DEPLOY_TOKEN="github_pat_your_token_here"

# Then use it when needed:
# GH_TOKEN=$DOKKU_DEPLOY_TOKEN gh api ...
```

### 2.3 Verify Token Access

```bash
# Check organization access
gh api orgs/signalwire-demos --jq '.login'
# Should output: signalwire-demos

# Check you can list repos
gh repo list signalwire-demos --limit 5

# Check secrets access
gh api orgs/signalwire-demos/actions/secrets --jq '.secrets[].name'
```

---

## Step 3: Set Up the Dokku Server

### 3.1 SSH Into Your Server

```bash
ssh root@YOUR_SERVER_IP
```

### 3.2 Clone the Deployment System

```bash
git clone https://github.com/signalwire-demos/dokku-deploy-system.git
cd dokku-deploy-system/server-setup
```

Or if setting up before pushing to GitHub:
```bash
# Copy files from your local machine
scp -r /path/to/dokku-deploy-system root@YOUR_SERVER_IP:/root/
ssh root@YOUR_SERVER_IP
cd /root/dokku-deploy-system/server-setup
```

### 3.3 Run Server Setup Scripts

**Option A: Run All at Once**
```bash
chmod +x *.sh
sudo ./setup-all.sh
```

**Option B: Run Individually (Recommended for First-Time Setup)**
```bash
chmod +x *.sh

# Step 1: Basic server initialization
sudo ./01-server-init.sh
# Wait for completion, review output

# Step 2: Install Dokku
sudo ./02-dokku-install.sh
# This takes 5-10 minutes

# Step 3: Install Dokku plugins
sudo ./03-dokku-plugins.sh
# Installs postgres, redis, letsencrypt, etc.

# Step 4: Configure Let's Encrypt
sudo ./04-letsencrypt-setup.sh
# You'll be prompted for admin email

# Step 5: Global configuration
sudo ./05-global-config.sh
# Sets up NGINX, resource defaults, etc.

# Step 6: Security hardening (optional but recommended)
sudo ./06-server-hardening.sh
```

### 3.4 Verify Dokku Installation

```bash
dokku version
# Should output: dokku version X.XX.X

dokku plugin:list
# Should show: postgres, redis, letsencrypt, etc.
```

---

## Step 4: Generate and Configure SSH Keys

### 4.1 Generate Deploy Key (On Your Local Machine)

```bash
cd /path/to/dokku-deploy-system/scripts
chmod +x generate-deploy-key.sh
./generate-deploy-key.sh
```

This creates:
- `~/.ssh/dokku_deploy_key` (private key)
- `~/.ssh/dokku_deploy_key.pub` (public key)

### 4.2 Add Public Key to Dokku Server

```bash
# Copy the public key
cat ~/.ssh/dokku_deploy_key.pub

# SSH to server and add the key
ssh root@YOUR_SERVER_IP

# Add the key (replace KEY_CONTENT with actual key)
echo "KEY_CONTENT" | dokku ssh-keys:add github-actions

# Verify
dokku ssh-keys:list
```

Or in one command:
```bash
cat ~/.ssh/dokku_deploy_key.pub | ssh root@YOUR_SERVER_IP "dokku ssh-keys:add github-actions"
```

### 4.3 Get Private Key for GitHub

```bash
# This is what goes into GitHub Secrets
cat ~/.ssh/dokku_deploy_key
```

Copy the entire output including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

---

## Step 5: Configure GitHub Organization Secrets (Infrastructure Only)

### 5.1 Set Organization-Level Secrets

These secrets are for **infrastructure only** - the core deployment system. App-specific configuration uses Environment Variables (Step 5.4).

```bash
# Ensure you're authenticated with the org token
gh auth status

# Set DOKKU_HOST
gh secret set DOKKU_HOST \
  --org signalwire-demos \
  --visibility all \
  --body "dokku.yourdomain.com"

# Set DOKKU_SSH_PRIVATE_KEY (use file input for multiline)
gh secret set DOKKU_SSH_PRIVATE_KEY \
  --org signalwire-demos \
  --visibility all \
  < ~/.ssh/dokku_deploy_key

# Set BASE_DOMAIN
gh secret set BASE_DOMAIN \
  --org signalwire-demos \
  --visibility all \
  --body "yourdomain.com"
```

### 5.2 Verify Secrets Were Created

```bash
gh api orgs/signalwire-demos/actions/secrets --jq '.secrets[].name'
```

Should output:
```
DOKKU_HOST
DOKKU_SSH_PRIVATE_KEY
BASE_DOMAIN
```

### 5.3 Optional: Set Slack Webhook (Org-Level)

```bash
# Slack webhook for deployment notifications
gh secret set SLACK_WEBHOOK_URL \
  --org signalwire-demos \
  --visibility all \
  --body "https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

### 5.4 Optional: Set GH_ORG_TOKEN for Cleanup

The automatic cleanup workflow needs a token to check if repos/PRs still exist:

```bash
# Create a fine-grained PAT at https://github.com/settings/tokens?type=beta
# - Resource owner: signalwire-demos
# - Repository access: All repositories
# - Permissions: Metadata (read-only) - this is the default

gh secret set GH_ORG_TOKEN \
  --org signalwire-demos \
  --visibility all \
  --body "github_pat_xxx"
```

This enables the daily cleanup to detect:
- Apps whose repos have been deleted
- PR preview apps for closed/merged PRs

### 5.5 Configure App-Specific Environment Variables

For app-specific configuration, use **GitHub Environment Variables** (not secrets). This is the recommended approach because:

- Variables are visible in workflow logs (easier debugging)
- Variables can be edited after creation (secrets cannot)
- The workflow dynamically reads all variables using `toJSON(vars)`
- The workflow clears Dokku config before setting, ensuring changes are applied

**To configure environment variables:**

1. Go to your repository → **Settings** → **Environments**
2. Select the environment (e.g., `production`)
3. Under **Environment variables** (not secrets), add your variables

**Example variables for a SignalWire app:**

| Variable | Example Value |
|----------|---------------|
| `SIGNALWIRE_SPACE_NAME` | `myspace` |
| `SIGNALWIRE_PROJECT_ID` | `abc123-def456` |
| `SIGNALWIRE_TOKEN` | `PTxxxxxxxx` |
| `SWML_BASIC_AUTH_USER` | `admin` |
| `SWML_BASIC_AUTH_PASSWORD` | `securepass` |
| `RAPIDAPI_KEY` | `your-api-key` |

**Via CLI:**

```bash
# Set an environment variable for the production environment
gh api repos/signalwire-demos/myapp/environments/production/variables \
  -X POST \
  -f name=SIGNALWIRE_SPACE_NAME \
  -f value=myspace

# List environment variables
gh api repos/signalwire-demos/myapp/environments/production/variables \
  --jq '.variables[].name'
```

**Important**: The deploy workflow automatically:
1. Reads all environment variables from the GitHub Environment
2. Clears existing Dokku config (`config:clear`)
3. Sets all variables fresh (`config:set`)

This ensures that any changes to variables are always applied.

---

## Step 6: Create GitHub Environments

Environments can be created automatically by the deploy workflow, or manually. The workflow will auto-create environments if they don't exist, but you may want to create them manually to configure variables first:

### 6.1 Create Environment Setup Script

```bash
#!/bin/bash
# setup-repo-environments.sh

REPO="$1"

if [ -z "$REPO" ]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

ORG="signalwire-demos"

echo "Creating environments for $ORG/$REPO..."

# Create production environment
gh api -X PUT "repos/$ORG/$REPO/environments/production" \
  --field "wait_timer=0" \
  --field "prevent_self_review=false"

# Create staging environment
gh api -X PUT "repos/$ORG/$REPO/environments/staging"

# Create development environment
gh api -X PUT "repos/$ORG/$REPO/environments/development"

# Create preview environment
gh api -X PUT "repos/$ORG/$REPO/environments/preview"

echo "Environments created successfully!"

# List environments
gh api "repos/$ORG/$REPO/environments" --jq '.environments[].name'
```

### 6.2 Run for a Repository

```bash
chmod +x setup-repo-environments.sh
./setup-repo-environments.sh my-app-name
```

---

## Step 7: Set Up DNS

### 7.1 Add Wildcard DNS Record

In your DNS provider (Cloudflare, Route53, etc.):

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `*` | `YOUR_SERVER_IP` | 300 |
| A | `@` | `YOUR_SERVER_IP` | 300 |

Example for `yourdomain.com`:
- `*.yourdomain.com` → `123.45.67.89`
- `yourdomain.com` → `123.45.67.89`

### 7.2 Verify DNS Propagation

```bash
# Check wildcard resolution
dig +short test-app.yourdomain.com
# Should return your server IP

# Check another subdomain
dig +short anything.yourdomain.com
# Should return your server IP
```

### 7.3 Configure Dokku Domain

```bash
# On Dokku server
ssh root@YOUR_SERVER_IP

# Set the global domain
dokku domains:set-global yourdomain.com

# Verify
dokku domains:report --global
```

---

## Step 8: Test the Setup

### 8.1 Test SSH Connection

```bash
# From your local machine
ssh -i ~/.ssh/dokku_deploy_key dokku@YOUR_SERVER_IP version
# Should output dokku version
```

### 8.2 Test GitHub Actions SSH

Create a test workflow:

```yaml
# .github/workflows/test-connection.yml
name: Test Dokku Connection

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOKKU_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

      - name: Test Connection
        run: |
          ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} version
```

Run it manually from Actions tab.

### 8.3 Test SSL Provisioning

```bash
# On Dokku server
# Create a test app
dokku apps:create test-ssl
dokku domains:add test-ssl test-ssl.yourdomain.com
dokku letsencrypt:enable test-ssl

# Check certificate
dokku letsencrypt:list

# Clean up
dokku apps:destroy test-ssl --force
```

---

## Step 9: Initialize Your First Project

### 9.1 Clone or Create Repository

```bash
# Create new repo
gh repo create signalwire-demos/my-first-app --private --clone
cd my-first-app

# Or clone existing
gh repo clone signalwire-demos/existing-repo
cd existing-repo
```

### 9.2 Initialize Dokku Files

```bash
# Run init script from dokku-deploy-system
/path/to/dokku-deploy-system/scripts/init-repo.sh .

# Or copy template files manually
cp -r /path/to/dokku-deploy-system/template-repo/. .
```

### 9.3 Configure Your Application

Edit `Procfile`:
```
web: uvicorn app:app --host 0.0.0.0 --port $PORT
```

Edit `.dokku/services.yml`:
```yaml
services:
  postgres:
    enabled: true
  redis:
    enabled: false
```

Create your app (e.g., `app.py`):
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from Dokku!"}

@app.get("/health")
def health():
    return {"status": "ok"}
```

Create `requirements.txt`:
```
fastapi
uvicorn[standard]
```

### 9.4 Create Environments for This Repo

```bash
./setup-repo-environments.sh my-first-app
```

### 9.5 Push and Deploy

```bash
git add .
git commit -m "Initial commit with Dokku deployment"
git push -u origin main
```

### 9.6 Monitor Deployment

```bash
# Watch the Actions tab
gh run watch

# Or list recent runs
gh run list --repo signalwire-demos/my-first-app
```

### 9.7 Verify Deployment

```bash
# Check the app is running
curl https://my-first-app.yourdomain.com/health
# Should return: {"status":"ok"}

# View logs
ssh dokku@YOUR_SERVER_IP logs my-first-app
```

---

## Quick Reference: All Commands

```bash
# === GitHub Token Setup ===
# Create token at: https://github.com/settings/tokens?type=beta

# === gh CLI Setup ===
gh auth login                    # Login with token
gh auth status                   # Check status
export GH_TOKEN="token"          # Use env var instead

# === Verify Access ===
gh api orgs/signalwire-demos --jq '.login'
gh repo list signalwire-demos --limit 5
gh api orgs/signalwire-demos/actions/secrets --jq '.secrets[].name'

# === Set Org Secrets (Infrastructure Only) ===
gh secret set DOKKU_HOST --org signalwire-demos --visibility all --body "host"
gh secret set DOKKU_SSH_PRIVATE_KEY --org signalwire-demos --visibility all < key
gh secret set BASE_DOMAIN --org signalwire-demos --visibility all --body "domain"

# === Set Environment Variables (App Config) ===
gh api repos/ORG/REPO/environments/production/variables -X POST -f name=VAR -f value=val
gh api repos/ORG/REPO/environments/production/variables --jq '.variables[].name'

# === Create Environments (auto-created by workflow too) ===
gh api -X PUT "repos/ORG/REPO/environments/production"
gh api -X PUT "repos/ORG/REPO/environments/staging"
gh api -X PUT "repos/ORG/REPO/environments/development"
gh api -X PUT "repos/ORG/REPO/environments/preview"

# === Dokku Server ===
dokku version
dokku plugin:list
dokku apps:list
dokku logs app-name
```

---

## Troubleshooting

### "Permission denied" when setting secrets

```bash
# Verify token has correct permissions
gh api user --jq '.login'
gh api orgs/signalwire-demos/memberships/$USER --jq '.role'
# Should be 'admin'
```

### "Resource not accessible by integration"

Your token doesn't have the required permissions. Create a new token with:
- Organization permissions → Organization secrets: Read and write

### SSH connection fails

```bash
# Test SSH directly
ssh -vvv -i ~/.ssh/dokku_deploy_key dokku@server version

# Check key is added on server
ssh root@server dokku ssh-keys:list
```

### DNS not resolving

```bash
# Check propagation
dig +short app.yourdomain.com

# May take up to 48 hours, but usually 5-30 minutes
# Use: https://dnschecker.org
```

---

## Next Steps

1. Review [ONBOARDING.md](./ONBOARDING.md) for developer onboarding
2. Review [QUICK-REFERENCE.md](./QUICK-REFERENCE.md) for daily commands
3. Set up the CLI: `dokku-cli setup`
4. Configure Slack notifications
5. Set up backup automation

---

## Support

- Documentation: This guide and related docs
- Issues: Create issue in dokku-deploy-system repo
- Slack: #deployments channel
