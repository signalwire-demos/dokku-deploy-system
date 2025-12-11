# Dokku Deployment System

A complete GitHub + Dokku auto-deployment system with preview environments, automatic SSL, and service provisioning.

## Features

- **Auto-deploy on push** - Push to `main`/`staging`/`develop` for automatic deployment
- **Preview environments** - Every PR gets its own live URL
- **Automatic SSL** - Let's Encrypt certificates provisioned automatically
- **Zero-downtime** - Health checks ensure smooth deployments
- **Service provisioning** - PostgreSQL, Redis, MySQL, MongoDB, RabbitMQ, Elasticsearch
- **Multi-environment** - Production, staging, development, preview
- **Automatic cleanup** - Orphaned apps and closed PR previews removed daily
- **Rollback support** - Easy rollback to previous releases
- **Developer CLI** - Simple command-line tool for common operations
- **Deploy locks** - Block deployments during incidents or maintenance
- **Release tasks** - Run migrations/commands after deploy
- **Database backups** - Scheduled daily backups with retention policy
- **Deploy dashboard** - GitHub Pages dashboard showing all app status
- **Commit status checks** - Real-time deployment status on commits and PRs
- **Scheduled deployments** - Schedule deploys for specific times (off-hours, change windows)
- **Audit log** - Comprehensive deployment history with searchable logs
- **PR notifications** - Automatic comments on PRs when code is deployed
- **Approval gates** - Require manual approval for production deployments
- **Security scanning** - Trivy vulnerability scanning with configurable blocking
- **Webhook integrations** - Custom webhooks, Datadog, PagerDuty support

## Directory Structure

```
dokku-deploy-system/
├── .github/workflows/      # Workflows
│   ├── deploy.yml          # Reusable deploy workflow (called by other repos)
│   ├── preview.yml         # Reusable preview workflow (called by other repos)
│   ├── scheduled.yml       # Daily maintenance (cleanup, certs, health checks, backups)
│   ├── cleanup.yml         # Manual app cleanup with safety checks
│   ├── rollback.yml        # Manual rollback workflow
│   ├── lock.yml            # Deploy lock management
│   ├── backup.yml          # Manual database backup
│   ├── update-dashboard.yml # Dashboard update (called by deploy/cleanup)
│   ├── schedule-deploy.yml # Scheduled deployment management
│   └── audit-log.yml       # Deployment audit logging
├── server-setup/           # Server installation scripts
│   ├── 01-server-init.sh
│   ├── 02-dokku-install.sh
│   ├── 03-dokku-plugins.sh
│   ├── 04-letsencrypt-setup.sh
│   ├── 05-global-config.sh
│   ├── 06-server-hardening.sh
│   └── setup-all.sh
├── template-repo/          # Template for new projects
│   ├── .github/workflows/  # Minimal callers to reusable workflows
│   ├── .dokku/
│   ├── Procfile
│   ├── CHECKS
│   └── ...
├── dashboard/              # Deploy dashboard (GitHub Pages)
│   ├── index.html
│   ├── style.css
│   └── apps.json
├── cli/                    # Developer CLI tool
│   └── dokku-cli
├── scripts/                # Utility scripts
│   ├── generate-deploy-key.sh
│   ├── backup-services.sh
│   └── init-repo.sh
└── docs/                   # Documentation
    ├── ONBOARDING.md
    ├── TROUBLESHOOTING.md
    ├── QUICK-REFERENCE.md
    └── FEATURES.md
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

### Preview Security

To prevent malicious code from being auto-deployed via fork PRs:
- **Org members**: PRs auto-deploy previews as usual
- **External contributors**: Require manual trigger by org member

When an external contributor opens a PR, the workflow posts a comment explaining how a maintainer can manually deploy the preview.

**Manual trigger for external PRs** (from this repo's Actions tab):
1. Go to Actions → "Preview Environment" → Run workflow
2. Enter the repo (e.g., `signalwire-demos/my-app`) and PR number
3. Select action: `deploy` or `destroy`

## Scheduled Maintenance

The system runs daily maintenance tasks at **6 AM UTC** via `scheduled.yml`:

- **Orphan Cleanup**: Removes apps whose GitHub repos no longer exist or PR previews for closed PRs
- **SSL Renewal**: Auto-renews Let's Encrypt certificates
- **Health Checks**: Verifies all apps are responding

All task results are posted to Slack (if configured).

### Manual Trigger

Run maintenance tasks manually from the Actions tab:
```
Actions → Scheduled Maintenance → Run workflow
```
Options:
- `task`: Choose `all`, `cleanup-orphans`, `renew-certs`, or `health-check`
- `dry_run`: Preview what would be deleted (cleanup only)

### Required Secret: GH_ORG_TOKEN

Add `GH_ORG_TOKEN` to org secrets (fine-grained PAT with expanded permissions):

```bash
gh secret set GH_ORG_TOKEN \
  --org signalwire-demos \
  --visibility all \
  --body "github_pat_xxx"
