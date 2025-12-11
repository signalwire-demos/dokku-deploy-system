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
- 14-day retention with automatic cleanup

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

# Backup to server storage
dokku-cli db myapp backup-server postgres
# Creates: /var/backups/dokku/postgres/myapp/20231210_153000.gz

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
