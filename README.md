# Dokku Deployment System

A complete GitHub + Dokku auto-deployment system with preview environments, automatic SSL, and service provisioning.

## Features

- **Auto-deploy on push** - Push to `main`/`staging`/`develop` for automatic deployment
- **Preview environments** - Every PR gets its own live URL
- **Automatic SSL** - Let's Encrypt certificates provisioned automatically
- **Zero-downtime** - Health checks ensure smooth deployments
- **Service provisioning** - PostgreSQL, Redis, etc. created automatically
- **Multi-environment** - Production, staging, development, preview
- **Automatic cleanup** - Orphaned apps and closed PR previews removed daily
- **Rollback support** - Easy rollback to previous releases
- **Developer CLI** - Simple command-line tool for common operations

## Directory Structure

```
dokku-deploy-system/
├── .github/workflows/      # Reusable workflows (called by other repos)
│   ├── deploy.yml          # Reusable deploy workflow
│   ├── preview.yml         # Reusable preview workflow
│   └── cleanup.yml         # Automatic orphan cleanup (daily)
├── server-setup/           # Server installation scripts
│   ├── 01-server-init.sh
│   ├── 02-dokku-install.sh
│   ├── 03-dokku-plugins.sh
│   ├── 04-letsencrypt-setup.sh
│   ├── 05-global-config.sh
│   ├── 06-server-hardening.sh
│   └── setup-all.sh
├── github-workflows/       # Legacy workflows (deprecated)
│   ├── scheduled.yml       # Maintenance tasks
│   ├── rollback.yml        # Manual rollback
│   └── custom-domain.yml   # Add custom domains
├── template-repo/          # Template for new projects
│   ├── .github/workflows/  # Minimal callers to reusable workflows
│   ├── .dokku/
│   ├── Procfile
│   ├── CHECKS
│   └── ...
├── cli/                    # Developer CLI tool
│   └── dokku-cli
├── scripts/                # Utility scripts
│   ├── generate-deploy-key.sh
│   ├── backup-services.sh
│   └── init-repo.sh
└── docs/                   # Documentation
    ├── ONBOARDING.md
    ├── TROUBLESHOOTING.md
    └── QUICK-REFERENCE.md
```

## Reusable Workflows

This repo provides **reusable workflows** that other repos can call. This means:
- Deploy logic lives in ONE place (this repo)
- Project repos have minimal ~15-line workflow files
- Updates to deployment logic apply to ALL repos automatically

### Usage in Your Project

Create these two files in your project:

**`.github/workflows/deploy.yml`**:
```yaml
name: Deploy
on:
  workflow_dispatch:
  push:
    branches: [main, staging, develop]

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  deploy:
    uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main
    secrets: inherit
```

**`.github/workflows/preview.yml`**:
```yaml
name: Preview
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

concurrency:
  group: preview-${{ github.event.pull_request.number }}

jobs:
  preview:
    uses: signalwire-demos/dokku-deploy-system/.github/workflows/preview.yml@main
    secrets: inherit
```

That's it! The reusable workflows handle:
- Creating the Dokku app
- Setting environment variables from your GitHub Environment
- Deploying via git push
- Configuring domains and SSL
- Health checks and Slack notifications
- Preview environment creation/cleanup

## Automatic Cleanup

The system includes automatic cleanup of orphaned apps:

- **Daily at 6 AM UTC**: Scans all Dokku apps and removes:
  - Apps whose GitHub repos no longer exist
  - PR preview apps for closed/merged pull requests
  - All associated services (PostgreSQL, Redis, etc.)

- **Manual cleanup**: Run from the Actions tab in `dokku-deploy-system`:
  ```
  Actions → Cleanup App → Run workflow
  ```
  Options:
  - `app_name`: Specific app to destroy
  - `dry_run`: Preview what would be deleted
  - `include_services`: Also destroy linked services

### Required Secret for Cleanup

Add `GH_ORG_TOKEN` to org secrets (fine-grained PAT with Metadata read access):

```bash
gh secret set GH_ORG_TOKEN \
  --org signalwire-demos \
  --visibility all \
  --body "github_pat_xxx"
```

This token allows the cleanup workflow to check if repos/PRs still exist.

## Quick Start

### 1. Server Setup

On a fresh Ubuntu 22.04 server:

```bash
# Clone this repo
git clone https://github.com/signalwire-demos/dokku-deploy-system.git
cd dokku-deploy-system/server-setup

# Run all setup scripts
sudo ./setup-all.sh

# Or run individually
sudo ./01-server-init.sh
sudo ./02-dokku-install.sh
sudo ./03-dokku-plugins.sh
sudo ./04-letsencrypt-setup.sh
sudo ./05-global-config.sh
sudo ./06-server-hardening.sh
```

