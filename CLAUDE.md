# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub + Dokku auto-deployment system providing reusable workflows for the `signalwire-demos` organization. It enables automatic deployments, preview environments, SSL provisioning, and service management across all organization repos.

## Architecture

### Workflows (`.github/workflows/`)
- **deploy.yml**: Reusable deployment workflow. Handles app creation, service provisioning, environment variables, release tasks, SSL, and dashboard updates.
- **preview.yml**: Reusable PR preview environment workflow. Creates temporary apps for each PR, auto-destroys on close.
- **scheduled.yml**: Daily maintenance (6 AM UTC) - orphan cleanup, SSL renewal, health checks with response times, database backups (2 AM UTC).
- **cleanup.yml**: Manual app destruction with safety checks and pre-destroy backups.
- **rollback.yml**: Manual rollback with pre-rollback backups. Requires typing "ROLLBACK" to confirm.
- **lock.yml**: Deploy lock management - lock/unlock apps to block deployments during incidents.
- **backup.yml**: Manual database backup workflow for postgres, mysql, redis, mongo.
- **update-dashboard.yml**: Updates the GitHub Pages deployment dashboard.

### Branch-to-Environment Mapping
- `main` → `{app}` (production) → `{app}.domain.com`
- `staging` → `{app}-staging` → `{app}-staging.domain.com`
- `develop` → `{app}-dev` → `{app}-dev.domain.com`
- PR #N → `{app}-pr-N` → `{app}-pr-N.domain.com`

### Project Configuration Files (in consuming repos)
- `.dokku/services.yml`: Define backing services (postgres, redis, mongo, mysql, rabbitmq, elasticsearch). Services auto-provision on deploy.
- `.dokku/config.yml`: Resource limits, health check settings, scaling config, custom domains, **release tasks**, **backup config**.
- `Procfile`: Process definitions (e.g., `web: uvicorn app:app --port $PORT`)
- `CHECKS`: Health check endpoint (e.g., `/health`)

### Advanced Features
- **Deploy Locks**: Lock apps to block deployments during incidents (`lock.yml`, CLI: `dokku-cli lock/unlock`)
- **Release Tasks**: Run post-deploy commands (migrations, cache clear) defined in `config.yml`
- **Database Backups**: Scheduled (2 AM UTC) + manual, stored at `/var/backups/dokku/`
- **Deploy Dashboard**: GitHub Pages dashboard at `https://signalwire-demos.github.io/dokku-deploy-system/`
- **Uptime Monitoring**: Health checks capture response times, shown on dashboard

### Server Setup Scripts (`server-setup/`)
Run sequentially on fresh Ubuntu 22.04: `01-server-init.sh` → `02-dokku-install.sh` → `03-dokku-plugins.sh` → `04-letsencrypt-setup.sh` → `05-global-config.sh` → `06-server-hardening.sh`

Or run all at once: `sudo ./setup-all.sh`

### CLI Tool (`cli/dokku-cli`)
Bash wrapper for common Dokku operations. Config stored in `~/.dokku-cli`.

## Common Commands

```bash
# Initialize a new project with Dokku deployment files
./scripts/init-repo.sh /path/to/project

# Generate SSH deploy key
./scripts/generate-deploy-key.sh

# CLI setup and usage
dokku-cli setup
dokku-cli list
dokku-cli logs myapp
dokku-cli deploy myapp main

# Deploy lock management
dokku-cli lock myapp "hotfix in progress"
dokku-cli unlock myapp
dokku-cli lock:status myapp

# Database backup/restore
dokku-cli db myapp backup postgres        # Local file
dokku-cli db myapp backup-server postgres # Server storage
dokku-cli db myapp restore backup.dump postgres
dokku-cli db myapp list-backups
```

## GitHub Configuration

### Required Org-Level Secrets
- `DOKKU_HOST`: Dokku server hostname
- `DOKKU_SSH_PRIVATE_KEY`: SSH key for deployments
- `BASE_DOMAIN`: Base domain for apps

### App Configuration
Use **GitHub Environment Variables** (not secrets) for app-specific config. Set in: Repo → Settings → Environments → [env] → Environment variables. The workflow clears and resets Dokku config on each deploy using `toJSON(vars)`.

### GitHub Environments
Created automatically by workflows: `production`, `staging`, `development`, `preview`

## Key Implementation Details

- Workflows auto-detect runtime (Node.js, Python, Ruby, Go) and run appropriate tests
- Environment variables flow: GitHub Environment Variables → workflow reads via `toJSON(vars)` → `dokku config:clear` + `config:set`
- Services use naming convention: `{service}-{app-name}` (e.g., `postgres-myapp`)
- Preview apps can use shared services (`shared: true` in services.yml) to save resources
- SSL enabled via Let's Encrypt after health check passes (HTTP first, then HTTPS)
- Scheduled maintenance has safety check: won't delete apps if corresponding GitHub repo still exists
