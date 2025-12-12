# Dokku Quick Reference

One-page reference for common operations.

---

## Branch → URL Mapping

```
main     → myapp.domain.com      (production)
staging  → myapp-staging.domain.com
develop  → myapp-dev.domain.com
PR #42   → myapp-pr-42.domain.com (auto-destroyed)
```

---

## Deployment

```bash
# Deploy to production
git push origin main

# Deploy to staging
git push origin staging

# Preview environment
# Just open a PR - automatic!

# Manual deploy via CLI
dokku-cli deploy myapp main
```

---

## App Management

```bash
# List all apps
dokku-cli list

# App info
dokku-cli info myapp

# Create app
dokku-cli create myapp

# Delete app (⚠️ destructive)
dokku-cli destroy myapp

# Restart
dokku-cli restart myapp

# Scale
dokku-cli scale myapp web=2
```

---

## Logs

```bash
# View recent logs
dokku-cli logs myapp

# Follow logs (live)
dokku-cli logs:follow myapp

# Last N lines
dokku-cli logs myapp --num 50

# Direct SSH
ssh dokku@server logs myapp -t
```

---

## Configuration

```bash
# View all env vars
dokku-cli config myapp

# Set variables
dokku-cli config:set myapp KEY=value DEBUG=true

# Remove variable
dokku-cli config:unset myapp KEY

# Direct SSH
ssh dokku@server config:set myapp KEY=value
```

---

## Database

```bash
# Create & link PostgreSQL
dokku-cli db myapp create postgres

# Connect to database shell
dokku-cli db myapp connect postgres

# Backup database
dokku-cli db myapp backup postgres

# View info
dokku-cli db myapp info postgres

# Direct commands
ssh dokku@server postgres:connect postgres-myapp
ssh dokku@server postgres:export postgres-myapp > backup.dump
ssh dokku@server postgres:import postgres-myapp < backup.dump
```

---

## SSL & Domains

```bash
# Check SSL status
dokku-cli ssl myapp

# Enable SSL
dokku-cli ssl myapp enable

# List domains
dokku-cli domains myapp

# Add custom domain
dokku-cli domains add myapp www.example.com

# Remove domain
dokku-cli domains remove myapp www.example.com

# Direct SSH
ssh dokku@server letsencrypt:enable myapp
ssh dokku@server domains:add myapp www.example.com
```

---

## Rollback

```bash
# View releases
dokku-cli releases myapp

# Rollback to previous
dokku-cli rollback myapp

# Rollback to specific version
dokku-cli rollback myapp v3

# Via GitHub Actions
# Actions → Rollback → Run workflow
```

---

## Run Commands

```bash
# One-off command
dokku-cli run myapp python manage.py migrate

# Interactive shell
dokku-cli shell myapp

# Direct SSH
ssh dokku@server run myapp python manage.py shell
ssh dokku@server enter myapp web
```

---

## Services (Direct SSH)

```bash
# PostgreSQL
dokku postgres:create db-name
dokku postgres:link db-name myapp
dokku postgres:unlink db-name myapp
dokku postgres:destroy db-name --force

# Redis
dokku redis:create redis-name
dokku redis:link redis-name myapp

# List all
dokku postgres:list
dokku redis:list
```

---

## NGINX & Proxy

```bash
# View NGINX config
ssh dokku@server nginx:show-config myapp

# Rebuild config
ssh dokku@server nginx:build-config myapp

# View ports
ssh dokku@server proxy:ports myapp

# Set custom port
ssh dokku@server proxy:ports-set myapp http:80:5000
```

---

## Resource Limits

```bash
# View limits
ssh dokku@server resource:report myapp

# Set limits
ssh dokku@server resource:limit myapp --memory 512m --cpu 1

# Clear limits
ssh dokku@server resource:limit-clear myapp
```

---

## Troubleshooting

```bash
# Full app report
ssh dokku@server report myapp

# Check process status
ssh dokku@server ps:report myapp

# View NGINX errors
ssh dokku@server nginx:error-logs myapp

# Check health endpoint
curl -I https://myapp.domain.com/health

# Test locally what Dokku sees
ssh dokku@server run myapp env
```

---

## GitHub Configuration (Infrastructure)

**Secrets:**
| Secret | Description |
|--------|-------------|
| `DOKKU_HOST` | Server hostname |
| `DOKKU_SSH_PRIVATE_KEY` | Deploy SSH key |
| `GH_ORG_TOKEN` | Multi-purpose PAT (dashboard, environments, cleanup, preview security) |
| `SLACK_WEBHOOK_URL` | Slack notifications (optional) |
| `DISCORD_WEBHOOK_URL` | Discord notifications (optional) |
| `DEPLOY_WEBHOOK_URLS` | Custom webhook URLs, comma-separated (optional) |
| `DEPLOY_WEBHOOK_SECRET` | HMAC secret for webhook signatures (optional) |
| `DD_API_KEY` | Datadog API key (optional) |
| `PAGERDUTY_ROUTING_KEY` | PagerDuty routing key (optional) |
| `AWS_ACCESS_KEY_ID` | AWS credentials for S3 backups (optional) |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials for S3 backups (optional) |
| `AWS_S3_BUCKET` | S3 bucket for backups (optional) |
| `AWS_REGION` | AWS region (optional, default: us-east-1) |