```

This single token handles multiple system functions:
- **Cleanup**: Check if repos/PRs still exist before deletion
- **Preview Security**: Verify PR authors are org members
- **Dashboard Updates**: Push to gh-pages branch
- **Environment Creation**: Auto-create GitHub environments on deploy

## Manual App Cleanup

To manually destroy a specific app and its services:

```
Actions → Cleanup App → Run workflow
```
Options:
- `app_name`: App to destroy (also destroys -staging, -dev, and -pr-* variants)
- `include_services`: Also destroy linked services (default: true)
- `dry_run`: Preview what would be deleted without deleting
- `force`: Force delete even if GitHub repo still exists (dangerous!)

**Safety check**: The workflow verifies the GitHub repo doesn't exist before deleting.
If the repo still exists, cleanup is aborted unless `force=true`.

## Rollback

To rollback an app to a previous release:

```
Actions → Rollback → Run workflow
```
Options:
- `app_name`: App to rollback (defaults to repo name)
- `environment`: production, staging, or development
- `release`: Specific release version (leave empty for previous)
- `confirm`: Type "ROLLBACK" to confirm

## Deploy Locks

Block deployments during incidents, maintenance, or hotfix periods:

```
Actions → Deploy Lock → Run workflow
```
Options:
- `app_name`: App to lock/unlock
- `action`: `lock`, `unlock`, or `status`
- `reason`: Why the app is locked

When locked, all deployments (including previews) are blocked until unlocked.

**Via CLI:**
```bash
dokku-cli lock myapp "Hotfix in progress"
dokku-cli lock:status myapp
dokku-cli unlock myapp
```

## Release Tasks

Run post-deployment commands like database migrations automatically.

Add to your `.dokku/config.yml`:

```yaml
release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"
      timeout: 120
    - name: "Clear cache"
      command: "python manage.py clear_cache"
      timeout: 30
```

Tasks run after git push, before health check. If any task fails, the deployment fails.

## Scheduled Deployments

Schedule deployments for specific times - useful for off-hours deploys, coordinated releases, or change window compliance.

```
Actions → Schedule Deploy → Run workflow
```
Options:
- `action`: `schedule`, `cancel`, or `list`
- `repo`: Repository to deploy (e.g., `signalwire-demos/my-app`)
- `branch`: Branch to deploy (`main`, `staging`, etc.)
- `scheduled_time`: ISO 8601 time (e.g., `2025-12-15T03:00:00Z`)
- `schedule_id`: ID to cancel (for cancel action)

The scheduler runs every 15 minutes and triggers deployments when their scheduled time arrives.

## Audit Log

Comprehensive deployment history stored on gh-pages branch:

- **audit-log.json**: Machine-readable log of all deployments
- **audit-report.md**: Human-readable summary with statistics

Access the audit log at: `https://signalwire-demos.github.io/dokku-deploy-system/audit-log.json`

Logged events include:
- Deployments (success/failure)
- Preview environments (deploy/cleanup)
- Rollbacks
- Lock/unlock operations

## Commit Status Checks

Deployments automatically update commit status on GitHub:

- **Pending**: Shows while deployment is in progress
- **Success**: Links directly to the deployed app URL
- **Failure**: Links to the workflow run for debugging

Status contexts:
- `deploy/production` - Production deployments
- `deploy/staging` - Staging deployments
- `deploy/development` - Development deployments
- `preview/deploy` - Preview environment deployments

## Approval Gates

Require manual approval before deploying to production using GitHub's built-in environment protection.

### Setup

1. Go to your repo → **Settings** → **Environments** → **production**
2. Click **Required reviewers** and add team members
3. Optionally set a **Wait timer** (e.g., 5 minutes)
4. Optionally restrict **Deployment branches** to `main` only

When configured, production deployments will pause and wait for approval before proceeding.

## Security Scanning

Automatic vulnerability scanning with Trivy before every deployment.

### How It Works

1. **Trivy scans** all dependencies (npm, pip, go, etc.)
2. **Results summarized** in workflow summary
3. **Critical vulnerabilities block** deployment by default
4. **Artifacts uploaded** for detailed review

### Configuration

To disable blocking (allow deployment despite vulnerabilities), add to `.dokku/config.yml`:

```yaml
security:
  block_on_critical: false
```

To ignore specific vulnerabilities, create `.trivyignore`:

```
CVE-2023-12345
CVE-2023-67890
```

## Webhook Integrations

Send deployment notifications to external services.

### Custom Webhooks

Set `DEPLOY_WEBHOOK_URLS` (comma-separated) in GitHub secrets:

```
https://hooks.example.com/deploy,https://api.internal.com/events
```

Optionally set `DEPLOY_WEBHOOK_SECRET` for HMAC signature verification.

**Payload format:**
```json
{
  "event": "deployment",
  "app": "myapp",
  "environment": "production",
  "status": "success",
  "commit_sha": "abc1234...",
  "deployed_by": "username",
  "app_url": "https://myapp.domain.com",
  "workflow_url": "https://github.com/.../runs/123",
  "timestamp": "2025-12-11T15:00:00Z"
}
```

