# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub + Dokku auto-deployment system providing reusable workflows for the `signalwire-demos` organization. It enables automatic deployments, preview environments, SSL provisioning, and service management across all organization repos.

## Architecture

### Workflow Interconnections
```
deploy.yml ──────┬──→ update-dashboard.yml
preview.yml ─────┤
cleanup.yml ─────┤
scheduled.yml ───┘
     │
     └──→ health checks, backups, SSL renewal
```

**Reusable workflows** (called by other repos via `uses:`):
- **deploy.yml**: Main deployment - app creation, service provisioning, env vars, release tasks, SSL, dashboard update
- **preview.yml**: PR preview environments - creates temp apps, auto-destroys on PR close
  - **Security**: Only auto-deploys for org members. External PRs require manual trigger.
- **update-dashboard.yml**: Updates `gh-pages` branch with app status (called by deploy/preview/cleanup/scheduled)

**Standalone workflows** (run in this repo only):
- **scheduled.yml**: Daily maintenance (6 AM UTC) - orphan cleanup, SSL renewal, health checks; backups (2 AM UTC)
- **cleanup.yml**: Manual app destruction with safety checks
- **rollback.yml**: Manual rollback (requires typing "ROLLBACK" to confirm)
- **lock.yml**: Deploy lock management
- **backup.yml**: Manual database backup

### Branch-to-Environment Mapping
- `main` → `{app}` (production) → `{app}.domain.com`
- `staging` → `{app}-staging` → `{app}-staging.domain.com`
- `develop` → `{app}-dev` → `{app}-dev.domain.com`
- PR #N → `{app}-pr-N` → `{app}-pr-N.domain.com`

### Configuration Files (in consuming repos)
- `.dokku/services.yml`: Define backing services (postgres, redis, mongo, mysql, rabbitmq, elasticsearch)
- `.dokku/config.yml`: Resource limits, health checks, scaling, custom domains, release tasks, backup config
- `Procfile`: Process definitions (e.g., `web: uvicorn app:app --port $PORT`)
- `CHECKS`: Health check endpoint (e.g., `/health`)

### Dashboard Data Structure (`dashboard/apps.json`)
```json
{
  "last_updated": "ISO8601",
  "apps": [{
    "name": "app-name",
    "status": "running|stopped|success|failure",
    "environment": "production|staging|development|preview",
    "url": "https://app.domain.com",
    "last_deploy": "ISO8601",
    "last_deploy_by": "github-user",
    "commit_sha": "abc1234",
    "uptime": {
      "status": "healthy|unhealthy|unknown",
      "uptime_seconds": 12345,
      "response_time_ms": 150,
      "last_check": "ISO8601"
    }
  }]
}
```

### Server Setup (`server-setup/`)
Run on fresh Ubuntu 22.04: `sudo ./setup-all.sh` or individually: `01-server-init.sh` → `02-dokku-install.sh` → `03-dokku-plugins.sh` → `04-letsencrypt-setup.sh` → `05-global-config.sh` → `06-server-hardening.sh`

### CLI Tool (`cli/dokku-cli`)
Bash wrapper for Dokku operations. Config stored in `~/.dokku-cli`.

## Development

This repo contains no buildable code - it's shell scripts and YAML workflows. To validate changes:

```bash
# Validate YAML syntax
yamllint .github/workflows/*.yml

# Check shell scripts
shellcheck cli/dokku-cli scripts/*.sh server-setup/*.sh

# Test workflow changes by pushing to a branch and triggering manually via Actions tab
```

Changes to reusable workflows (`deploy.yml`, `preview.yml`) affect all consuming repos immediately when merged to `main`.

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

## Preview Security

Preview deployments are restricted to org members to prevent malicious code from being auto-deployed via fork PRs.

**For org members**: PRs auto-deploy previews as usual.

**For external contributors**: The workflow posts a comment explaining that a maintainer must manually trigger the preview.

**Manual trigger for external PRs** (org members only):
1. Go to [Actions → Preview Environment](../../actions/workflows/preview.yml)
2. Click "Run workflow"
3. Enter the repo (e.g., `signalwire-demos/my-app`) and PR number
4. Select action: `deploy` or `destroy`

Requires `GH_ORG_TOKEN` secret with `read:org` scope for org membership checks.
