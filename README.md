# Dokku Deployment System

A complete GitHub + Dokku auto-deployment system with preview environments, automatic SSL, and service provisioning.

## Features

- **Auto-deploy on push** - Push to `main`/`staging`/`develop` for automatic deployment
- **Preview environments** - Every PR gets its own live URL
- **Automatic SSL** - Let's Encrypt certificates provisioned automatically
- **Zero-downtime** - Health checks ensure smooth deployments
- **Service provisioning** - PostgreSQL, Redis, etc. created automatically
- **Multi-environment** - Production, staging, development, preview
- **Rollback support** - Easy rollback to previous releases
- **Developer CLI** - Simple command-line tool for common operations

## Directory Structure

```
dokku-deploy-system/
├── server-setup/           # Server installation scripts
│   ├── 01-server-init.sh
│   ├── 02-dokku-install.sh
│   ├── 03-dokku-plugins.sh
│   ├── 04-letsencrypt-setup.sh
│   ├── 05-global-config.sh
│   ├── 06-server-hardening.sh
│   └── setup-all.sh
├── github-workflows/       # GitHub Actions workflows
│   ├── deploy.yml          # Main deployment
│   ├── preview.yml         # PR preview environments
│   ├── scheduled.yml       # Maintenance tasks
│   ├── rollback.yml        # Manual rollback
│   └── custom-domain.yml   # Add custom domains
├── template-repo/          # Template for new projects
│   ├── .github/workflows/
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

## Quick Start

### 1. Server Setup

On a fresh Ubuntu 22.04 server:

```bash
# Clone this repo
git clone https://github.com/yourorg/dokku-deploy-system.git
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

### 4. Configure GitHub Secrets

Add to your GitHub organization (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `DOKKU_HOST` | `dokku.yourdomain.com` |
| `DOKKU_SSH_PRIVATE_KEY` | (generated private key) |
| `BASE_DOMAIN` | `yourdomain.com` |

### 5. Create GitHub Environments

Create these environments in your repos:

- `production`
- `staging`
- `development`
- `preview`

### 6. Initialize a Project

```bash
# Copy template files to your project
./scripts/init-repo.sh /path/to/your/project

# Or manually copy from template-repo/
```

### 7. Deploy!

```bash
git push origin main  # Deploys to production
```

## Install CLI

```bash
# Download
curl -o dokku-cli https://raw.githubusercontent.com/yourorg/dokku-deploy-system/main/cli/dokku-cli
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
