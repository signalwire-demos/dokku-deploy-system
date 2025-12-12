# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub + Dokku auto-deployment system providing reusable workflows for the `signalwire-demos` organization. It enables automatic deployments, preview environments, SSL provisioning, and service management across all organization repos.

## Architecture

### Workflow Interconnections
```
deploy.yml ──────┬──→ update-dashboard.yml ──→ gh-pages
preview.yml ─────┤         │
cleanup.yml ─────┤         ├──→ audit-log.yml ──→ gh-pages
scheduled.yml ───┘         │
     │                     └──→ apps.json, audit-log.json
     └──→ health checks, backups (S3), SSL renewal, Docker cleanup
```

### Reusable Workflows (called by other repos)

| Workflow | Purpose |
|----------|---------|
| **deploy.yml** | Main deployment - app creation, services, env vars, resource limits, security scan, release tracking, SSL |
| **preview.yml** | PR preview environments - auto-deploy for org members, auto-destroy on PR close |
| **update-dashboard.yml** | Updates gh-pages with app status |
| **audit-log.yml** | Records deployment audit trail |

#### Workflow Inputs

**deploy.yml** accepts these optional inputs when called:
```yaml
uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main
with:
  health_check_path: '/health'  # Health check endpoint (default: /health)
  memory_limit: '512m'          # Memory limit override
  cpu_limit: '1'                # CPU limit override
secrets: inherit
```

**preview.yml** accepts these optional inputs:
```yaml
uses: signalwire-demos/dokku-deploy-system/.github/workflows/preview.yml@main
with:
  memory_limit: '256m'  # Memory limit for preview apps (default: 256m)
  cpu_limit: '0.5'      # CPU limit for preview apps (default: 0.5)
secrets: inherit
```

### Standalone Workflows (this repo only)

| Workflow | Purpose | Schedule |
|----------|---------|----------|
| **scheduled.yml** | Orphan cleanup, SSL renewal, health checks, Docker cleanup | Daily 6 AM UTC |
| **scheduled.yml** | Database backups (S3) | Daily 2 AM UTC |
| **cleanup.yml** | Manual app destruction with safety checks | Manual |
| **rollback.yml** | Rollback to previous release version | Manual |
| **lock.yml** | Deploy lock management | Manual |
| **backup.yml** | Manual database backup | Manual |
| **cost-report.yml** | Resource usage & cost tracking | Weekly/Monthly |
| **performance-monitor.yml** | Response time & availability metrics | Every 15 min |
| **update-repo-list.yml** | Cache of deployable repos | Every 6 hours |

### Advanced Workflows (available but less commonly used)

| Workflow | Purpose |
|----------|---------|
| **canary-deploy.yml** | Gradual traffic shifting for canary releases |
| **promote.yml** | Promote builds between environments |
| **autoscaler.yml** | Auto-scale based on metrics |
| **multi-region-deploy.yml** | Deploy to multiple regions |
| **schedule-deploy.yml** | Schedule deployments for specific times |
| **sync-secrets.yml** | Sync secrets across repos |
| **log-drain.yml** | Configure centralized logging |

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

This repo contains no buildable code - it's shell scripts and YAML workflows.

### Validation

The repo includes automated validation via `.github/workflows/validate.yml` which runs on PRs:
- **yamllint**: YAML syntax validation
- **actionlint**: GitHub Actions workflow validation
- **shellcheck**: Shell script linting
- **config validation**: Template config file checks

### Local Validation

```bash
# Install pre-commit hooks (recommended)
pip install pre-commit
pre-commit install

# Run all checks manually
pre-commit run --all-files

# Or run individual tools
yamllint -c .yamllint.yml .github/workflows/*.yml
shellcheck cli/dokku-cli scripts/*.sh server-setup/*.sh
```

### Testing Changes

Test workflow changes by pushing to a branch and triggering manually via the Actions tab.

**Important:** Changes to reusable workflows (`deploy.yml`, `preview.yml`) affect all consuming repos immediately when merged to `main`.

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
| Secret | Purpose |
|--------|---------|
| `DOKKU_HOST` | Dokku server hostname |
| `DOKKU_SSH_PRIVATE_KEY` | SSH private key for deployments |
| `GH_ORG_TOKEN` | Fine-grained PAT for cross-repo operations (dashboard, cleanup, org membership checks) |

### Optional Org-Level Secrets

#### Notifications
| Secret | Purpose |
|--------|---------|
| `SLACK_WEBHOOK_URL` | Slack notifications for deploys, alerts |
| `DISCORD_WEBHOOK_URL` | Discord notifications for deploys, alerts |
| `DEPLOY_WEBHOOK_URLS` | Custom webhook URLs (comma-separated) for deploy events |
| `DEPLOY_WEBHOOK_SECRET` | HMAC secret for signing webhook payloads |
| `DD_API_KEY` | Datadog API key for deploy events and metrics |
| `PAGERDUTY_ROUTING_KEY` | PagerDuty routing key for failure alerts |

