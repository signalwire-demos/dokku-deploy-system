# Feature Documentation

This document describes the advanced features available in the Dokku Deploy System.

## Table of Contents

- [Preview Security](#preview-security)
- [Deploy Locks](#deploy-locks)
- [Release Tasks](#release-tasks)
- [Database Backups](#database-backups)
- [Deploy Dashboard](#deploy-dashboard)
- [Enhanced Notifications](#enhanced-notifications)
- [Commit Status Checks](#commit-status-checks)
- [Scheduled Deployments](#scheduled-deployments)
- [Audit Log](#audit-log)
- [Approval Gates](#approval-gates)
- [Security Scanning](#security-scanning)
- [Webhook Integrations](#webhook-integrations)
- [Environment Promotion](#environment-promotion)
- [Custom Domains](#custom-domains)
- [Secrets Management](#secrets-management)
- [Canary Deployments](#canary-deployments)
- [Multi-Region Deployment](#multi-region-deployment)
- [Resource Auto-Scaling](#resource-auto-scaling)
- [Log Aggregation](#log-aggregation)
- [Performance Monitoring](#performance-monitoring)
- [Cost Tracking](#cost-tracking)
- [CLI Tool](#cli-tool)

---

## Preview Security

Prevent malicious code from being auto-deployed via fork PRs by restricting auto-deploys to org members only.

### How It Works

When a pull request is opened:

1. **Setup job** checks if the PR author is an org member
2. **Org members**: Preview deploys automatically (existing behavior)
3. **External contributors**:
   - Auto-deploy is skipped
   - A comment is posted explaining how to manually trigger the preview
   - Org members can manually deploy from the Actions tab

### Required Secret

The `GH_ORG_TOKEN` org secret (a fine-grained PAT) is required for org membership checks. This is the same token used for dashboard updates, environment creation, and cleanup. See [SETUP-GUIDE.md](./SETUP-GUIDE.md#54-set-gh_org_token-required) for full configuration.

### Manual Trigger for External PRs

Org members can manually deploy previews for external contributors:

1. Go to [Actions → Preview Environment](https://github.com/signalwire-demos/dokku-deploy-system/actions/workflows/preview.yml)
2. Click "Run workflow"
3. Enter:
   - **Repository**: e.g., `signalwire-demos/my-app`
   - **PR number**: e.g., `42`
   - **Action**: `deploy` or `destroy`

### PR Comment

When an external contributor's PR is blocked from auto-deploying, they see a comment like:

> **🔒 Preview Deployment Requires Approval**
>
> Since you're not a member of this organization, preview deployments require manual approval from a maintainer.
>
> **Maintainers:** To deploy a preview for this PR, go to:
> Actions → Preview Environment → Run workflow

### Security Considerations

- Cleanup still runs automatically on PR close (regardless of author)
- The check runs before any code from the PR is executed
- Manual triggers can only be initiated by users with workflow dispatch permissions (org members)

---

## Deploy Locks

Prevent deployments during incidents, maintenance windows, or hotfix periods.

### How It Works

Lock state is stored as Dokku config variables on the app:
- `DEPLOY_LOCKED`: true/false
- `DEPLOY_LOCK_REASON`: Human-readable reason
- `DEPLOY_LOCK_BY`: Who locked the app
- `DEPLOY_LOCK_AT`: Timestamp

When locked, all deployments (including previews for the base app) are blocked.

### Usage

#### Via GitHub Actions Workflow

1. Go to Actions > "Deploy Lock"
2. Select action: `lock`, `unlock`, or `status`
3. Enter the app name
4. For lock action, provide a reason

#### Via CLI

```bash
# Lock an app
dokku-cli lock myapp "Hotfix deployment in progress"

# Check lock status
dokku-cli lock:status myapp

# Unlock an app
dokku-cli unlock myapp
```

#### Via Direct SSH

```bash
# Lock
ssh dokku config:set myapp DEPLOY_LOCKED=true DEPLOY_LOCK_REASON="maintenance"

# Unlock
ssh dokku config:unset myapp DEPLOY_LOCKED DEPLOY_LOCK_REASON
```

### Notifications

Slack notifications are sent when apps are locked or unlocked.

---

## Release Tasks

Run post-deployment commands like database migrations, cache clearing, or asset compilation.

### Configuration

Add to your `.dokku/config.yml`:

```yaml
release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"
      timeout: 120  # seconds (default: 120)

    - name: "Clear cache"
      command: "python manage.py clear_cache"
      timeout: 30

    - name: "Collect static files"
      command: "python manage.py collectstatic --no-input"
```

### Environment-Specific Tasks

Override tasks for specific environments:

```yaml
release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"

environments:
  preview:
    release:
      tasks:
        - name: "Seed demo data"
          command: "python manage.py seed_demo"
```

### Behavior

- Tasks run after git push, before health check
- If any task fails, the deployment fails
- Task output is visible in workflow logs
- Each task has a configurable timeout

---

## Database Backups

Automatic and manual database backups with retention policy.

### Storage Location

Backups are stored on the Dokku server at:
```
/var/backups/dokku/{service}/{app}/YYYYMMDD_HHMMSS.gz
```

### Server Setup

First-time setup on the Dokku server:

```bash
sudo mkdir -p /var/backups/dokku/{postgres,mysql,redis,mongo,rabbitmq,elasticsearch}
sudo chown -R dokku:dokku /var/backups/dokku
```

### Scheduled Backups

Runs daily at 2 AM UTC via `scheduled.yml`:
- Backs up all linked PostgreSQL and MySQL databases
- Skips preview apps (they use shared databases)
- Streams directly to S3 (no local storage required)

| Location | Retention | Cleanup |
|----------|-----------|---------|
| S3 (`s3://{bucket}/{postgres,mysql}/{app}/`) | 30 days | S3 lifecycle rule |

**S3 Setup (Required):** Add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_S3_BUCKET` to org secrets.

### Manual Backups

#### Via GitHub Actions

1. Go to Actions > "Database Backup"
2. Enter app name (or leave empty for all apps)
3. Select service type (all, postgres, mysql, redis, mongo)

#### Via CLI

```bash
# Backup to local file
dokku-cli db myapp backup postgres
# Creates: myapp-20231210_153000.dump

# List available backups
dokku-cli db myapp list-backups
```

### Restore

```bash
# Restore from local file
dokku-cli db myapp restore myapp-20231210.dump postgres

# Restore from gzipped file
dokku-cli db myapp restore myapp-20231210.gz postgres
```

### Pre-Destructive Backups

Automatic backups are created before:
- App cleanup (cleanup.yml)
- Rollback operations (rollback.yml)

These are tagged with `pre-destroy_` or `pre-rollback_` prefix.

---

## Deploy Dashboard

Static HTML dashboard showing all deployed applications.

### Access

Dashboard URL: `https://signalwire-demos.github.io/dokku-deploy-system/`

### Features

- Real-time status of all apps
- Environment filtering (production, staging, development, preview)
- Search functionality
- Response time metrics
- Last deploy information
- Auto-refresh every 5 minutes

### Setup

1. Create `gh-pages` branch:
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   cp -r dashboard/* .
   git add .
   git commit -m "Initialize dashboard"
   git push origin gh-pages
   ```

2. Enable GitHub Pages:
   - Go to Settings > Pages
   - Source: Deploy from branch
   - Branch: gh-pages / root

### Data Structure

`apps.json`:
```json
{
  "last_updated": "2025-12-10T12:00:00Z",
  "apps": [{
    "name": "myapp",
    "status": "success",
    "environment": "production",
    "url": "https://myapp.domain.com",
    "last_deploy": "2025-12-10T10:30:00Z",
    "last_deploy_by": "username",
    "commit_sha": "abc1234",
    "uptime": {
      "status": "healthy",
      "response_time_ms": 245,
      "last_check": "2025-12-10T12:00:00Z"
    }
  }]
}
```

### Automatic Updates

Dashboard is updated automatically by:
- `deploy.yml` - After each deployment
- `scheduled.yml` - Health check results (daily)
- `cleanup.yml` - When apps are removed

---

## Enhanced Notifications

Rich Slack notifications with detailed deployment information.

### Notification Fields

Deploy notifications include:
- App name and environment
- Deploy duration
- Files changed count
- Version comparison (previous → current)
- Commit message
- Actor (who triggered)
- App URL
- Links to workflow and commit

### Example Notification

```
✅ Deployed successfully

App:           myapp              Environment:  production
Duration:      2m 34s             Files Changed: 12
Version:       abc1234 → def5678  Actor:        @username
Commit:        Fix login validation bug
URL:           https://myapp.domain.com

View Workflow | View Commit
```

### Configuration

Set notification webhook secrets in your GitHub organization settings:

| Secret | Description |
|--------|-------------|
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL |

Both are optional - notifications will be skipped if the secret is not set.

**Creating a Discord Webhook:**
1. Open Discord and go to your server
2. Right-click the channel → Edit Channel → Integrations → Webhooks
3. Click "New Webhook" and copy the URL
4. Add as `DISCORD_WEBHOOK_URL` secret in GitHub

---

## Troubleshooting

### Release Tasks Failing

```bash
# Check task output in workflow logs

# Run task manually
ssh dokku run myapp python manage.py migrate --no-input

# Check app logs
ssh dokku logs myapp
```

### Backup Failures

```bash
# Check if database exists
ssh dokku postgres:exists postgres-myapp

# Check backup directory permissions
ssh dokku@server ls -la /var/backups/dokku/postgres/

# Manual backup test
ssh dokku postgres:export postgres-myapp | head -c 1000
```

### Lock Not Working

```bash
# Check lock status directly
ssh dokku config:get myapp DEPLOY_LOCKED

# Force unlock
ssh dokku config:unset myapp DEPLOY_LOCKED DEPLOY_LOCK_REASON DEPLOY_LOCK_BY DEPLOY_LOCK_AT
```

### Dashboard Not Updating

1. Check `gh-pages` branch exists
2. Verify GitHub Pages is enabled
3. Check workflow permissions
4. Look for update-dashboard job errors in workflow logs

---

## Commit Status Checks

Real-time deployment status on commits and PRs.

### How It Works

When a deployment starts:
1. **Pending status** is set on the commit
2. Deployment proceeds through all steps
3. **Success status** is set with link to deployed app
4. Or **Failure status** is set with link to workflow logs

### Status Contexts

Different contexts for different environments:
- `deploy/production` - Production deployments
- `deploy/staging` - Staging deployments
- `deploy/development` - Development deployments
- `preview/deploy` - Preview environment deployments

### Viewing Status

Commit status appears:
- On the commit in GitHub UI
- On pull requests that include the commit
- In branch protection rules (can require passing status)

### PR Comments

When code from a merged PR is deployed, a comment is automatically added:

> ## 🚀 Deployed to production
>
> | Status | URL |
> |--------|-----|
> | ✅ Deployed | https://myapp.domain.com |
>
> **Commit:** `abc1234`
> **Duration:** 2m 34s
> **Environment:** production

---

## Scheduled Deployments

Schedule deployments for specific times - useful for:
- Off-hours deployments (weekends, nights)
- Coordinated releases across teams
- Change window compliance

### Scheduling a Deployment

1. Go to [Actions → Schedule Deploy](../../actions/workflows/schedule-deploy.yml)
2. Click "Run workflow"
3. Enter:
   - **Action**: `schedule`
   - **Repository**: e.g., `signalwire-demos/my-app`
   - **Branch**: e.g., `main`
   - **Scheduled Time**: ISO 8601 format (e.g., `2025-12-15T03:00:00Z`)

### Managing Schedules

**List all scheduled deploys:**
- Action: `list`

**Cancel a scheduled deploy:**
- Action: `cancel`
- Schedule ID: The ID shown when scheduling

### How It Works

1. Schedules are stored in `scheduled-deploys.json` in the main branch
2. A scheduler job runs every 15 minutes
3. When a scheduled time arrives, the deployment is triggered
4. Completed schedules are automatically cleaned up after 7 days

### Notifications

Slack/Discord notifications are sent when:
- A deployment is scheduled
- A scheduled deployment is cancelled
- A scheduled deployment is executed

---

## Audit Log

Comprehensive deployment history for compliance and debugging.

### What's Logged

Every deployment action is recorded:
- **Deploys**: Production, staging, development
- **Previews**: Deploy and cleanup
- **Rollbacks**: Version changes
- **Locks**: Lock and unlock operations

### Log Location

Logs are stored on the `gh-pages` branch:
- `audit-log.json` - Machine-readable JSON
- `audit-report.md` - Human-readable markdown

Access at: `https://signalwire-demos.github.io/dokku-deploy-system/audit-log.json`

### Log Entry Format

```json
{
  "id": "audit-1702345678-abc123",
  "timestamp": "2025-12-11T15:00:00Z",
  "action": "deploy",
  "app_name": "myapp",
  "environment": "production",
  "status": "success",
  "actor": "username",
  "repository": "signalwire-demos/myapp",
  "commit": {
    "sha": "abc1234",
    "message": "Fix login bug"
  },
  "duration": "2m 34s",
  "url": "https://myapp.domain.com",
  "workflow": {
    "run_id": "12345678",
    "run_url": "https://github.com/..."
  }
}
```

### Statistics

The audit log tracks:
- Total deployments
- Successful deployments
- Failed deployments
- Success rate percentage

### Manual Log Entry

For compliance or tracking external events:
1. Go to [Actions → Audit Log](../../actions/workflows/audit-log.yml)
2. Click "Run workflow"
3. Fill in the event details

### Retention

- Last 1000 entries are kept
- Older entries are automatically removed
- For longer retention, download and archive the JSON file

---

## Approval Gates

Require manual approval before deploying to production environments.

### How It Works

The system uses GitHub's built-in environment protection rules. When configured:

1. Developer pushes to `main` branch
2. Deploy workflow starts and reaches the deploy job
3. Workflow **pauses** waiting for approval
4. Designated reviewers receive email notification
5. Reviewer approves or rejects from GitHub UI
6. If approved, deployment proceeds

### Setup

Configure in your repository:

1. Go to **Settings** → **Environments** → **production**
2. Enable **Required reviewers**
   - Add individual users or teams
   - Set minimum number of approvals (default: 1)
3. Optional: Set **Wait timer**
   - Delay before deployment starts (even after approval)
   - Useful for scheduled deployments
4. Optional: Set **Deployment branches**
   - Restrict which branches can deploy to this environment
   - Recommended: Only `main` for production

### Reviewer Options

When a deployment needs approval, reviewers can:

- **Approve**: Deployment proceeds
- **Reject**: Deployment cancelled
- **Comment**: Add notes for the requester

### Notifications

Reviewers receive:
- Email notification when approval is needed
- Link to the pending deployment in GitHub

### Best Practices

- Require at least 2 reviewers for production
- Set branch protection to require PR reviews before merge
- Use wait timer (5-15 min) to allow last-minute cancellation
- Document approval criteria in CONTRIBUTING.md

### Bypass for Emergencies

If an emergency deployment is needed:
1. Repository admins can bypass protection rules
2. Or, temporarily disable protection, deploy, then re-enable
3. All bypasses are logged in audit log

---

## Security Scanning

Automatic vulnerability scanning before every deployment using Trivy.

### How It Works

1. **Security scan job** runs in parallel with tests
2. **Trivy scans** the codebase for vulnerabilities
3. **Results** are parsed and categorized (Critical/High/Medium)
4. **Summary** appears in GitHub workflow summary
5. **Blocking** occurs if critical vulnerabilities are found (configurable)
6. **Artifacts** are uploaded for detailed review

### Supported Ecosystems

Trivy scans:
- **Python**: requirements.txt, Pipfile, pyproject.toml
- **Node.js**: package-lock.json, yarn.lock
- **Go**: go.mod
- **Ruby**: Gemfile.lock
- **PHP**: composer.lock
- **Container images**: Dockerfile
- **Infrastructure**: Terraform, CloudFormation

### Workflow Summary

After each scan, the workflow summary shows:

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 3 |
| Medium | 12 |

### Configuration

#### Disable Blocking

To allow deployments despite critical vulnerabilities:

```yaml
# .dokku/config.yml
security:
  block_on_critical: false
```

#### Environment-Specific Policies

Different strictness per environment:

```yaml
# .dokku/config.yml
security:
  environments:
    production: strict      # Block on critical
    staging: moderate       # Warn only
    development: permissive # No blocking
```

#### Ignore Specific CVEs

Create `.trivyignore` in your repo root:

```
# Accepted risks
CVE-2023-12345
CVE-2023-67890

# False positive in test dependency
CVE-2023-11111
```

### Viewing Detailed Results

1. Go to the workflow run
2. Click "Summary" tab
3. Download the `security-scan-results` artifact
4. Open `trivy-results.json` for full details

### Fixing Vulnerabilities

Most vulnerabilities can be fixed by updating dependencies:

```bash
# Python
pip install --upgrade vulnerable-package

# Node.js
npm audit fix

# Go
go get -u vulnerable-module
```

### Best Practices

- Review vulnerability reports weekly
- Update dependencies regularly
- Add accepted risks to `.trivyignore` with comments
- Consider using Dependabot for automated updates

---

## Webhook Integrations

Send deployment notifications to external services and trigger deployments from external systems.

### Outbound Webhooks

#### Custom Webhooks

Send deployment events to any HTTP endpoint:

1. Set `DEPLOY_WEBHOOK_URLS` secret (comma-separated list)
2. Optionally set `DEPLOY_WEBHOOK_SECRET` for HMAC signing

**Example:**
```
https://hooks.example.com/deploy,https://api.internal.com/events
```

**Payload:**
```json
{
  "event": "deployment",
  "app": "myapp",
  "environment": "production",
  "status": "success",
  "commit_sha": "abc1234def5678...",
  "commit_sha_short": "abc1234",
  "deployed_by": "username",
  "branch": "main",
  "app_url": "https://myapp.domain.com",
  "workflow_url": "https://github.com/.../runs/123",
  "repository": "org/repo",
  "timestamp": "2025-12-11T15:00:00Z"
}
```

**Headers:**
- `Content-Type: application/json`
- `X-Deploy-Event: deployment`
- `X-Deploy-Signature: sha256=...` (if secret configured)

#### Verifying Signatures

To verify webhook authenticity:

```python
import hmac
import hashlib

def verify_signature(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

### Pre-configured Integrations

#### Datadog

Send deployment events to Datadog for tracking and correlation.

**Setup:**
1. Get API key from Datadog → Organization Settings → API Keys
2. Add `DD_API_KEY` secret to GitHub

**Events sent:**
- Deployment started
- Deployment succeeded (info)
- Deployment failed (error)

**Tags added:**
- `app:myapp`
- `env:production`
- `deploy`
- `status:success`

#### PagerDuty

Alert on-call when deployments fail.

**Setup:**
1. Create integration in PagerDuty → Services → Integrations → Events API v2
2. Add `PAGERDUTY_ROUTING_KEY` secret to GitHub

**When triggered:**
- Only on deployment failures
- Creates incident with deployment details
- Links to workflow run

**Deduplication:**
- Uses `deploy-{app}-{env}-{run_id}` as dedup key
- Prevents duplicate alerts for same failure

### Inbound Webhooks (Trigger Deployments)

Trigger deployments from external CI/CD systems using repository dispatch:

```bash
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/ORG/REPO/dispatches \
  -d '{
    "event_type": "deploy",
    "client_payload": {
      "environment": "production",
      "ref": "main"
    }
  }'
```

### Secrets Reference

| Secret | Required | Description |
|--------|----------|-------------|
| `DEPLOY_WEBHOOK_URLS` | No | Comma-separated webhook URLs |
| `DEPLOY_WEBHOOK_SECRET` | No | HMAC secret for signature |
| `DD_API_KEY` | No | Datadog API key |
| `PAGERDUTY_ROUTING_KEY` | No | PagerDuty routing key |

---

## Environment Promotion

Promote deployments between environments with version comparison and safety checks.

### Promotion Paths

Only these promotion paths are allowed:
- `development` → `staging`
- `staging` → `production`

### How It Works

1. Go to [Actions → Promote Environment](../../actions/workflows/promote.yml)
2. Enter the app name (repo name, e.g., `myapp`)
3. Select source environment (`development` or `staging`)
4. Select target environment (`staging` or `production`)
5. Type `PROMOTE` to confirm
6. Review the diff and approve (if approval gates enabled)

### What Happens

1. **Validation**: Checks promotion path is valid
2. **Version Check**: Gets current versions from both environments
3. **Diff Display**: Shows commits to be promoted
4. **Deploy**: Pushes source version to target environment
5. **Update GIT_REV**: Tracks the promoted version
6. **Verify**: Health check on promoted app

### Workflow Summary

After promotion, the workflow summary shows:

| | |
|---|---|
| **App** | myapp |
| **From** | staging (abc1234) |
| **To** | production (def5678) |

### Commits to be Promoted

- `abc1234` Fix login bug
- `def5678` Update dependencies

### Environment App Naming

| Environment | App Name |
|-------------|----------|
| development | `myapp-dev` |
| staging | `myapp-staging` |
| production | `myapp` |

### Approval Gates

When promoting to production:
- If the `production` environment has required reviewers configured
- Deployment will pause for approval
- Reviewers receive email notification

### Notifications

Slack/Discord notifications are sent with:
- App name
- Promotion path (from → to)
- Number of commits promoted
- URL of promoted app
- Who triggered the promotion

---

## Custom Domains

Configure custom domains for your apps through `.dokku/config.yml`.

### Configuration

Add custom domains to your `.dokku/config.yml`:

```yaml
# Global custom domains (all environments)
custom_domains:
  - api.example.com
  - app.example.com

# Environment-specific domains
environments:
  production:
    custom_domains:
      - www.example.com
      - example.com
  staging:
    custom_domains:
      - staging.example.com
```

### How It Works

During deployment:
1. Workflow reads `.dokku/config.yml`
2. Extracts global and environment-specific domains
3. Adds each domain to the Dokku app
4. SSL is automatically provisioned via Let's Encrypt

### DNS Setup

Before adding a custom domain:

1. **A Record**: Point to your Dokku server IP
   ```
   example.com.  A  192.0.2.1
   ```

2. **CNAME Record**: For subdomains
   ```
   www.example.com.  CNAME  myapp.dokku.domain.com.
   ```

### Wildcard Domains

Dokku supports wildcard domains:

```yaml
custom_domains:
  - "*.example.com"
```

Note: Wildcard SSL requires DNS challenge (not supported by default Let's Encrypt setup).

### Verifying Domains

Check configured domains:

```bash
ssh dokku@server domains:report myapp
```

### Removing Domains

Domains are only added, not removed automatically. To remove:

```bash
ssh dokku@server domains:remove myapp old-domain.com
```

---

## Secrets Management

Sync secrets from external vaults to GitHub Environment Variables.

### Supported Providers

| Provider | Secret Required |
|----------|-----------------|
| AWS Secrets Manager | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| HashiCorp Vault | `VAULT_ADDR` + (`VAULT_TOKEN` or `VAULT_ROLE_ID`/`VAULT_SECRET_ID`) |
| 1Password | `OP_SERVICE_ACCOUNT_TOKEN` |

### Manual Sync

1. Go to [Actions → Sync Secrets](../../actions/workflows/sync-secrets.yml)
2. Select provider
3. Enter target repository (e.g., `signalwire-demos/myapp`)
4. Select target environment (`production`, `staging`, `development`)
5. Enter secret path in vault
6. Enable dry run to preview (recommended first)

### Vault Configuration Examples

#### AWS Secrets Manager

Secret path format: `myapp/production`

Store secrets as JSON:
```json
{
  "SIGNALWIRE_TOKEN": "PT...",
  "API_KEY": "abc123",
  "DATABASE_URL": "postgres://..."
}
```

#### HashiCorp Vault

Secret path format: `secret/myapp/production` (KV v2) or `secret/myapp/production` (KV v1)

```bash
# KV v2
vault kv put secret/myapp/production \
  SIGNALWIRE_TOKEN="PT..." \
  API_KEY="abc123"

# KV v1
vault write secret/myapp/production \
  SIGNALWIRE_TOKEN="PT..." \
  API_KEY="abc123"
```

#### 1Password

Secret path format: `vault/item` or just `item`

Create a Secure Note with fields:
- Field Label: `SIGNALWIRE_TOKEN`, Value: `PT...`
- Field Label: `API_KEY`, Value: `abc123`

### Scheduled Sync

Enable automatic daily sync by creating `.github/secrets-sync.yml`:

```yaml
syncs:
  - provider: aws-secrets-manager
    repo: signalwire-demos/myapp
    environment: production
    secret_path: myapp/production

  - provider: hashicorp-vault
    repo: signalwire-demos/myapp
    environment: staging
    secret_path: secret/myapp/staging

  - provider: 1password
    repo: signalwire-demos/otherapp
    environment: production
    secret_path: DevVault/otherapp-secrets
```

Schedule runs daily at 4 AM UTC.

### Dry Run Mode

Always use dry run first to preview changes:

```
═══════════════════════════════════════════════════════
  DRY RUN - Preview Only
═══════════════════════════════════════════════════════

  Target: signalwire-demos/myapp
  Environment: production

  Current variables in environment:
    • SIGNALWIRE_TOKEN
    • API_KEY

  Variables to sync:
    • SIGNALWIRE_TOKEN
    • API_KEY
    • NEW_VARIABLE

  Run again with dry_run=false to apply changes.
```

### Security Considerations

- Secrets are synced as **Environment Variables** (not GitHub Secrets)
- This allows visibility for debugging but means they appear in logs
- Only sync non-sensitive configuration this way
- For highly sensitive data, use GitHub Secrets directly
- All sync operations are logged in the audit log

### Troubleshooting

**AWS authentication failed:**
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set
- Check IAM permissions include `secretsmanager:GetSecretValue`

**Vault authentication failed:**
- For token auth: ensure `VAULT_TOKEN` is valid and not expired
- For AppRole: verify `VAULT_ROLE_ID` and `VAULT_SECRET_ID`
- Check Vault policies allow reading the secret path

**1Password authentication failed:**
- Verify `OP_SERVICE_ACCOUNT_TOKEN` is a valid service account token
- Check the service account has access to the vault/item

---

## Canary Deployments

Deploy to a subset of traffic first, monitor for errors, and automatically rollback if issues are detected.

### How It Works

1. Deploy new version as `{app}-canary` alongside stable
2. Split traffic between stable and canary (configurable %)
3. Monitor error rates for specified duration
4. Auto-rollback if error rate exceeds threshold
5. Auto-promote canary to stable if healthy
6. Clean up canary app

### Architecture

```
        nginx (load balancer)
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
 Stable    Stable    Canary
 (v1.0)    (v1.0)    (v1.1)
  90%       90%       10%
```

### Usage

1. Go to [Actions → Canary Deployment](../../actions/workflows/canary-deploy.yml)
2. Enter:
   - **App name**: Production app name (e.g., `myapp`)
   - **Repo**: Repository (e.g., `signalwire-demos/myapp`)
   - **Ref**: Branch/tag/SHA to deploy
   - **Canary percent**: Traffic to canary (5-50%)
   - **Monitoring duration**: Minutes to monitor
   - **Error threshold**: Error rate % to trigger rollback

### Workflow Steps

| Step | Description |
|------|-------------|
| Validate | Check inputs, get stable version |
| Deploy Canary | Create `{app}-canary`, deploy new version |
| Configure Traffic | Set up nginx upstream with weighted routing |
| Monitor | Health check every 10s for monitoring duration |
| Rollback/Promote | Based on error rate vs threshold |
| Cleanup | Remove canary app and nginx config |

### Configuration

Add canary defaults to `.dokku/config.yml`:

```yaml
canary:
  enabled: true
  environments:
    production:
      initial_percent: 10
      monitoring_duration: 15  # minutes
      error_threshold: 5       # percent
      metrics:
        - error_rate
        - response_time_p99
      rollback_on:
        error_rate: "> 5%"
        response_time_p99: "> 2000ms"
```

### Notifications

Slack/Discord notifications are sent with:
- App name
- Canary percentage
- Monitoring duration
- Final error rate
- Result (promoted or rolled back)

### Best Practices

- Start with low canary percentage (10%)
- Use longer monitoring duration for critical apps
- Set appropriate error thresholds for your app
- Monitor workflow logs during canary period
- Have runbook ready for manual intervention

---

## Multi-Region Deployment

Deploy to multiple Dokku servers for redundancy or geographic distribution.

### Configuration

Add servers to `.dokku/config.yml`:

```yaml
servers:
  us-east:
    host: dokku-us-east.example.com
    primary: true
    domain: us-east.example.com
  us-west:
    host: dokku-us-west.example.com
    domain: us-west.example.com
  eu-west:
    host: dokku-eu.example.com
    domain: eu.example.com

deployment:
  strategy: all          # all, primary-only, rolling
  failover: true
  parallel: true
```

### Deployment Strategies

| Strategy | Description |
|----------|-------------|
| `all` | Deploy to all servers simultaneously |
| `primary-only` | Deploy only to the primary server |
| `rolling` | Deploy one server at a time |

### Usage

1. Go to [Actions → Multi-Region Deploy](../../actions/workflows/multi-region-deploy.yml)
2. Enter:
   - **Repo**: Repository to deploy
   - **Ref**: Branch/tag/SHA
   - **Environment**: Target environment
   - **Strategy**: Deployment strategy
   - **Confirm**: Type `DEPLOY`

### Required Secrets

For multiple servers, you can use:

**Shared secrets (default):**
- `DOKKU_SSH_PRIVATE_KEY` - Used for all servers
- `BASE_DOMAIN` - Default domain

**Per-region secrets (optional):**
- `DOKKU_HOST_US_EAST`, `DOKKU_HOST_US_WEST`, etc.
- `DOKKU_SSH_KEY_US_EAST`, `DOKKU_SSH_KEY_US_WEST`, etc.
- `BASE_DOMAIN_US_EAST`, `BASE_DOMAIN_US_WEST`, etc.

### Workflow Summary

After deployment, the summary shows:

| Server | Status |
|--------|--------|
| us-east | ✅ |
| us-west | ✅ |
| eu-west | ✅ |

### Failover Behavior

With `fail-fast: false`:
- If one server fails, deployment continues to others
- Summary shows which servers succeeded/failed
- Notifications include partial failure status

### Health Verification

Each server deployment includes:
1. App creation (if needed)
2. Git push deploy
3. GIT_REV config update
4. Health check verification

---

## Resource Auto-Scaling

Automatically scale app resources based on metrics or schedules.

### Configuration

Add scaling rules to `.dokku/config.yml`:

```yaml
scaling:
  production:
    min_instances: 2
    max_instances: 10

    metrics:
      cpu:
        scale_up_threshold: 80    # Scale up when CPU > 80%
        scale_down_threshold: 50  # Scale down when CPU < 50%
      memory:
        scale_up_threshold: 85

    schedule:
      - cron: "0 9 * * 1-5"   # 9 AM weekdays
        instances: 5           # Scale up for business hours
      - cron: "0 18 * * 1-5"  # 6 PM weekdays
        instances: 2           # Scale down after hours

    cooldown:
      scale_up: 3m    # Wait 3 min after scale up
      scale_down: 10m # Wait 10 min after scale down
```

### How It Works

**Metric-based scaling:**
1. Autoscaler runs every 5 minutes
2. Checks CPU/memory for each production app
3. Compares against thresholds
4. Scales up/down if threshold breached
5. Respects cooldown periods

**Scheduled scaling:**
1. Checks cron rules on each run
2. If current time matches schedule, sets instance count
3. Useful for predictable traffic patterns

### Usage

**Automatic (scheduled):**
- Runs every 5 minutes via cron
- Checks all production apps

**Manual:**
1. Go to [Actions → Autoscaler](../../actions/workflows/autoscaler.yml)
2. Choose action:
   - `check` - Check metrics and scale if needed
   - `status` - Show current scaling status
   - `scale-up` - Force scale up by 1
   - `scale-down` - Force scale down by 1
   - `set` - Set specific instance count

### Scaling Actions

| Action | Trigger | Behavior |
|--------|---------|----------|
| Scale Up | CPU > threshold | +1 instance (up to max) |
| Scale Down | CPU < threshold | -1 instance (down to min) |
| Scheduled | Cron match | Set to target instances |
| Manual | Workflow dispatch | Force scale or set |

### Cooldown Periods

Prevent rapid scaling oscillation:

- **Scale up cooldown**: Wait before scaling up again (default: 3m)
- **Scale down cooldown**: Wait before scaling down again (default: 10m)

Last scaling action is stored in `LAST_SCALE_TIME` and `LAST_SCALE_ACTION` config vars.

### Monitoring

View scaling history:
```bash
ssh dokku@server config:get myapp LAST_SCALE_TIME
ssh dokku@server config:get myapp LAST_SCALE_ACTION
ssh dokku@server ps:scale myapp
```

### Best Practices

- Set reasonable min/max to prevent runaway costs
- Use longer cooldown for scale-down to avoid flapping
- Combine with scheduled scaling for predictable patterns
- Monitor scaling events in audit log
- Set alerts for hitting max instances

---

## Log Aggregation

Ship logs to external services for centralized search, analysis, and alerting.

### Supported Destinations

| Destination | Secret Required | URL Format |
|-------------|-----------------|------------|
| Papertrail | `PAPERTRAIL_HOST`, `PAPERTRAIL_PORT` | `syslog+tls://host:port` |
| Datadog | `DD_API_KEY` | Datadog intake endpoint |
| Logtail/Better Stack | `LOGTAIL_TOKEN` | `https://in.logtail.com/token` |
| Custom | None | Any syslog URL |

### Usage

1. Go to [Actions → Configure Log Drain](../../actions/workflows/log-drain.yml)
2. Select action:
   - `list` - Show current drains
   - `add` - Add log drain
   - `remove` - Remove log drain
3. Select destination and app(s)

### Adding a Log Drain

**For all apps:**
- Leave "App name" empty
- Select destination
- Workflow configures drain on all apps

**For specific app:**
- Enter app name
- Select destination
- Drain configured only for that app

### Papertrail Setup

1. Create a Papertrail account at papertrailapp.com
2. Add a log destination (Settings → Log Destinations)
3. Copy the host and port
4. Add secrets to GitHub:
   - `PAPERTRAIL_HOST`: e.g., `logs.papertrailapp.com`
   - `PAPERTRAIL_PORT`: e.g., `12345`

### Datadog Setup

1. Get API key from Datadog → Organization Settings → API Keys
2. Add `DD_API_KEY` secret to GitHub
3. Logs will appear in Datadog Logs Explorer

Additional environment variables set on apps:
- `DD_LOGS_ENABLED=true`
- `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true`

### Logtail/Better Stack Setup

1. Create a source in Logtail
2. Copy the source token
3. Add `LOGTAIL_TOKEN` secret to GitHub

### Custom Syslog

For custom syslog endpoints:
1. Select "custom" destination
2. Enter full syslog URL:
   - `syslog://host:port` (UDP)
   - `syslog+tcp://host:port` (TCP)
   - `syslog+tls://host:port` (TLS)

### Viewing Logs

After configuration, logs flow automatically to your destination:

```bash
# Local logs still available
ssh dokku@server logs myapp -t

# Or view in your log aggregation service
```

---

## Performance Monitoring

Track response times, error rates, and availability metrics for all apps.

### How It Works

**Every 15 minutes:**
1. Workflow pings each app's health endpoint
2. Collects response time samples (20 requests)
3. Calculates percentiles (p50, p95, p99)
4. Checks error rates and SSL expiry
5. Stores metrics in `dashboard/metrics.json`
6. Sends alerts if thresholds exceeded

### Metrics Collected

| Metric | Description |
|--------|-------------|
| Response Time p50 | Median response time |
| Response Time p95 | 95th percentile |
| Response Time p99 | 99th percentile |
| Success Rate | % of 2xx responses |
| Error Rate | % of 4xx/5xx responses |
| SSL Days | Days until certificate expiry |

### Usage

**Automatic:**
- Runs every 15 minutes via cron
- Results stored in gh-pages branch

**Manual:**
1. Go to [Actions → Performance Monitor](../../actions/workflows/performance-monitor.yml)
2. Optionally specify app name
3. Enable "detailed" for 100 requests instead of 20

### Alert Thresholds

Alerts are triggered when:

| Condition | Alert Level |
|-----------|-------------|
| p99 > 2000ms | ⚠️ Warning |
| Error rate > 5% | 🚨 Critical |
| SSL < 14 days | 🔐 Warning |

### Viewing Metrics

**Dashboard:**
Access `dashboard/metrics.json` on gh-pages branch:
```
https://signalwire-demos.github.io/dokku-deploy-system/metrics.json
```

**Workflow Summary:**
Manual runs show a summary table with all app metrics.

### Metrics History

The workflow keeps 24 hours of historical data (96 entries at 15-minute intervals).

Structure:
```json
{
  "latest": { ... current metrics ... },
  "history": [ ... last 96 entries ... ]
}
```

### Alert Destinations

Alerts are sent to:
- Slack (if `SLACK_WEBHOOK_URL` configured)
- Discord (if `DISCORD_WEBHOOK_URL` configured)
- PagerDuty (if `PAGERDUTY_ROUTING_KEY` configured, critical only)

---

## Cost Tracking

Track resource usage and generate cost reports per app.

### How It Works

**Scheduled reports:**
- Monthly (1st of month)
- Weekly (Sundays)

**Metrics collected:**
- CPU allocation per app
- Memory allocation per app
- Storage usage (databases)
- Instance count

**Cost calculation:**
```
CPU Cost = CPU cores × instances × hours × rate
Memory Cost = GB × instances × hours × rate
Storage Cost = GB × rate
```

### Usage

1. Go to [Actions → Cost Report](../../actions/workflows/cost-report.yml)
2. Select period: daily, weekly, or monthly
3. Enable "detailed" for per-app breakdown

### Cost Rates

Default rates (configurable via secrets):

| Resource | Rate | Secret |
|----------|------|--------|
| CPU | $0.01/core-hour | `COST_CPU_RATE` |
| Memory | $0.005/GB-hour | `COST_MEM_RATE` |
| Storage | $0.10/GB-month | `COST_STORAGE_RATE` |

### Report Contents

**Summary:**
- Total CPU cores
- Total memory (GB)
- Total storage (GB)
- Total estimated cost

**By Environment:**
- Production, staging, development, preview
- App count and cost per environment

**Top 10 Apps:**
- Highest cost apps
- Resource breakdown

### Budget Alerts

Set a monthly budget to receive alerts:

1. Add `COST_BUDGET_MONTHLY` secret (e.g., `500` for $500)
2. Alerts triggered at:
   - ⚠️ 80% of budget
   - 🚨 100% of budget (overage)

### Viewing Reports

**Dashboard:**
Reports saved to `dashboard/cost-reports/`:
```
https://signalwire-demos.github.io/dokku-deploy-system/cost-reports/latest.json
```

**Historical reports:**
```
cost-reports/weekly-2025-12-07.json
cost-reports/monthly-2025-12-01.json
```

### Optimizing Costs

Based on reports, consider:
- Reducing instance counts for low-traffic apps
- Lowering memory limits if not fully utilized
- Cleaning up unused preview environments
- Using scheduled scaling for off-hours

---

## CLI Tool

A developer-friendly command-line interface for common Dokku operations.

### Installation

```bash
# Download
curl -o dokku-cli https://raw.githubusercontent.com/signalwire-demos/dokku-deploy-system/main/cli/dokku-cli
chmod +x dokku-cli
sudo mv dokku-cli /usr/local/bin/

# Configure
dokku-cli setup
```

### Shell Completions

**Bash:**
```bash
# Linux
sudo cp completions/dokku-cli.bash /etc/bash_completion.d/dokku-cli

# macOS (Homebrew)
cp completions/dokku-cli.bash $(brew --prefix)/etc/bash_completion.d/dokku-cli

# Or add to ~/.bashrc
source /path/to/dokku-cli.bash
```

**Zsh:**
```bash
# Add to ~/.zshrc (before compinit)
fpath=(/path/to/completions $fpath)
autoload -Uz compinit && compinit
```

**Fish:**
```bash
cp completions/dokku-cli.fish ~/.config/fish/completions/
```

### App Aliases

Create shortcuts for frequently used apps:

```bash
# Add aliases
dokku-cli alias add prod myapp
dokku-cli alias add stg myapp-staging

# Use aliases instead of full names
dokku-cli logs prod
dokku-cli restart stg
dokku-cli config prod

# List all aliases
dokku-cli alias

# Remove alias
dokku-cli alias remove prod
```

Aliases are stored in `~/.dokku-cli`.

### Output Formatting

**JSON output** for scripting:
```bash
dokku-cli --json list
# {"apps":["myapp","myapp-staging","other-app"]}

# Use with jq
dokku-cli --json list | jq '.apps[]'
```

**Quiet mode** for minimal output:
```bash
dokku-cli --quiet list
# myapp
# myapp-staging
# other-app

# Use in scripts
for app in $(dokku-cli -q list); do
  dokku-cli restart $app
done
```

### Common Commands

| Command | Description |
|---------|-------------|
| `dokku-cli list` | List all apps |
| `dokku-cli info [app]` | Show app details |
| `dokku-cli logs [app]` | View recent logs |
| `dokku-cli logs:follow [app]` | Tail logs in real-time |
| `dokku-cli config [app]` | Show environment variables |
| `dokku-cli config:set [app] K=V` | Set environment variables |
| `dokku-cli restart [app]` | Restart app |
| `dokku-cli deploy [app] [branch]` | Deploy via git push |
| `dokku-cli rollback [app]` | Rollback to previous release |
| `dokku-cli shell [app]` | Open shell in container |
| `dokku-cli run [app] <cmd>` | Run one-off command |
| `dokku-cli db [app] backup` | Backup database |
| `dokku-cli lock [app]` | Lock deployments |
| `dokku-cli unlock [app]` | Unlock deployments |

### Auto-Detection

If you don't specify an app name, the CLI will use the current git repository name:

```bash
cd ~/projects/myapp
dokku-cli logs          # Uses "myapp"
dokku-cli restart       # Restarts "myapp"
dokku-cli config:set DEBUG=true  # Sets on "myapp"
```

### Configuration File

Settings are stored in `~/.dokku-cli`:

```bash
# Dokku CLI Configuration
DOKKU_HOST="dokku.example.com"
SSH_KEY="/home/user/.ssh/dokku_deploy"
BASE_DOMAIN="example.com"

# App Aliases
ALIAS_PROD="myapp"
ALIAS_STG="myapp-staging"
ALIAS_DEV="myapp-dev"
```

### Deploy Locks via CLI

```bash
# Lock an app (block all deployments)
dokku-cli lock myapp "Investigating production issue"

# Check lock status
dokku-cli lock:status myapp

# Unlock when ready
dokku-cli unlock myapp
```

### Database Operations

```bash
# Create and link database
dokku-cli db myapp create postgres

# Connect to database shell
dokku-cli db myapp connect postgres

# Backup to local file
dokku-cli db myapp backup postgres
# Output: myapp-20250115_120000.dump

# Backup to server storage
dokku-cli db myapp backup-server postgres

# List available backups
dokku-cli db myapp list-backups

# Restore from backup
dokku-cli db myapp restore backup.dump postgres
```

### Interactive Mode (requires fzf)

The CLI includes a full interactive TUI for browsing and managing apps:

```bash
# Launch interactive mode
dokku-cli i
# or
dokku-cli interactive
```

**Features:**
- Fuzzy search through all apps
- Preview pane showing app status, URL, and lock state
- Action menu for common operations
- Branch picker for deployments

**Quick app selection:**
```bash
# Pick app interactively, then run command
dokku-cli logs -i
dokku-cli restart -i
dokku-cli config -i
dokku-cli deploy -i    # Also picks branch interactively

# Or use pick for piping
dokku-cli restart $(dokku-cli pick)
```

**Install fzf:**
```bash
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt install fzf

# Fedora
sudo dnf install fzf

# Arch
sudo pacman -S fzf
```

If fzf is not installed, the CLI will show installation instructions when you try to use interactive mode.