### Pre-configured Integrations

| Service | Secret | Description |
|---------|--------|-------------|
| Datadog | `DD_API_KEY` | Sends deployment events |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` | Alerts on failures |

## Database Backups

Automatic daily backups at 2 AM UTC with dual storage (local + S3), plus manual backups on demand.

**Scheduled Backups:**
- Runs daily for all apps with linked databases
- PostgreSQL and MySQL supported
- Dual storage: local server + S3 (if configured)

| Location | Retention | Cleanup |
|----------|-----------|---------|
| Server (`/var/backups/dokku/`) | 7 days | Workflow auto-deletes |
| S3 (`s3://{bucket}/{postgres,mysql}/{app}/`) | 30 days | S3 lifecycle rule |

**Manual Backup:**
```
Actions → Database Backup → Run workflow
```

**Via CLI:**
```bash
dokku-cli db myapp backup postgres           # Download locally
dokku-cli db myapp backup-server postgres    # Save to server
dokku-cli db myapp list-backups              # List available backups
dokku-cli db myapp restore backup.gz postgres
```

**Server Setup Required:**
```bash
sudo mkdir -p /var/backups/dokku/{postgres,mysql}
sudo chown -R dokku:dokku /var/backups/dokku
```

**S3 Setup (Optional but Recommended):**
Add these org secrets for S3 backup storage:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_S3_BUCKET`
- `AWS_REGION` (optional, defaults to us-east-1)

## Deploy Dashboard

Static HTML dashboard showing all deployed applications, updated automatically after each deployment.

**Dashboard URL:** `https://signalwire-demos.github.io/dokku-deploy-system/`

### Dashboard Setup

1. **Create the `gh-pages` branch:**
   ```bash
   cd dokku-deploy-system
   git checkout --orphan gh-pages
   git rm -rf .
   cp -r dashboard/* .
   git add .
   git commit -m "Initialize dashboard"
   git push origin gh-pages
   git checkout main
   ```

2. **Enable GitHub Pages:**
   - Go to repo Settings → Pages
   - Source: Deploy from branch
   - Branch: `gh-pages` / `root`
   - Save

3. **Grant workflow permissions:**
   - Go to repo Settings → Actions → General
   - Workflow permissions: Read and write permissions
   - Save

The dashboard auto-updates after:
- Each deployment (success or failure)
- Health checks (daily at 6 AM UTC)
- App cleanup

### Dashboard Features

- Real-time status of all apps (healthy/degraded/down)
- Environment filtering (production, staging, development, preview)
- Search functionality
- Response time metrics
- Last deploy timestamp and actor
- Auto-refresh every 5 minutes

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

### 4. Configure GitHub Secrets & Variables

**Org-Level Secrets** (Settings → Secrets and variables → Actions → Secrets):

| Secret | Value | Purpose |
|--------|-------|---------|
| `DOKKU_HOST` | `dokku.yourdomain.com` | Server hostname |
| `DOKKU_SSH_PRIVATE_KEY` | (generated private key) | SSH authentication |
| `GH_ORG_TOKEN` | (fine-grained PAT) | Multi-purpose org token (see below) |
| `SLACK_WEBHOOK_URL` | (optional) | Slack notifications |
| `DISCORD_WEBHOOK_URL` | (optional) | Discord notifications |
| `AWS_ACCESS_KEY_ID` | (optional) | S3 backup storage |
| `AWS_SECRET_ACCESS_KEY` | (optional) | S3 backup storage |
| `AWS_S3_BUCKET` | (optional) | S3 bucket name |

**Org-Level Variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Value | Purpose |
|----------|-------|---------|
| `BASE_DOMAIN` | `yourdomain.com` | Base domain for apps |

**Note**: `BASE_DOMAIN` is a variable (not secret) so URLs are visible in logs.

**Note**: Org-level secrets/variables are for **infrastructure only**. App-specific configuration uses Environment Variables (see below).

**GH_ORG_TOKEN**: A single fine-grained PAT that handles multiple functions:
- Preview security (check org membership)
- Dashboard updates (push to gh-pages)
- Environment creation (create production/staging/development/preview)
- Cleanup safety checks (verify repos exist)

Required permissions:
- **Repository**: Actions (R/W), Contents (R/W), Environments (R/W), Metadata (R), Pull requests (R/W)
- **Organization**: Members (R)

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

# Deploy locks
dokku-cli lock myapp "reason"
dokku-cli unlock myapp
dokku-cli lock:status myapp

# Database
dokku-cli db myapp create postgres
dokku-cli db myapp connect postgres
dokku-cli db myapp backup postgres
dokku-cli db myapp backup-server postgres
dokku-cli db myapp list-backups
dokku-cli db myapp restore backup.gz postgres

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
- [Features Guide](docs/FEATURES.md) - Deploy locks, release tasks, backups, dashboard
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