#### AWS (Backups)
| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | S3 backup uploads |
| `AWS_SECRET_ACCESS_KEY` | S3 backup uploads |
| `AWS_S3_BUCKET` | S3 bucket name for backups |
| `AWS_REGION` | AWS region (default: us-east-1) |

#### Preview Environment
| Secret | Purpose |
|--------|---------|
| `PREVIEW_AUTH_USER` | HTTP basic auth username for preview apps |
| `PREVIEW_AUTH_PASSWORD` | HTTP basic auth password for preview apps |

#### External Vault Integration (sync-secrets.yml)
| Secret | Purpose |
|--------|---------|
| `VAULT_ADDR` | HashiCorp Vault server URL |
| `VAULT_TOKEN` | Vault token (alternative to AppRole) |
| `VAULT_ROLE_ID` | Vault AppRole role ID |
| `VAULT_SECRET_ID` | Vault AppRole secret ID |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token |

#### Log Aggregation (log-drain.yml)
| Secret | Purpose |
|--------|---------|
| `PAPERTRAIL_HOST` | Papertrail syslog host |
| `PAPERTRAIL_PORT` | Papertrail syslog port |
| `LOGTAIL_TOKEN` | Logtail/Better Stack source token |

#### Cost Tracking (cost-report.yml)
| Secret | Purpose |
|--------|---------|
| `COST_CPU_RATE` | Cost per CPU-hour (default: 0.01) |
| `COST_MEM_RATE` | Cost per GB-hour (default: 0.005) |
| `COST_STORAGE_RATE` | Cost per GB-month (default: 0.10) |
| `COST_BUDGET_MONTHLY` | Monthly budget for alerts |

### Required Org-Level Variables
| Variable | Purpose |
|----------|---------|
| `BASE_DOMAIN` | Base domain for apps (e.g., `dokku.signalwire.io`) |

Set at: Organization → Settings → Secrets and variables → Actions → Variables tab

Note: Using variables instead of secrets means URLs will be visible in logs (not masked).

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
- Docker cleanup runs daily using `dokku cleanup` command
- Resource limits and scaling configured via `.dokku/config.yml` or workflow inputs
- Security scanning via Trivy - blocks deploys with critical vulnerabilities (configurable)

## Security Scanning

Every deploy runs a Trivy vulnerability scan on dependencies:
- Scans for CRITICAL, HIGH, and MEDIUM severity issues
- Results shown in GitHub Actions step summary
- Critical vulnerabilities block deploy by default

To ignore false positives, create `.trivyignore` in repo root:
```
CVE-2023-12345
CVE-2023-67890
```

To disable blocking, add to `.dokku/config.yml`:
```yaml
security:
  block_on_critical: false
```

## Release Tracking

Each deploy creates an incrementing release version (v1, v2, v3...) stored in Dokku config:
- `RELEASE_VERSION`: Current version number
- `RELEASE_HISTORY_B64`: Base64-encoded JSON of last 10 releases

Use the CLI to view releases and rollback:
```bash
dokku-cli releases myapp       # List release history
dokku-cli rollback myapp v3    # Rollback to specific version
```

## Database Backups

Backups run daily at 2 AM UTC and stream directly to S3:

| Location | Retention | Cleanup |
|----------|-----------|---------|
| S3 (`s3://{bucket}/{postgres,mysql}/{app}/`) | 30 days | S3 lifecycle rule |

The workflow streams `dokku postgres:export | gzip` directly to S3 without local storage.

Manual backup via CLI:
```bash
dokku-cli db myapp backup postgres           # Download locally
```

Requires AWS secrets configured (see GitHub Configuration above).

## gh-pages Branch

The `gh-pages` branch stores dashboard data. Multiple workflows write to it:
- `update-dashboard.yml`: App status after deploys
- `audit-log.yml`: Deployment audit trail
- `cost-report.yml`: Resource usage reports
- `update-repo-list.yml`: Deployable repos cache
- `performance-monitor.yml`: Response time metrics

All workflows use retry with `git pull --rebase` to handle concurrent updates.

## Preview Security

Preview deployments are restricted to org members to prevent malicious code from being auto-deployed via fork PRs.

**For org members**: PRs auto-deploy previews as usual.

**For external contributors**: The workflow posts a comment explaining that a maintainer must manually trigger the preview.

**Manual trigger for external PRs** (org members only):
1. Go to [Actions → Preview Environment](../../actions/workflows/preview.yml)
2. Click "Run workflow"
3. Enter the repo (e.g., `signalwire-demos/my-app`) and PR number
4. Select action: `deploy` or `destroy`

Requires `GH_ORG_TOKEN` secret (fine-grained PAT with org members read + repo permissions for dashboard, environments, and cleanup).