**Variables (org-level):**
| Variable | Description |
|----------|-------------|
| `BASE_DOMAIN` | Base domain for apps (required) |

**Optional Secrets (integrations):**
| Secret | Description |
|--------|-------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token |
| `PAPERTRAIL_HOST` | Papertrail syslog host |
| `PAPERTRAIL_PORT` | Papertrail syslog port |
| `LOGTAIL_TOKEN` | Logtail/Better Stack token |
| `COST_CPU_RATE` | CPU cost per core-hour, default $0.01 |
| `COST_MEM_RATE` | Memory cost per GB-hour, default $0.005 |
| `COST_STORAGE_RATE` | Storage cost per GB-month, default $0.10 |
| `COST_BUDGET_MONTHLY` | Monthly budget for alerts |

---

## GitHub Environment Variables (App Config)

Configure in: Repo → Settings → Environments → [env] → Environment variables

| Variable | Example |
|----------|---------|
| `SIGNALWIRE_SPACE_NAME` | `myspace` |
| `SIGNALWIRE_PROJECT_ID` | `abc-123` |
| `SIGNALWIRE_TOKEN` | `PTxxx` |
| `RAPIDAPI_KEY` | `xxx` |

```bash
# Add variable via CLI
gh api repos/ORG/REPO/environments/production/variables \
  -X POST -f name=VAR_NAME -f value=VAR_VALUE

# List variables
gh api repos/ORG/REPO/environments/production/variables \
  --jq '.variables[].name'
```

**Note**: Variables (not secrets) are used for app config because:
- They're visible in logs for debugging
- They can be edited after creation
- The workflow clears and resets all config on each deploy

---

## Required Files

```
Procfile           # web: uvicorn app:app --port $PORT
runtime.txt        # python-3.11
requirements.txt   # Dependencies
CHECKS             # /health
.dokku/services.yml # Service config
```

---

## Health Check (Required)

Your app must respond to `/health` with HTTP 200:

```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

---

## Cleanup

```bash
# Manual cleanup via GitHub Actions
# Go to: dokku-deploy-system → Actions → Cleanup App → Run workflow
# Options:
#   - app_name: App to destroy
#   - dry_run: Preview only (default: false)
#   - include_services: Also destroy services (default: true)
#   - force: Override safety check (default: false)
#
# Safety: Aborts if repo still exists (unless force=true)

# Automatic cleanup runs daily at 6 AM UTC:
# - Removes apps whose repos no longer exist
# - Removes PR previews for closed PRs
# - Cleans up all associated services

# Direct SSH cleanup (use with caution)
ssh dokku@server apps:destroy myapp --force
ssh dokku@server postgres:destroy postgres-myapp --force
ssh dokku@server redis:destroy redis-myapp --force
```

---

## CLI Command ↔ Workflow Cross-Reference

Many CLI commands have corresponding GitHub Actions workflows. Use CLI for quick operations; use workflows for automation and audit trails.

| CLI Command | GitHub Workflow | Notes |
|-------------|-----------------|-------|
| `deploy` | **deploy.yml** | Workflow adds security scan, release tracking, dashboard update |
| `rollback` | **rollback.yml** | Workflow has pre-rollback backup option |
| `lock`, `unlock` | **lock.yml** | Workflow can trigger via Actions UI |
| `destroy` | **cleanup.yml** | Workflow has safety checks, service cleanup |
| `db backup` | **backup.yml** | Workflow streams to S3, scheduled daily |
| `ssl enable` | **scheduled.yml** | Workflow handles auto-renewal |
| `scale` | **autoscaler.yml** | Workflow provides auto-scaling based on metrics |
| `releases` | — | Reads data set by deploy.yml |
| `config` | — | deploy.yml syncs from GitHub Environment Variables |
| `logs` | — | Direct SSH only |
| `shell`, `run` | — | Direct SSH only |
| `restart`, `start`, `stop` | — | Direct SSH only |
| `domains` | — | Use `.dokku/config.yml` custom_domains for automation |

**When to use which:**

| Scenario | Recommendation |
|----------|----------------|
| Quick debugging | CLI (`logs`, `shell`, `run`) |
| Production deploy | Workflow (audit trail, security scan) |
| Hotfix with rollback | CLI `rollback` (faster) or workflow (backup first) |
| Block deployments | CLI `lock` (immediate) or workflow (recorded) |
| Database backup | Workflow (S3 storage, retention) |
| One-off migration | CLI `run` |
| Recurring tasks | Workflow (scheduled) |

---

## Help

- Slack: #deployments
- Wiki: /wiki/dokku
- CLI: `dokku-cli help`