### 2. DNS Configuration

Add wildcard DNS:

```
Type: A
Name: *
Value: YOUR_SERVER_IP
TTL: 300
```

### 3. Generate Deploy Key

```bash
./scripts/generate-deploy-key.sh

# Follow instructions to:
# 1. Add public key to Dokku
# 2. Add private key to GitHub Secrets
```

### 4. Configure GitHub Secrets (Infrastructure Only)

Add to your GitHub organization (Settings → Secrets → Actions):

| Secret | Value | Purpose |
|--------|-------|---------|
| `DOKKU_HOST` | `dokku.yourdomain.com` | Server hostname |
| `DOKKU_SSH_PRIVATE_KEY` | (generated private key) | SSH authentication |
| `BASE_DOMAIN` | `yourdomain.com` | Base domain for apps |

**Note**: Org-level secrets are for **infrastructure only**. App-specific configuration uses Environment Variables (see below).

### 5. Configure Environment Variables (App Config)

For app-specific configuration, use **GitHub Environment Variables** (not secrets):

1. Go to your repo → **Settings** → **Environments**
2. Select an environment (e.g., `production`)
3. Add variables under **Environment variables** (not secrets)

| Variable | Example | Purpose |
|----------|---------|---------|
| `SIGNALWIRE_SPACE_NAME` | `myspace` | SignalWire space |
| `SIGNALWIRE_PROJECT_ID` | `abc-123` | SignalWire project |
| `SIGNALWIRE_TOKEN` | `PTxxx` | SignalWire token |
| `RAPIDAPI_KEY` | `xxx` | API keys |

**Why Variables instead of Secrets?**
- Variables are visible in logs (easier debugging)
- Variables can be edited after creation
- The workflow uses `toJSON(vars)` to dynamically set all environment variables
- The workflow clears Dokku config before setting to ensure changes are applied

### 6. Create GitHub Environments

Create these environments in your repos (or let the workflow create them automatically):

- `production` - for `main` branch
- `staging` - for `staging` branch
- `development` - for `develop` branch
- `preview` - for pull requests

**Note**: The deploy workflow automatically creates these environments if they don't exist.

### 7. Initialize a Project

```bash
# Copy template files to your project
./scripts/init-repo.sh /path/to/your/project

# Or manually copy from template-repo/
```

### 8. Deploy!

```bash
git push origin main  # Deploys to production
```

## Install CLI

```bash
# Download
curl -o dokku-cli https://raw.githubusercontent.com/signalwire-demos/dokku-deploy-system/main/cli/dokku-cli
chmod +x dokku-cli
sudo mv dokku-cli /usr/local/bin/

# Configure
dokku-cli setup
```

## CLI Usage

```bash
# App management
dokku-cli list
dokku-cli info myapp
dokku-cli logs myapp
dokku-cli restart myapp

# Configuration
dokku-cli config myapp
dokku-cli config:set myapp KEY=value

# Deployment
dokku-cli deploy myapp
dokku-cli rollback myapp

# Database
dokku-cli db myapp create postgres
dokku-cli db myapp connect postgres

# See all commands
dokku-cli help
```

## Branch → Environment Mapping

| Branch | App Name | URL |
|--------|----------|-----|
| `main` | `{repo}` | `{repo}.domain.com` |
| `staging` | `{repo}-staging` | `{repo}-staging.domain.com` |
| `develop` | `{repo}-dev` | `{repo}-dev.domain.com` |
| PR #42 | `{repo}-pr-42` | `{repo}-pr-42.domain.com` |

## Required Files in Projects

```
your-project/
├── .github/workflows/
│   ├── deploy.yml
│   └── preview.yml
├── .dokku/
│   ├── services.yml    # Enable postgres, redis, etc.
│   └── config.yml      # Resource limits
├── Procfile            # web: your-start-command
├── runtime.txt         # python-3.11
└── CHECKS              # /health
```

## Service Configuration

Edit `.dokku/services.yml`:

```yaml
services:
  postgres:
    enabled: true
  redis:
    enabled: true
```

## Documentation

- [Setup Guide](docs/SETUP-GUIDE.md) - **Start here** - Complete installation instructions
- [Onboarding Guide](docs/ONBOARDING.md) - Getting started for developers
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Quick Reference](docs/QUICK-REFERENCE.md) - One-page command reference

## Server Requirements

- Ubuntu 22.04 LTS
- 4+ GB RAM (8+ recommended)
- 50+ GB SSD
- Public IP address
- Domain with DNS access

## License

MIT
