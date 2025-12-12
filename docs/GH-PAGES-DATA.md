# GitHub Pages Data Files Reference

The `gh-pages` branch stores dashboard data and metrics. Multiple workflows write to this branch, using retry logic with `git pull --rebase` to handle concurrent updates.

---

## Table of Contents

- [Overview](#overview)
- [Data Files](#data-files)
  - [apps.json](#appsjson)
  - [repos.json](#reposjson)
  - [metrics.json](#metricsjson)
  - [audit-log.json](#audit-logjson)
  - [cost-reports/](#cost-reports)
- [Workflow Data Flow](#workflow-data-flow)
- [Dashboard UI](#dashboard-ui)
- [Setup Instructions](#setup-instructions)

---

## Overview

| File/Directory | Purpose | Updated By |
|----------------|---------|------------|
| `apps.json` | Deployed applications and status | deploy, preview, cleanup, update-dashboard, update-repo-list |
| `repos.json` | Deployable repositories list | update-repo-list |
| `metrics.json` | Performance metrics history | performance-monitor |
| `audit-log.json` | Deployment audit trail | audit-log |
| `cost-reports/` | Resource usage reports | cost-report |

---

## Data Files

### apps.json

Main registry of deployed applications.

**Location:** `gh-pages:/apps.json`

**Schema:**

```json
{
  "last_updated": "2025-12-12T10:30:00Z",
  "apps": [
    {
      "name": "myapp",
      "base_app": "myapp",
      "status": "running",
      "environment": "production",
      "repo": "signalwire-demos/myapp",
      "url": "https://myapp.dokku.example.com",
      "last_deploy": "2025-12-12T10:30:00Z",
      "last_deploy_by": "github-username",
      "commit_sha": "abc1234def5678901234567890abcdef12345678",
      "uptime": {
        "status": "healthy",
        "uptime_seconds": 86400,
        "response_time_ms": 150,
        "last_check": "2025-12-12T10:45:00Z"
      }
    },
    {
      "name": "myapp-staging",
      "base_app": "myapp",
      "status": "running",
      "environment": "staging",
      "repo": "signalwire-demos/myapp",
      "url": "https://myapp-staging.dokku.example.com",
      "last_deploy": "2025-12-11T15:00:00Z",
      "last_deploy_by": "another-user",
      "commit_sha": "def5678abc1234901234567890abcdef12345678",
      "uptime": null
    },
    {
      "name": "myapp-pr-42",
      "base_app": "myapp",
      "status": "running",
      "environment": "preview",
      "repo": "signalwire-demos/myapp",
      "url": "https://myapp-pr-42.dokku.example.com",
      "last_deploy": "2025-12-12T09:00:00Z",
      "last_deploy_by": "contributor",
      "commit_sha": "123abc456def789012345678901234567890abcd",
      "uptime": null
    }
  ]
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `last_updated` | ISO 8601 | When the file was last modified |
| `apps[].name` | string | Dokku app name |
| `apps[].base_app` | string | Base app name (without -staging, -dev, -pr-N suffix) |
| `apps[].status` | string | `running`, `stopped`, `success`, `failure` |
| `apps[].environment` | string | `production`, `staging`, `development`, `preview`, `canary` |
| `apps[].repo` | string | GitHub repository (org/repo) or null |
| `apps[].url` | string | App URL |
| `apps[].last_deploy` | ISO 8601 | Last deployment timestamp |
| `apps[].last_deploy_by` | string | GitHub username who triggered deploy |
| `apps[].commit_sha` | string | Full commit SHA deployed |
| `apps[].uptime` | object/null | Health check data (from performance-monitor) |
| `apps[].uptime.status` | string | `healthy`, `unhealthy`, `unknown` |
| `apps[].uptime.uptime_seconds` | number | Seconds since last restart |
| `apps[].uptime.response_time_ms` | number | Last response time in milliseconds |
| `apps[].uptime.last_check` | ISO 8601 | Last health check timestamp |

---

### repos.json

Cache of deployable repositories in the organization.

**Location:** `gh-pages:/repos.json`

**Schema:**

```json
{
  "last_updated": "2025-12-12T06:00:00Z",
  "repos": [
    {
      "name": "myapp",
      "full_name": "signalwire-demos/myapp",
      "default_branch": "main",
      "updated_at": "2025-12-12T05:30:00Z",
      "description": "My application description",
      "has_dokku_config": true,
      "has_deploy_workflow": true
    },
    {
      "name": "another-app",
      "full_name": "signalwire-demos/another-app",
      "default_branch": "main",
      "updated_at": "2025-12-10T12:00:00Z",
      "description": null,
      "has_dokku_config": false,
      "has_deploy_workflow": true
    }
  ]
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `repos[].name` | string | Repository name |
| `repos[].full_name` | string | Full repository path (org/repo) |
| `repos[].default_branch` | string | Default branch name |
| `repos[].updated_at` | ISO 8601 | Last repo update |
| `repos[].description` | string/null | Repository description |
| `repos[].has_dokku_config` | boolean | Has `.dokku/` directory |
| `repos[].has_deploy_workflow` | boolean | Has deploy workflow |

**Updated by:** `update-repo-list.yml` (every 6 hours)

---

### metrics.json

Performance metrics history for all apps.

**Location:** `gh-pages:/metrics.json`

**Schema:**

```json
{
  "latest": {
    "timestamp": "2025-12-12T10:45:00Z",
    "apps": {
      "myapp": {
        "url": "https://myapp.dokku.example.com",
        "response_time": {
          "p50": 45,
          "p95": 120,
          "p99": 250
        },
        "availability": {
          "success_rate": 100,
          "error_rate": 0,
          "requests": 20,
          "successes": 20,
          "client_errors": 0,
          "server_errors": 0
        },
        "ssl": {
          "days_until_expiry": 75
        }
      },
      "another-app": {
        "url": "https://another-app.dokku.example.com",
        "response_time": {
          "p50": 80,
          "p95": 200,
          "p99": 450
        },
        "availability": {
          "success_rate": 95,
          "error_rate": 5,
          "requests": 20,
          "successes": 19,
          "client_errors": 0,
          "server_errors": 1
        },
        "ssl": {
          "days_until_expiry": 45
        }
      }
    }
  },
  "history": [
    { "timestamp": "2025-12-12T10:30:00Z", "apps": { ... } },
    { "timestamp": "2025-12-12T10:15:00Z", "apps": { ... } }
  ]
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `latest` | object | Most recent metrics collection |
| `latest.timestamp` | ISO 8601 | When metrics were collected |
| `latest.apps[name].response_time.p50` | number | 50th percentile response time (ms) |
| `latest.apps[name].response_time.p95` | number | 95th percentile response time (ms) |
| `latest.apps[name].response_time.p99` | number | 99th percentile response time (ms) |
| `latest.apps[name].availability.success_rate` | number | Success rate percentage |
| `latest.apps[name].availability.error_rate` | number | Error rate percentage |
| `latest.apps[name].ssl.days_until_expiry` | number | Days until SSL cert expires (-1 if no SSL) |
| `history` | array | Last 96 entries (24 hours at 15-min intervals) |

**Updated by:** `performance-monitor.yml` (every 15 minutes)

**Alert thresholds:**
- p99 response time > 2000ms
- Error rate > 5%
- SSL expiry < 14 days

---

### audit-log.json

Deployment audit trail.

**Location:** `gh-pages:/audit-log.json`

**Schema:**

```json
{
  "entries": [
    {
      "id": "audit-1702378200-abc123",
      "timestamp": "2025-12-12T10:30:00Z",
      "action": "deploy",
      "app_name": "myapp",
      "environment": "production",
      "status": "success",
      "actor": "github-username",
      "commit_sha": "abc1234",
      "commit_message": "Add new feature",
      "duration": "45s",
      "url": "https://myapp.dokku.example.com",
      "workflow_url": "https://github.com/org/repo/actions/runs/12345",
      "metadata": {}
    },
    {
      "id": "audit-1702377000-def456",
      "timestamp": "2025-12-12T10:10:00Z",
      "action": "rollback",
      "app_name": "myapp",
      "environment": "production",
      "status": "success",
      "actor": "admin-user",
      "commit_sha": "def5678",
      "commit_message": null,
      "duration": "30s",
      "url": "https://myapp.dokku.example.com",
      "workflow_url": "https://github.com/org/repo/actions/runs/12344",
      "metadata": {
        "from_version": "v5",
        "to_version": "v4"
      }
    }
  ]
}
```

**Action Types:**

| Action | Description |
|--------|-------------|
| `deploy` | Standard deployment |
| `preview` | Preview environment deploy |
| `cleanup` | App/preview destruction |
| `rollback` | Version rollback |
| `lock` | Deploy lock enabled |
| `unlock` | Deploy lock disabled |
| `promote` | Environment promotion |
| `canary` | Canary deployment |
| `sync-secrets` | Secret synchronization |
| `log-drain-add` | Log drain configured |
| `log-drain-remove` | Log drain removed |
| `manual` | Manual log entry |

**Updated by:** `audit-log.yml`

---

### cost-reports/

Resource usage and cost reports.

**Location:** `gh-pages:/cost-reports/`

**Files:**
- `latest.json` - Most recent report
- `weekly-YYYY-MM-DD.json` - Weekly reports
- `monthly-YYYY-MM-DD.json` - Monthly reports

**Schema:**

```json
{
  "timestamp": "2025-12-12T00:00:00Z",
  "period": "weekly",
  "hours": 168,
  "apps": [
    {
      "name": "myapp",
      "environment": "production",
      "resources": {
        "cpu": 2,
        "memory_gb": 2,
        "storage_gb": 10,
        "instances": 4
      },
      "costs": {
        "cpu": 13.44,
        "memory": 6.72,
        "storage": 1.00,
        "total": 21.16
      }
    }
  ],
  "totals": {
    "cpu": 8,
    "memory_gb": 6,
    "storage_gb": 25,
    "cost": 85.50
  },
  "rates": {
    "cpu_per_hour": 0.01,
    "memory_per_gb_hour": 0.005,
    "storage_per_gb_month": 0.10
  }
}
```

**Updated by:** `cost-report.yml` (weekly on Sunday, monthly on 1st)

---

## Workflow Data Flow

```
deploy.yml ─────────┬──→ update-dashboard.yml ──→ apps.json
                    │
preview.yml ────────┼──→ audit-log.yml ──────────→ audit-log.json
                    │
cleanup.yml ────────┤
                    │
rollback.yml ───────┘

scheduled.yml ──────────→ (health checks update apps.json via update-dashboard)

performance-monitor.yml ─→ metrics.json

update-repo-list.yml ────→ repos.json, apps.json

cost-report.yml ─────────→ cost-reports/*.json
```

---

## Dashboard UI

The dashboard UI (`index.html`, `style.css`) reads from these JSON files to display:

- App status cards with health indicators
- Environment filtering (production, staging, development, preview)
- Search functionality
- Response time metrics
- Last deploy information
- Auto-refresh every 5 minutes

**Dashboard URL:** `https://{org}.github.io/{repo}/`

---

## Setup Instructions

### Initial Setup

1. **Create gh-pages branch:**

```bash
git checkout --orphan gh-pages
git rm -rf .
cp -r dashboard/* .
git add .
git commit -m "Initialize dashboard"
git push origin gh-pages
```

2. **Enable GitHub Pages:**
   - Repository Settings → Pages
   - Source: Deploy from branch
   - Branch: `gh-pages` / `root`

3. **Verify access:**
   - Visit `https://{org}.github.io/{repo}/`

### Manual Data Reset

If data becomes corrupted:

```bash
# Clone gh-pages branch
git clone --branch gh-pages https://github.com/org/repo dashboard-data
cd dashboard-data

# Reset apps.json
echo '{"last_updated":"","apps":[]}' > apps.json

# Reset repos.json
echo '{"last_updated":"","repos":[]}' > repos.json

# Reset metrics.json
echo '{"latest":null,"history":[]}' > metrics.json

# Reset audit-log.json
echo '{"entries":[]}' > audit-log.json

# Commit and push
git add .
git commit -m "Reset data files"
git push
```

### Triggering Data Refresh

```bash
# Refresh repo list
gh workflow run update-repo-list.yml

# Refresh metrics
gh workflow run performance-monitor.yml

# Sync dashboard from Dokku
gh workflow run update-dashboard.yml -f action=sync-from-dokku
```
