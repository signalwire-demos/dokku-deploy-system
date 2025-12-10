# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub + Dokku auto-deployment system providing reusable workflows for the `signalwire-demos` organization. It enables automatic deployments, preview environments, SSL provisioning, and service management across all organization repos.

## Architecture

### Workflows (`.github/workflows/`)
- **deploy.yml**: Reusable deployment workflow called by other repos via `uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main`. Handles app creation, service provisioning, environment variables, and SSL.
- **preview.yml**: Reusable PR preview environment workflow. Creates temporary apps for each PR, auto-destroys on close.
- **scheduled.yml**: Daily maintenance (6 AM UTC) - orphan cleanup, SSL renewal, health checks. All results posted to Slack.
- **rollback.yml**: Manual rollback to previous releases. Requires typing "ROLLBACK" to confirm.

### Branch-to-Environment Mapping
- `main` → `{app}` (production) → `{app}.domain.com`
- `staging` → `{app}-staging` → `{app}-staging.domain.com`
- `develop` → `{app}-dev` → `{app}-dev.domain.com`
- PR #N → `{app}-pr-N` → `{app}-pr-N.domain.com`

### Project Configuration Files (in consuming repos)
- `.dokku/services.yml`: Define backing services (postgres, redis, mongo, mysql, rabbitmq, elasticsearch). Services auto-provision on deploy.
- `.dokku/config.yml`: Resource limits (memory, cpu), health check settings, scaling config, custom domains.
- `Procfile`: Process definitions (e.g., `web: uvicorn app:app --port $PORT`)
- `CHECKS`: Health check endpoint (e.g., `/health`)

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
