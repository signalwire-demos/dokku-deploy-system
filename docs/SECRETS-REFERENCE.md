# Secrets & Variables Reference

Complete reference of all GitHub secrets and variables used by the Dokku Deploy System.

---

## Table of Contents

- [Required Secrets](#required-secrets)
- [Optional Secrets by Category](#optional-secrets-by-category)
  - [Notifications](#notifications)
  - [AWS / Backups](#aws--backups)
  - [Preview Security](#preview-security)
  - [External Vault Integration](#external-vault-integration)
  - [Log Aggregation](#log-aggregation)
  - [Cost Tracking](#cost-tracking)
- [Required Variables](#required-variables)
- [Per-Region Secrets (Multi-Region)](#per-region-secrets-multi-region)
- [Setting Secrets via CLI](#setting-secrets-via-cli)
- [Workflow Usage Matrix](#workflow-usage-matrix)

---

## Required Secrets

These secrets must be configured at the organization level for the system to function.

| Secret | Purpose | Where Used |
|--------|---------|------------|
| `DOKKU_HOST` | Hostname/IP of Dokku server | All workflows |
| `DOKKU_SSH_PRIVATE_KEY` | SSH private key for Dokku access | All workflows |
| `GH_ORG_TOKEN` | Fine-grained PAT for GitHub API | Dashboard, cleanup, org membership checks, environments |

### Setting Required Secrets

```bash
# Set via gh CLI
gh secret set DOKKU_HOST --org signalwire-demos --visibility all --body "dokku.example.com"

# Set SSH key from file
gh secret set DOKKU_SSH_PRIVATE_KEY --org signalwire-demos --visibility all < ~/.ssh/dokku_deploy

# Set GitHub token
gh secret set GH_ORG_TOKEN --org signalwire-demos --visibility all --body "github_pat_..."
```

---

## Optional Secrets by Category

### Notifications

| Secret | Purpose | Used By |
|--------|---------|---------|
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL | deploy, preview, cleanup, scheduled, rollback, promote, canary |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL | deploy, preview, cleanup, scheduled, rollback, promote, canary |
| `DEPLOY_WEBHOOK_URLS` | Custom webhook URLs (comma-separated) | deploy |
| `DEPLOY_WEBHOOK_SECRET` | HMAC secret for webhook signatures | deploy |
| `DD_API_KEY` | Datadog API key for events | deploy, performance-monitor |
| `PAGERDUTY_ROUTING_KEY` | PagerDuty Events API v2 routing key | deploy, performance-monitor |

#### Slack Setup
1. Go to [Slack API](https://api.slack.com/apps)
2. Create app → Incoming Webhooks → Add to channel
3. Copy webhook URL

#### Discord Setup
1. Server Settings → Integrations → Webhooks
2. Create webhook, copy URL

#### Datadog Setup
1. Organization Settings → API Keys
2. Create new key, copy it

#### PagerDuty Setup
1. Services → Select service → Integrations
2. Add Events API v2 integration
3. Copy routing key

---

### AWS / Backups

| Secret | Purpose | Default | Used By |
|--------|---------|---------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | - | scheduled (backups), backup |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | scheduled (backups), backup |
| `AWS_S3_BUCKET` | S3 bucket name for backups | - | scheduled (backups) |
| `AWS_REGION` | AWS region | `us-east-1` | scheduled (backups), sync-secrets |

#### IAM Policy Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

---

### Preview Security

| Secret | Purpose | Used By |
|--------|---------|---------|
| `PREVIEW_AUTH_USER` | HTTP basic auth username for preview apps | preview |
| `PREVIEW_AUTH_PASSWORD` | HTTP basic auth password for preview apps | preview |

When set, all preview apps require HTTP basic auth to access.

---

### External Vault Integration

For `sync-secrets.yml` workflow:

#### AWS Secrets Manager

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key (shared with backups) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key (shared with backups) |
| `AWS_REGION` | AWS region (default: us-east-1) |

IAM permissions needed: `secretsmanager:GetSecretValue`

#### HashiCorp Vault

| Secret | Purpose |
|--------|---------|
| `VAULT_ADDR` | Vault server URL (e.g., `https://vault.example.com`) |
| `VAULT_TOKEN` | Vault token (alternative to AppRole) |
| `VAULT_ROLE_ID` | AppRole role ID |
| `VAULT_SECRET_ID` | AppRole secret ID |

Use either `VAULT_TOKEN` OR `VAULT_ROLE_ID` + `VAULT_SECRET_ID`.

#### 1Password

| Secret | Purpose |
|--------|---------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token |

Create service account at 1Password.com → Settings → Service Accounts.

---

### Log Aggregation

For `log-drain.yml` workflow:

| Secret | Purpose | Used By |
|--------|---------|---------|
| `PAPERTRAIL_HOST` | Papertrail syslog host | log-drain |
| `PAPERTRAIL_PORT` | Papertrail syslog port | log-drain |
| `LOGTAIL_TOKEN` | Logtail/Better Stack source token | log-drain |

---

### Cost Tracking

For `cost-report.yml` workflow:

| Secret | Purpose | Default |
|--------|---------|---------|
| `COST_CPU_RATE` | Cost per CPU-hour in USD | `0.01` |
| `COST_MEM_RATE` | Cost per GB-hour in USD | `0.005` |
| `COST_STORAGE_RATE` | Cost per GB-month in USD | `0.10` |
| `COST_BUDGET_MONTHLY` | Monthly budget for alerts | - |

When `COST_BUDGET_MONTHLY` is set, alerts trigger at 80% usage.

---

## Required Variables

Variables are set at organization level and are visible in logs (not masked).

| Variable | Purpose | Example |
|----------|---------|---------|
| `BASE_DOMAIN` | Base domain for app URLs | `dokku.signalwire.io` |

### Setting Variables

```bash
# Via gh CLI
gh api --method POST /orgs/signalwire-demos/actions/variables \
  -f name=BASE_DOMAIN \
  -f value="dokku.signalwire.io" \
  -f visibility=all
```

---

## Per-Region Secrets (Multi-Region)

For `multi-region-deploy.yml` with multiple servers:

| Pattern | Purpose | Example |
|---------|---------|---------|
| `DOKKU_HOST_{REGION}` | Server hostname per region | `DOKKU_HOST_US_EAST` |
| `DOKKU_SSH_KEY_{REGION}` | SSH key per region | `DOKKU_SSH_KEY_US_WEST` |
| `BASE_DOMAIN_{REGION}` | Domain per region | `BASE_DOMAIN_EU_WEST` |

Region names are derived from `.dokku/config.yml`:

```yaml
servers:
  us-east:    # -> DOKKU_HOST_US_EAST
    host: dokku-us-east.example.com
  us-west:    # -> DOKKU_HOST_US_WEST
    host: dokku-us-west.example.com
```

---

## Setting Secrets via CLI

### Org-Level Secrets

```bash
# Single value
gh secret set SECRET_NAME --org ORG_NAME --visibility all --body "value"

# From file
gh secret set SECRET_NAME --org ORG_NAME --visibility all < filename

# From environment variable
echo "$VALUE" | gh secret set SECRET_NAME --org ORG_NAME --visibility all
```

### Repo-Level Secrets

```bash
gh secret set SECRET_NAME --repo ORG/REPO --body "value"
```

### Environment Secrets

```bash
gh secret set SECRET_NAME --repo ORG/REPO --env production --body "value"
```

---

## Workflow Usage Matrix

Which secrets are used by which workflows:

| Secret | deploy | preview | scheduled | cleanup | rollback | promote | canary | multi-region | sync-secrets | log-drain | cost-report | perf-monitor |
|--------|--------|---------|-----------|---------|----------|---------|--------|--------------|--------------|-----------|-------------|--------------|
| `DOKKU_HOST` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | ✓ | ✓ | ✓ |
| `DOKKU_SSH_PRIVATE_KEY` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | ✓ | ✓ | ✓ |
| `GH_ORG_TOKEN` | ✓ | ✓ | ✓ | ✓ | | ✓ | ✓ | | ✓ | | | ✓ |
| `SLACK_WEBHOOK_URL` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | | ✓ | ✓ |
| `DISCORD_WEBHOOK_URL` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | | ✓ | ✓ |
| `AWS_*` (backups) | | | ✓ | | | | | | ✓ | | | |
| `DD_API_KEY` | ✓ | | | | | | | | | ✓ | | |
| `PAGERDUTY_ROUTING_KEY` | ✓ | | | | | | | | | | | ✓ |
| `PREVIEW_AUTH_*` | | ✓ | | | | | | | | | | |
| `VAULT_*` | | | | | | | | | ✓ | | | |
| `OP_SERVICE_ACCOUNT_TOKEN` | | | | | | | | | ✓ | | | |
| `PAPERTRAIL_*` | | | | | | | | | | ✓ | | |
| `LOGTAIL_TOKEN` | | | | | | | | | | ✓ | | |
| `COST_*` | | | | | | | | | | | ✓ | |

---

## Environment Variables vs Secrets

**Use GitHub Secrets for:**
- API keys and tokens
- Passwords and credentials
- SSH keys
- Webhook URLs (if you want them masked in logs)

**Use GitHub Environment Variables for:**
- App configuration (DATABASE_URL, API endpoints)
- Feature flags
- Non-sensitive settings

Environment variables are set per-environment (production, staging, development, preview) and flow to Dokku via `dokku config:set`.
