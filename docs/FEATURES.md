# Feature Documentation

This document describes the advanced features available in the Dokku Deploy System.

## Table of Contents

- [Deploy Locks](#deploy-locks)
- [Release Tasks](#release-tasks)
- [Database Backups](#database-backups)
- [Deploy Dashboard](#deploy-dashboard)
- [Enhanced Notifications](#enhanced-notifications)

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
sudo mkdir -p /var/backups/dokku/{postgres,mysql,redis,mongo}
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

Set the `SLACK_WEBHOOK_URL` secret in your GitHub organization or repository settings.

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
