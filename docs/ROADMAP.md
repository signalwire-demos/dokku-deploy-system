# Dokku Deploy System - Feature Roadmap

This document outlines planned features to enhance the deployment system. Features are organized by priority and include implementation details.

---

## Table of Contents

1. [GitHub Commit Status Checks](#1-github-commit-status-checks)
2. [Approval Gates](#2-approval-gates)
3. [Deploy Scheduling](#3-deploy-scheduling)
4. [Audit Log](#4-audit-log)
5. [Environment Promotion](#5-environment-promotion)
6. [Dependency Scanning](#6-dependency-scanning)
7. [Webhook Integrations](#7-webhook-integrations)
8. [Custom Domain Management](#8-custom-domain-management)
9. [Secrets Management](#9-secrets-management)
10. [Canary Deployments](#10-canary-deployments)
11. [Deployment Notifications to PR/Commit](#11-deployment-notifications-to-prcommit)
12. [Multi-Region/Multi-Server Support](#12-multi-regionmulti-server-support)
13. [Resource Auto-Scaling](#13-resource-auto-scaling)
14. [Cost Tracking](#14-cost-tracking)
15. [Log Aggregation](#15-log-aggregation)
16. [Performance Monitoring](#16-performance-monitoring)
17. [Database Management UI](#17-database-management-ui)
18. [App Templates](#18-app-templates)
19. [CLI Improvements](#19-cli-improvements)
20. [Monorepo Support](#20-monorepo-support)

---

## 1. GitHub Commit Status Checks

**Priority:** High | **Effort:** Low | **Impact:** High

### Overview
Post deployment status as GitHub commit status checks so developers can see deploy progress directly on PRs and commits.

### Current State
- Deployment status only visible in Actions tab
- PR comments for preview environments only

### Proposed Solution

#### Implementation
Add status check updates at key deployment stages:

```yaml
# In deploy.yml - Add after setup job
- name: Set pending status
  env:
    GH_TOKEN: ${{ secrets.GH_ORG_TOKEN }}
  run: |
    gh api repos/${{ github.repository }}/statuses/${{ github.sha }} \
      -f state=pending \
      -f context="deploy/${{ env.ENVIRONMENT }}" \
      -f description="Deployment in progress..." \
      -f target_url="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

# After successful deploy
- name: Set success status
  if: success()
  run: |
    gh api repos/${{ github.repository }}/statuses/${{ github.sha }} \
      -f state=success \
      -f context="deploy/${{ env.ENVIRONMENT }}" \
      -f description="Deployed to ${{ env.ENVIRONMENT }}" \
      -f target_url="https://${{ env.DOMAIN }}"

# On failure
- name: Set failure status
  if: failure()
  run: |
    gh api repos/${{ github.repository }}/statuses/${{ github.sha }} \
      -f state=failure \
      -f context="deploy/${{ env.ENVIRONMENT }}" \
      -f description="Deployment failed" \
      -f target_url="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
```

#### Status Contexts
- `deploy/production` - Production deployment status
- `deploy/staging` - Staging deployment status
- `deploy/development` - Development deployment status
- `deploy/preview` - Preview environment status

#### Files to Modify
- `.github/workflows/deploy.yml` - Add status updates
- `.github/workflows/preview.yml` - Add status updates

### Acceptance Criteria
- [ ] Pending status shown when deploy starts
- [ ] Success status with URL when deploy completes
- [ ] Failure status with link to logs on failure
- [ ] Status visible on PR checks and commit page

---

## 2. Approval Gates

**Priority:** High | **Effort:** Medium | **Impact:** High

### Overview
Require manual approval before deploying to production, with support for team-based approvals.

### Current State
- Any push to main triggers immediate production deploy
- No approval workflow

### Proposed Solution

#### Option A: GitHub Environment Protection Rules (Recommended)
Use GitHub's built-in environment protection:

1. Configure in repo Settings → Environments → production:
   - Required reviewers: Add team members
   - Wait timer: Optional delay (e.g., 5 minutes)
   - Deployment branches: Restrict to `main` only

2. The existing `environment: production` in deploy.yml will automatically pause for approval.

#### Option B: Custom Approval Workflow
For more control, create a custom approval system:

```yaml
# .github/workflows/deploy-with-approval.yml
name: Deploy with Approval

on:
  push:
    branches: [main]

jobs:
  request-approval:
    runs-on: ubuntu-latest
    outputs:
      approved: ${{ steps.check.outputs.approved }}
    steps:
      - name: Create deployment request
        id: request
        uses: actions/github-script@v7
        with:
          script: |
            const { data: deployment } = await github.rest.repos.createDeployment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              ref: context.sha,
              environment: 'production',
              required_contexts: [],
              auto_merge: false
            });
            return deployment.id;

      - name: Wait for approval
        id: check
        uses: actions/github-script@v7
        with:
          script: |
            // Poll for approval status
            const deploymentId = ${{ steps.request.outputs.result }};
            let approved = false;
            for (let i = 0; i < 60; i++) { // Wait up to 30 minutes
              const { data: statuses } = await github.rest.repos.listDeploymentStatuses({
                owner: context.repo.owner,
                repo: context.repo.repo,
                deployment_id: deploymentId
              });
              if (statuses.some(s => s.state === 'success')) {
                approved = true;
                break;
              }
              if (statuses.some(s => s.state === 'failure' || s.state === 'error')) {
                break;
              }
              await new Promise(r => setTimeout(r, 30000)); // Wait 30s
            }
            core.setOutput('approved', approved);

  deploy:
    needs: request-approval
    if: needs.request-approval.outputs.approved == 'true'
    uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main
    secrets: inherit
```

#### Configuration Options
Add to `.dokku/config.yml`:

```yaml
approval:
  production:
    required: true
    reviewers: 2
    teams:
      - platform-team
      - leads
    timeout: 30m  # Auto-reject after 30 minutes
  staging:
    required: false
```

#### Slack/Discord Integration
Notify approvers when approval is needed:

```yaml
- name: Request approval notification
  run: |
    curl -X POST "$SLACK_WEBHOOK_URL" \
      -d "{
        \"text\": \"🔐 Deployment approval required\",
        \"attachments\": [{
          \"color\": \"warning\",
          \"fields\": [
            {\"title\": \"App\", \"value\": \"$APP_NAME\", \"short\": true},
            {\"title\": \"Environment\", \"value\": \"production\", \"short\": true},
            {\"title\": \"Requester\", \"value\": \"${{ github.actor }}\", \"short\": true}
          ],
          \"actions\": [
            {\"type\": \"button\", \"text\": \"Review\", \"url\": \"$APPROVAL_URL\"}
          ]
        }]
      }"
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add approval job
- `docs/FEATURES.md` - Document approval configuration

### Acceptance Criteria
- [ ] Production deploys require approval
- [ ] Configurable number of required approvers
- [ ] Slack/Discord notification to approvers
- [ ] Timeout for stale approval requests
- [ ] Bypass option for emergency deploys (with audit)

---

## 3. Deploy Scheduling

**Priority:** Medium | **Effort:** Low | **Impact:** Medium

### Overview
Schedule deployments for specific times, enforce maintenance windows, and support "deploy after hours" workflows.

### Current State
- Deploys happen immediately on push
- No scheduling capability

### Proposed Solution

#### Scheduled Deploy Workflow
```yaml
# .github/workflows/scheduled-deploy.yml
name: Scheduled Deploy

on:
  workflow_dispatch:
    inputs:
      app_name:
        description: 'App to deploy'
        required: true
      environment:
        description: 'Target environment'
        type: choice
        options: [production, staging]
      schedule_time:
        description: 'Deploy time (ISO 8601, e.g., 2024-01-15T22:00:00Z)'
        required: true
      branch:
        description: 'Branch to deploy'
        default: 'main'

jobs:
  schedule:
    runs-on: ubuntu-latest
    steps:
      - name: Calculate delay
        id: delay
        run: |
          SCHEDULE_TIME="${{ inputs.schedule_time }}"
          SCHEDULE_EPOCH=$(date -d "$SCHEDULE_TIME" +%s)
          NOW_EPOCH=$(date +%s)
          DELAY=$((SCHEDULE_EPOCH - NOW_EPOCH))

          if [ "$DELAY" -lt 0 ]; then
            echo "::error::Scheduled time is in the past"
            exit 1
          fi

          if [ "$DELAY" -gt 604800 ]; then
            echo "::error::Cannot schedule more than 7 days in advance"
            exit 1
          fi

          echo "delay=$DELAY" >> $GITHUB_OUTPUT
          echo "Deployment scheduled in $((DELAY / 3600)) hours $((DELAY % 3600 / 60)) minutes"

      - name: Wait for scheduled time
        run: |
          echo "Waiting ${{ steps.delay.outputs.delay }} seconds..."
          sleep ${{ steps.delay.outputs.delay }}

      - name: Trigger deployment
        env:
          GH_TOKEN: ${{ secrets.GH_ORG_TOKEN }}
        run: |
          gh workflow run deploy.yml \
            --repo ${{ github.repository }} \
            --ref ${{ inputs.branch }}
```

#### Maintenance Windows
Add to `.dokku/config.yml`:

```yaml
maintenance_windows:
  production:
    # Only allow deploys during these windows
    allowed:
      - days: [tue, wed, thu]
        start: "09:00"
        end: "16:00"
        timezone: "America/New_York"
    # Or block specific times
    blocked:
      - days: [fri]
        start: "14:00"
        end: "23:59"
        reason: "No Friday afternoon deploys"
      - dates: ["2024-12-24", "2024-12-25"]
        reason: "Holiday freeze"
  staging:
    # No restrictions
    allowed: always
```

#### Enforcement in deploy.yml
```yaml
- name: Check maintenance window
  run: |
    # Parse maintenance windows from config
    if [ -f ".dokku/config.yml" ]; then
      WINDOWS=$(yq e ".maintenance_windows.$ENVIRONMENT" .dokku/config.yml)
      if [ "$WINDOWS" != "null" ] && [ "$WINDOWS" != "always" ]; then
        # Check if current time is within allowed window
        CURRENT_DAY=$(date +%a | tr '[:upper:]' '[:lower:]')
        CURRENT_TIME=$(date +%H:%M)

        # Implementation: check against windows
        # If outside window, fail with message
      fi
    fi
```

#### Queue System for Off-Hours
```yaml
- name: Queue for next window
  if: env.OUTSIDE_WINDOW == 'true' && inputs.queue_if_outside == 'true'
  run: |
    NEXT_WINDOW=$(calculate_next_window)
    gh workflow run scheduled-deploy.yml \
      -f app_name=$APP_NAME \
      -f schedule_time=$NEXT_WINDOW \
      -f branch=${{ github.ref_name }}
    echo "Deployment queued for $NEXT_WINDOW"
```

### Files to Create/Modify
- `.github/workflows/scheduled-deploy.yml` - New workflow
- `.github/workflows/deploy.yml` - Add window check
- `docs/FEATURES.md` - Document scheduling

### Acceptance Criteria
- [ ] Schedule deploys for future time via workflow_dispatch
- [ ] Maintenance window configuration in config.yml
- [ ] Enforce windows (block or queue)
- [ ] Notification when deploy is queued
- [ ] Holiday/freeze date support

---

## 4. Audit Log

**Priority:** Medium | **Effort:** Low | **Impact:** Medium

### Overview
Track all deployment actions with who, what, when, and outcome for compliance and debugging.

### Current State
- GitHub Actions logs exist but expire
- No centralized audit trail
- Dashboard shows last deploy only

### Proposed Solution

#### Audit Log Storage
Store audit events in `audit-log.json` on gh-pages branch:

```json
{
  "events": [
    {
      "id": "evt_20240115_001",
      "timestamp": "2024-01-15T14:30:00Z",
      "type": "deploy",
      "actor": "username",
      "app": "myapp",
      "environment": "production",
      "outcome": "success",
      "details": {
        "commit_sha": "abc1234",
        "branch": "main",
        "duration_seconds": 145,
        "previous_version": "def5678"
      },
      "workflow_run_id": 12345678
    },
    {
      "id": "evt_20240115_002",
      "timestamp": "2024-01-15T15:00:00Z",
      "type": "rollback",
      "actor": "admin",
      "app": "myapp",
      "environment": "production",
      "outcome": "success",
      "details": {
        "from_version": "abc1234",
        "to_version": "xyz9999",
        "reason": "Performance degradation"
      }
    }
  ]
}
```

#### Event Types
- `deploy` - Standard deployment
- `rollback` - Rollback operation
- `preview_create` - Preview environment created
- `preview_destroy` - Preview environment destroyed
- `lock` - App locked
- `unlock` - App unlocked
- `cleanup` - App cleaned up
- `backup` - Database backup
- `restore` - Database restore
- `config_change` - Environment variables changed
- `approval_requested` - Deploy approval requested
- `approval_granted` - Deploy approved
- `approval_denied` - Deploy rejected

#### Audit Writer (Reusable Action)
```yaml
# .github/actions/audit-log/action.yml
name: Write Audit Log
description: Append event to audit log

inputs:
  type:
    required: true
  app:
    required: true
  environment:
    required: false
  outcome:
    required: true
  details:
    required: false
    default: '{}'

runs:
  using: composite
  steps:
    - name: Checkout gh-pages
      uses: actions/checkout@v4
      with:
        ref: gh-pages
        path: audit

    - name: Append audit event
      shell: bash
      run: |
        cd audit
        EVENT_ID="evt_$(date +%Y%m%d)_$(openssl rand -hex 4)"
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        # Create event JSON
        EVENT=$(jq -n \
          --arg id "$EVENT_ID" \
          --arg ts "$TIMESTAMP" \
          --arg type "${{ inputs.type }}" \
          --arg actor "${{ github.actor }}" \
          --arg app "${{ inputs.app }}" \
          --arg env "${{ inputs.environment }}" \
          --arg outcome "${{ inputs.outcome }}" \
          --argjson details '${{ inputs.details }}' \
          --arg run_id "${{ github.run_id }}" \
          '{
            id: $id,
            timestamp: $ts,
            type: $type,
            actor: $actor,
            app: $app,
            environment: $env,
            outcome: $outcome,
            details: $details,
            workflow_run_id: ($run_id | tonumber)
          }')

        # Append to audit log (keep last 10000 events)
        if [ -f audit-log.json ]; then
          jq --argjson event "$EVENT" '.events += [$event] | .events = .events[-10000:]' \
            audit-log.json > tmp.json && mv tmp.json audit-log.json
        else
          echo "{\"events\": [$EVENT]}" > audit-log.json
        fi

    - name: Commit audit log
      shell: bash
      run: |
        cd audit
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add audit-log.json
        git diff --staged --quiet || git commit -m "Audit: ${{ inputs.type }} ${{ inputs.app }}"
        git push
```

#### Dashboard Integration
Add audit log viewer to dashboard:

```html
<!-- In dashboard/index.html -->
<div id="audit-log">
  <h2>Recent Activity</h2>
  <table>
    <thead>
      <tr>
        <th>Time</th>
        <th>Type</th>
        <th>App</th>
        <th>Actor</th>
        <th>Outcome</th>
      </tr>
    </thead>
    <tbody id="audit-events"></tbody>
  </table>
</div>

<script>
async function loadAuditLog() {
  const response = await fetch('audit-log.json');
  const data = await response.json();
  const tbody = document.getElementById('audit-events');

  data.events.slice(-50).reverse().forEach(event => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${new Date(event.timestamp).toLocaleString()}</td>
      <td><span class="badge badge-${event.type}">${event.type}</span></td>
      <td>${event.app}</td>
      <td>${event.actor}</td>
      <td><span class="status status-${event.outcome}">${event.outcome}</span></td>
    `;
    tbody.appendChild(row);
  });
}
</script>
```

#### Export Capability
```yaml
# .github/workflows/export-audit.yml
name: Export Audit Log

on:
  workflow_dispatch:
    inputs:
      format:
        type: choice
        options: [json, csv]
      start_date:
        description: 'Start date (YYYY-MM-DD)'
      end_date:
        description: 'End date (YYYY-MM-DD)'

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: gh-pages

      - name: Filter and export
        run: |
          jq --arg start "${{ inputs.start_date }}" \
             --arg end "${{ inputs.end_date }}" \
             '.events | map(select(.timestamp >= $start and .timestamp <= $end))' \
             audit-log.json > export.json

          if [ "${{ inputs.format }}" == "csv" ]; then
            jq -r '["timestamp","type","actor","app","environment","outcome"],
                   (.[] | [.timestamp,.type,.actor,.app,.environment,.outcome]) | @csv' \
              export.json > export.csv
          fi

      - uses: actions/upload-artifact@v4
        with:
          name: audit-export
          path: export.*
```

### Files to Create/Modify
- `.github/actions/audit-log/action.yml` - Reusable action
- `.github/workflows/deploy.yml` - Add audit calls
- `.github/workflows/preview.yml` - Add audit calls
- `.github/workflows/rollback.yml` - Add audit calls
- `.github/workflows/cleanup.yml` - Add audit calls
- `.github/workflows/lock.yml` - Add audit calls
- `.github/workflows/export-audit.yml` - New workflow
- `dashboard/index.html` - Add audit viewer

### Acceptance Criteria
- [ ] All deployment events logged
- [ ] Audit log viewer in dashboard
- [ ] Export to JSON/CSV
- [ ] Date range filtering
- [ ] 10,000 event retention

---

## 5. Environment Promotion

**Priority:** High | **Effort:** Medium | **Impact:** High

### Overview
Promote deployments between environments (dev → staging → production) with comparison and one-click workflow.

### Current State
- Each environment deploys from different branches
- No direct promotion between environments
- Manual coordination required

### Proposed Solution

#### Promotion Workflow
```yaml
# .github/workflows/promote.yml
name: Promote Environment

on:
  workflow_dispatch:
    inputs:
      app_name:
        description: 'App to promote'
        required: true
      from_environment:
        description: 'Source environment'
        type: choice
        options: [development, staging]
        required: true
      to_environment:
        description: 'Target environment'
        type: choice
        options: [staging, production]
        required: true
      confirm:
        description: 'Type PROMOTE to confirm'
        required: true

jobs:
  validate:
    runs-on: ubuntu-latest
    outputs:
      source_sha: ${{ steps.info.outputs.source_sha }}
      target_sha: ${{ steps.info.outputs.target_sha }}
      changes: ${{ steps.diff.outputs.changes }}
    steps:
      - name: Validate confirmation
        if: inputs.confirm != 'PROMOTE'
        run: |
          echo "::error::Confirmation text must be 'PROMOTE'"
          exit 1

      - name: Validate promotion path
        run: |
          FROM="${{ inputs.from_environment }}"
          TO="${{ inputs.to_environment }}"

          # Valid paths: dev→staging, staging→production
          if [ "$FROM" == "development" ] && [ "$TO" != "staging" ]; then
            echo "::error::Development can only promote to staging"
            exit 1
          fi
          if [ "$FROM" == "staging" ] && [ "$TO" != "production" ]; then
            echo "::error::Staging can only promote to production"
            exit 1
          fi

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOKKU_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

      - name: Get environment info
        id: info
        run: |
          FROM_APP="${{ inputs.app_name }}"
          TO_APP="${{ inputs.app_name }}"

          case "${{ inputs.from_environment }}" in
            development) FROM_APP="${{ inputs.app_name }}-dev" ;;
            staging) FROM_APP="${{ inputs.app_name }}-staging" ;;
          esac

          case "${{ inputs.to_environment }}" in
            staging) TO_APP="${{ inputs.app_name }}-staging" ;;
            production) TO_APP="${{ inputs.app_name }}" ;;
          esac

          # Get current versions
          SOURCE_SHA=$(ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            config:get $FROM_APP GIT_REV 2>/dev/null || echo "unknown")
          TARGET_SHA=$(ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            config:get $TO_APP GIT_REV 2>/dev/null || echo "none")

          echo "source_sha=$SOURCE_SHA" >> $GITHUB_OUTPUT
          echo "target_sha=$TARGET_SHA" >> $GITHUB_OUTPUT
          echo "source_app=$FROM_APP" >> $GITHUB_OUTPUT
          echo "target_app=$TO_APP" >> $GITHUB_OUTPUT

      - name: Compare versions
        id: diff
        env:
          GH_TOKEN: ${{ secrets.GH_ORG_TOKEN }}
        run: |
          SOURCE="${{ steps.info.outputs.source_sha }}"
          TARGET="${{ steps.info.outputs.target_sha }}"

          if [ "$TARGET" == "none" ]; then
            echo "First deployment to ${{ inputs.to_environment }}"
            echo "changes=initial" >> $GITHUB_OUTPUT
          elif [ "$SOURCE" == "$TARGET" ]; then
            echo "::error::Source and target are already at the same version"
            exit 1
          else
            echo "## Changes to be promoted" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY

            # Get commit diff
            COMMITS=$(gh api repos/${{ github.repository }}/compare/${TARGET}...${SOURCE} \
              --jq '.commits | length')
            echo "**$COMMITS commits** will be promoted" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY

            gh api repos/${{ github.repository }}/compare/${TARGET}...${SOURCE} \
              --jq '.commits[] | "- \(.sha[0:7]) \(.commit.message | split("\n")[0])"' \
              >> $GITHUB_STEP_SUMMARY

            echo "changes=$COMMITS" >> $GITHUB_OUTPUT
          fi

  promote:
    needs: validate
    runs-on: ubuntu-latest
    environment: ${{ inputs.to_environment }}
    steps:
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOKKU_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

      - name: Checkout source version
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.source_sha }}
          fetch-depth: 0

      - name: Determine target app name
        id: target
        run: |
          case "${{ inputs.to_environment }}" in
            staging) echo "app=${{ inputs.app_name }}-staging" >> $GITHUB_OUTPUT ;;
            production) echo "app=${{ inputs.app_name }}" >> $GITHUB_OUTPUT ;;
          esac

      - name: Deploy to target
        run: |
          TARGET_APP="${{ steps.target.outputs.app }}"

          git remote add dokku dokku@${{ secrets.DOKKU_HOST }}:$TARGET_APP 2>/dev/null || \
          git remote set-url dokku dokku@${{ secrets.DOKKU_HOST }}:$TARGET_APP

          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no" \
            git push dokku HEAD:refs/heads/main --force

      - name: Verify promotion
        run: |
          DOMAIN="${{ steps.target.outputs.app }}.${{ secrets.BASE_DOMAIN }}"
          sleep 10

          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" || echo "000")

          if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
            echo "✅ Promotion successful!"
            echo "🌐 https://$DOMAIN"
          else
            echo "::warning::App returned HTTP $HTTP_STATUS - verify manually"
          fi

      - name: Notify
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
        run: |
          MESSAGE="🚀 **${{ inputs.app_name }}** promoted from ${{ inputs.from_environment }} → ${{ inputs.to_environment }}"

          [ -n "$SLACK_WEBHOOK_URL" ] && curl -X POST "$SLACK_WEBHOOK_URL" \
            -d "{\"text\": \"$MESSAGE\", \"attachments\": [{\"color\": \"good\"}]}"

          [ -n "$DISCORD_WEBHOOK_URL" ] && curl "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"embeds\": [{\"title\": \"$MESSAGE\", \"color\": 3066993}]}"
```

#### Dashboard Integration
Add promotion button to dashboard:

```javascript
// In dashboard app
function showPromoteDialog(app, currentEnv) {
  const targetEnv = currentEnv === 'development' ? 'staging' : 'production';

  if (confirm(`Promote ${app} from ${currentEnv} to ${targetEnv}?`)) {
    // Trigger workflow via API
    fetch(`https://api.github.com/repos/signalwire-demos/${app}/actions/workflows/promote.yml/dispatches`, {
      method: 'POST',
      headers: {
        'Authorization': `token ${userToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        ref: 'main',
        inputs: {
          app_name: app,
          from_environment: currentEnv,
          to_environment: targetEnv,
          confirm: 'PROMOTE'
        }
      })
    });
  }
}
```

### Files to Create/Modify
- `.github/workflows/promote.yml` - New workflow
- `dashboard/index.html` - Add promote buttons
- `docs/FEATURES.md` - Document promotion

### Acceptance Criteria
- [ ] Promote dev → staging → production
- [ ] Show diff before promotion
- [ ] Require confirmation
- [ ] Block invalid promotion paths
- [ ] Notifications on promotion
- [ ] Dashboard integration

---

## 6. Dependency Scanning

**Priority:** High | **Effort:** Medium | **Impact:** High

### Overview
Scan for vulnerable dependencies before deployment and optionally block deploys with critical CVEs.

### Current State
- No dependency scanning
- Vulnerable packages can be deployed

### Proposed Solution

#### Integration Options

**Option A: GitHub Dependabot (Recommended)**
Already built into GitHub - just enable it:

```yaml
# .github/dependabot.yml (in each repo)
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Option B: Pre-deploy Scanning**
Add scanning step to deploy.yml:

```yaml
# In deploy.yml
- name: Scan dependencies
  id: scan
  run: |
    CRITICAL=0
    HIGH=0

    # Python
    if [ -f "requirements.txt" ]; then
      pip install safety
      RESULT=$(safety check -r requirements.txt --json 2>/dev/null || echo "[]")
      CRITICAL=$(echo "$RESULT" | jq '[.[] | select(.severity == "critical")] | length')
      HIGH=$(echo "$RESULT" | jq '[.[] | select(.severity == "high")] | length')
    fi

    # Node.js
    if [ -f "package.json" ]; then
      npm audit --json > audit.json 2>/dev/null || true
      CRITICAL=$((CRITICAL + $(jq '.metadata.vulnerabilities.critical // 0' audit.json)))
      HIGH=$((HIGH + $(jq '.metadata.vulnerabilities.high // 0' audit.json)))
    fi

    echo "critical=$CRITICAL" >> $GITHUB_OUTPUT
    echo "high=$HIGH" >> $GITHUB_OUTPUT

    # Generate summary
    echo "## Dependency Scan Results" >> $GITHUB_STEP_SUMMARY
    echo "- Critical: $CRITICAL" >> $GITHUB_STEP_SUMMARY
    echo "- High: $HIGH" >> $GITHUB_STEP_SUMMARY

- name: Block on critical vulnerabilities
  if: steps.scan.outputs.critical > 0
  run: |
    echo "::error::Deployment blocked: ${{ steps.scan.outputs.critical }} critical vulnerabilities found"
    echo "Run 'npm audit' or 'safety check' locally to see details"
    exit 1
```

**Option C: Trivy Integration**
More comprehensive scanning:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'

- name: Check for critical vulnerabilities
  run: |
    CRITICAL=$(cat trivy-results.sarif | jq '[.runs[].results[] | select(.level == "error")] | length')
    if [ "$CRITICAL" -gt 0 ]; then
      echo "::error::$CRITICAL critical vulnerabilities found"
      exit 1
    fi
```

#### Configuration
Add to `.dokku/config.yml`:

```yaml
security:
  dependency_scan:
    enabled: true
    block_on:
      critical: true    # Block deploy if critical vulns
      high: false       # Allow deploy with high vulns (warning only)
    ignore:
      - CVE-2023-12345  # Known false positive
      - GHSA-xxxx-yyyy  # Accepted risk
    environments:
      production: strict    # Block on high+critical
      staging: moderate     # Block on critical only
      development: permissive  # Warn only
```

#### Auto-fix PRs
Create PRs to fix vulnerabilities:

```yaml
# .github/workflows/security-fixes.yml
name: Security Fixes

on:
  schedule:
    - cron: '0 8 * * 1'  # Weekly on Monday

jobs:
  fix-vulnerabilities:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Fix npm vulnerabilities
        if: hashFiles('package.json') != ''
        run: |
          npm audit fix
          if git diff --quiet package-lock.json; then
            echo "No fixes available"
          else
            git checkout -b security-fixes-$(date +%Y%m%d)
            git add package-lock.json
            git commit -m "fix: Update dependencies to fix vulnerabilities"
            gh pr create --title "Security: Fix vulnerable dependencies" \
              --body "Automated PR to fix known vulnerabilities"
          fi
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add scan step
- `.github/workflows/security-fixes.yml` - New workflow
- `template-repo/.github/dependabot.yml` - Template file
- `docs/FEATURES.md` - Document security scanning

### Acceptance Criteria
- [ ] Scan dependencies before deploy
- [ ] Block critical vulnerabilities
- [ ] Configurable severity thresholds
- [ ] Ignore list for accepted risks
- [ ] Security findings in GitHub Security tab
- [ ] Weekly auto-fix PRs

---

## 7. Webhook Integrations

**Priority:** Medium | **Effort:** Low | **Impact:** Medium

### Overview
Trigger deployments from external systems and notify external services after deployment.

### Current State
- Deploys only triggered by git push or manual workflow
- Notifications limited to Slack/Discord

### Proposed Solution

#### Inbound Webhooks (Trigger Deploys)

**Repository Dispatch Events:**
```yaml
# In deploy.yml - add trigger
on:
  repository_dispatch:
    types: [deploy, deploy-production, deploy-staging]
```

**Trigger from external system:**
```bash
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/signalwire-demos/myapp/dispatches \
  -d '{
    "event_type": "deploy",
    "client_payload": {
      "environment": "production",
      "ref": "main",
      "triggered_by": "jenkins"
    }
  }'
```

**Handle in workflow:**
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      ENVIRONMENT: ${{ github.event.client_payload.environment || 'production' }}
      REF: ${{ github.event.client_payload.ref || 'main' }}
```

#### Outbound Webhooks (Notify External Services)

**Generic webhook notification:**
```yaml
# In deploy.yml
- name: Send webhook notifications
  if: always()
  env:
    WEBHOOK_URLS: ${{ secrets.DEPLOY_WEBHOOK_URLS }}  # Comma-separated
  run: |
    [ -z "$WEBHOOK_URLS" ] && exit 0

    PAYLOAD=$(jq -n \
      --arg app "$APP_NAME" \
      --arg env "$ENVIRONMENT" \
      --arg status "${{ job.status }}" \
      --arg sha "${{ github.sha }}" \
      --arg actor "${{ github.actor }}" \
      --arg url "https://$DOMAIN" \
      --arg run_url "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
      '{
        event: "deployment",
        app: $app,
        environment: $env,
        status: $status,
        commit_sha: $sha,
        deployed_by: $actor,
        app_url: $url,
        workflow_url: $run_url,
        timestamp: (now | todate)
      }')

    IFS=',' read -ra URLS <<< "$WEBHOOK_URLS"
    for URL in "${URLS[@]}"; do
      curl -X POST "$URL" \
        -H "Content-Type: application/json" \
        -H "X-Deploy-Event: deployment" \
        -H "X-Deploy-Signature: $(echo -n "$PAYLOAD" | openssl sha256 -hmac "$WEBHOOK_SECRET" -hex)" \
        -d "$PAYLOAD" || true
    done
```

#### Pre-configured Integrations

**Datadog:**
```yaml
- name: Notify Datadog
  if: success()
  env:
    DD_API_KEY: ${{ secrets.DD_API_KEY }}
  run: |
    [ -z "$DD_API_KEY" ] && exit 0

    curl -X POST "https://api.datadoghq.com/api/v1/events" \
      -H "DD-API-KEY: $DD_API_KEY" \
      -d "{
        \"title\": \"Deployment: $APP_NAME to $ENVIRONMENT\",
        \"text\": \"Deployed ${{ github.sha }} by ${{ github.actor }}\",
        \"tags\": [\"app:$APP_NAME\", \"env:$ENVIRONMENT\", \"deploy\"],
        \"alert_type\": \"info\"
      }"
```

**PagerDuty (on failure):**
```yaml
- name: Notify PagerDuty
  if: failure()
  env:
    PD_ROUTING_KEY: ${{ secrets.PAGERDUTY_ROUTING_KEY }}
  run: |
    [ -z "$PD_ROUTING_KEY" ] && exit 0

    curl -X POST "https://events.pagerduty.com/v2/enqueue" \
      -H "Content-Type: application/json" \
      -d "{
        \"routing_key\": \"$PD_ROUTING_KEY\",
        \"event_action\": \"trigger\",
        \"payload\": {
          \"summary\": \"Deployment failed: $APP_NAME to $ENVIRONMENT\",
          \"severity\": \"error\",
          \"source\": \"dokku-deploy\",
          \"custom_details\": {
            \"app\": \"$APP_NAME\",
            \"environment\": \"$ENVIRONMENT\",
            \"commit\": \"${{ github.sha }}\",
            \"actor\": \"${{ github.actor }}\"
          }
        },
        \"links\": [{
          \"href\": \"${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\",
          \"text\": \"View Workflow\"
        }]
      }"
```

**Jira (update ticket):**
```yaml
- name: Update Jira ticket
  env:
    JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
    JIRA_USER: ${{ secrets.JIRA_USER }}
    JIRA_TOKEN: ${{ secrets.JIRA_TOKEN }}
  run: |
    [ -z "$JIRA_BASE_URL" ] && exit 0

    # Extract ticket ID from commit message or branch
    TICKET=$(echo "${{ github.event.head_commit.message }}" | grep -oE '[A-Z]+-[0-9]+' | head -1)
    [ -z "$TICKET" ] && exit 0

    curl -X POST "$JIRA_BASE_URL/rest/api/3/issue/$TICKET/comment" \
      -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"body\": {
          \"type\": \"doc\",
          \"version\": 1,
          \"content\": [{
            \"type\": \"paragraph\",
            \"content\": [{
              \"type\": \"text\",
              \"text\": \"Deployed to $ENVIRONMENT: \"
            }, {
              \"type\": \"text\",
              \"text\": \"https://$DOMAIN\",
              \"marks\": [{\"type\": \"link\", \"attrs\": {\"href\": \"https://$DOMAIN\"}}]
            }]
          }]
        }
      }"
```

#### Configuration
Add to `.dokku/config.yml`:

```yaml
webhooks:
  outbound:
    - url: https://api.example.com/deploy-hook
      events: [deploy, rollback]
      environments: [production]
      secret_env: WEBHOOK_SECRET_1
    - url: https://other.service.com/notify
      events: [deploy]
      environments: [production, staging]

  integrations:
    datadog:
      enabled: true
      api_key_env: DD_API_KEY
    pagerduty:
      enabled: true
      routing_key_env: PAGERDUTY_ROUTING_KEY
      on_failure_only: true
    jira:
      enabled: true
      extract_ticket_from: commit_message
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add webhook steps
- `docs/FEATURES.md` - Document webhook configuration
- `docs/INTEGRATIONS.md` - New file with integration guides

### Acceptance Criteria
- [ ] Trigger deploys via repository_dispatch
- [ ] Send webhooks to configured URLs after deploy
- [ ] HMAC signature for webhook security
- [ ] Pre-built integrations (Datadog, PagerDuty, Jira)
- [ ] Configurable per-environment

---

## 8. Custom Domain Management

**Priority:** Medium | **Effort:** Medium | **Impact:** Medium

### Overview
Manage custom domains via workflow, with automatic SSL and health monitoring.

### Current State
- Domains set via Dokku config or SSH
- Manual SSL provisioning
- No domain health monitoring

### Proposed Solution

#### Domain Management Workflow
```yaml
# .github/workflows/domains.yml
name: Domain Management

on:
  workflow_dispatch:
    inputs:
      app_name:
        description: 'App name'
        required: true
      action:
        type: choice
        options: [add, remove, list]
        required: true
      domain:
        description: 'Domain (for add/remove)'
        required: false
      enable_ssl:
        description: 'Enable SSL'
        type: boolean
        default: true

jobs:
  manage-domain:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOKKU_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

      - name: List domains
        if: inputs.action == 'list'
        run: |
          echo "## Domains for ${{ inputs.app_name }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            domains:report ${{ inputs.app_name }} >> $GITHUB_STEP_SUMMARY

      - name: Add domain
        if: inputs.action == 'add'
        run: |
          APP="${{ inputs.app_name }}"
          DOMAIN="${{ inputs.domain }}"

          # Validate domain format
          if ! echo "$DOMAIN" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$'; then
            echo "::error::Invalid domain format: $DOMAIN"
            exit 1
          fi

          # Add domain
          ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            domains:add $APP $DOMAIN

          echo "✅ Domain $DOMAIN added to $APP"

      - name: Enable SSL
        if: inputs.action == 'add' && inputs.enable_ssl
        run: |
          APP="${{ inputs.app_name }}"

          # Wait for DNS propagation
          echo "Waiting for DNS propagation..."
          for i in {1..30}; do
            if dig +short ${{ inputs.domain }} | grep -q .; then
              echo "DNS resolved"
              break
            fi
            sleep 10
          done

          # Enable SSL
          ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            letsencrypt:enable $APP || echo "::warning::SSL provisioning may have failed"

      - name: Remove domain
        if: inputs.action == 'remove'
        run: |
          ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            domains:remove ${{ inputs.app_name }} ${{ inputs.domain }}

          echo "✅ Domain ${{ inputs.domain }} removed"

      - name: Verify domain
        if: inputs.action == 'add'
        run: |
          DOMAIN="${{ inputs.domain }}"
          sleep 10

          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")

          if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
            echo "✅ Domain verified: https://$DOMAIN"
          else
            echo "::warning::Domain returned HTTP $HTTP_STATUS - may need DNS configuration"
          fi
```

#### Domain Configuration File
Support domain configuration in `.dokku/config.yml`:

```yaml
domains:
  production:
    primary: myapp.example.com
    aliases:
      - www.myapp.example.com
      - app.example.com
    ssl: true
    redirect_www: true  # Redirect www to non-www

  staging:
    primary: staging.myapp.example.com
    ssl: true
```

#### Process in deploy.yml:
```yaml
- name: Configure custom domains
  run: |
    if [ -f ".dokku/config.yml" ]; then
      PRIMARY=$(yq e ".domains.$ENVIRONMENT.primary" .dokku/config.yml)

      if [ -n "$PRIMARY" ] && [ "$PRIMARY" != "null" ]; then
        # Add primary domain
        ssh dokku domains:add $APP_NAME $PRIMARY 2>/dev/null || true

        # Add aliases
        ALIASES=$(yq e ".domains.$ENVIRONMENT.aliases[]" .dokku/config.yml 2>/dev/null)
        for ALIAS in $ALIASES; do
          ssh dokku domains:add $APP_NAME $ALIAS 2>/dev/null || true
        done

        # Configure www redirect
        REDIRECT_WWW=$(yq e ".domains.$ENVIRONMENT.redirect_www" .dokku/config.yml)
        if [ "$REDIRECT_WWW" == "true" ]; then
          ssh dokku redirect:set $APP_NAME www.$PRIMARY $PRIMARY 2>/dev/null || true
        fi
      fi
    fi
```

#### Domain Health Monitoring
Add to scheduled.yml:

```yaml
- name: Check custom domain health
  run: |
    UNHEALTHY_DOMAINS=""

    for APP in $(ssh dokku apps:list | tail -n +2); do
      DOMAINS=$(ssh dokku domains:report $APP --domains-app-vhosts 2>/dev/null || echo "")

      for DOMAIN in $DOMAINS; do
        # Skip default dokku domains
        [[ "$DOMAIN" == *"$BASE_DOMAIN" ]] && continue

        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")

        if [ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 400 ]; then
          UNHEALTHY_DOMAINS="$UNHEALTHY_DOMAINS\n- $DOMAIN ($APP): HTTP $STATUS"
        fi
      done
    done

    if [ -n "$UNHEALTHY_DOMAINS" ]; then
      echo "::warning::Unhealthy custom domains:$UNHEALTHY_DOMAINS"
    fi
```

### Files to Create/Modify
- `.github/workflows/domains.yml` - New workflow
- `.github/workflows/deploy.yml` - Add domain config
- `.github/workflows/scheduled.yml` - Add domain health check
- `docs/FEATURES.md` - Document domain management

### Acceptance Criteria
- [ ] Add/remove domains via workflow
- [ ] Automatic SSL provisioning
- [ ] Domain configuration in config.yml
- [ ] www redirect support
- [ ] Domain health monitoring
- [ ] DNS propagation check

---

## 9. Secrets Management

**Priority:** High | **Effort:** High | **Impact:** High

### Overview
Integrate with external secret managers to sync secrets and support automatic rotation.

### Current State
- Secrets stored in GitHub Secrets only
- Manual rotation
- No external vault integration

### Proposed Solution

#### Supported Backends

**AWS Secrets Manager:**
```yaml
# .github/workflows/sync-secrets.yml
name: Sync Secrets

on:
  schedule:
    - cron: '0 * * * *'  # Hourly
  workflow_dispatch:

jobs:
  sync-aws:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Fetch secrets from AWS
        run: |
          # Get secret from AWS Secrets Manager
          SECRET_JSON=$(aws secretsmanager get-secret-value \
            --secret-id "dokku/${{ inputs.app_name }}/production" \
            --query 'SecretString' --output text)

          # Parse and set as env vars
          echo "$SECRET_JSON" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > /tmp/secrets.env

      - name: Apply to Dokku
        run: |
          ssh dokku config:set --no-restart $APP_NAME $(cat /tmp/secrets.env | tr '\n' ' ')
          rm /tmp/secrets.env
```

**HashiCorp Vault:**
```yaml
- name: Fetch secrets from Vault
  env:
    VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
    VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
  run: |
    # Get secrets from Vault
    SECRETS=$(vault kv get -format=json secret/dokku/$APP_NAME/$ENVIRONMENT | jq -r '.data.data')

    # Convert to KEY=value format
    echo "$SECRETS" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > /tmp/secrets.env
```

**1Password:**
```yaml
- name: Fetch secrets from 1Password
  uses: 1password/load-secrets-action@v1
  with:
    export-env: true
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    DATABASE_URL: op://Deployments/${{ inputs.app_name }}/DATABASE_URL
    API_KEY: op://Deployments/${{ inputs.app_name }}/API_KEY
```

#### Secret Rotation
```yaml
# .github/workflows/rotate-secrets.yml
name: Rotate Secrets

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly
  workflow_dispatch:
    inputs:
      secret_type:
        type: choice
        options: [database, api_keys, all]

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
      - name: Rotate database password
        if: inputs.secret_type == 'database' || inputs.secret_type == 'all'
        run: |
          NEW_PASSWORD=$(openssl rand -base64 32)

          # Update in vault
          vault kv patch secret/dokku/$APP_NAME/production \
            DATABASE_PASSWORD="$NEW_PASSWORD"

          # Update database user password
          ssh dokku postgres:connect postgres-$APP_NAME <<EOF
          ALTER USER app PASSWORD '$NEW_PASSWORD';
          EOF

          # Update app config
          OLD_URL=$(ssh dokku config:get $APP_NAME DATABASE_URL)
          NEW_URL=$(echo "$OLD_URL" | sed "s/:.*@/:$NEW_PASSWORD@/")
          ssh dokku config:set $APP_NAME DATABASE_URL="$NEW_URL"

      - name: Notify about rotation
        run: |
          curl -X POST "$SLACK_WEBHOOK_URL" \
            -d '{"text": "🔑 Secrets rotated for ${{ inputs.app_name }}"}'
```

#### Configuration
```yaml
# .dokku/config.yml
secrets:
  backend: aws-secrets-manager  # or: vault, 1password, github

  aws:
    region: us-east-1
    secret_prefix: "dokku/"
    role_arn_env: AWS_ROLE_ARN

  vault:
    address_env: VAULT_ADDR
    path_prefix: "secret/dokku"
    auth_method: token  # or: approle, kubernetes

  rotation:
    enabled: true
    schedule: monthly
    types:
      - database_passwords
      - api_keys
    notify:
      - slack
      - email
```

#### Secret Diff Detection
Warn when secrets change between syncs:

```yaml
- name: Check for secret changes
  run: |
    # Get current secrets (names only)
    CURRENT=$(ssh dokku config:keys $APP_NAME | sort)

    # Get expected secrets from vault
    EXPECTED=$(vault kv get -format=json secret/dokku/$APP_NAME | jq -r '.data.data | keys[]' | sort)

    # Compare
    ADDED=$(comm -13 <(echo "$CURRENT") <(echo "$EXPECTED"))
    REMOVED=$(comm -23 <(echo "$CURRENT") <(echo "$EXPECTED"))

    if [ -n "$ADDED" ] || [ -n "$REMOVED" ]; then
      echo "::warning::Secret configuration has changed"
      echo "Added: $ADDED"
      echo "Removed: $REMOVED"
    fi
```

### Files to Create/Modify
- `.github/workflows/sync-secrets.yml` - New workflow
- `.github/workflows/rotate-secrets.yml` - New workflow
- `.github/workflows/deploy.yml` - Add secret sync step
- `docs/SECRETS.md` - New documentation

### Acceptance Criteria
- [ ] AWS Secrets Manager integration
- [ ] HashiCorp Vault integration
- [ ] 1Password integration
- [ ] Automatic secret rotation
- [ ] Secret change detection
- [ ] Rotation notifications

---

## 10. Canary Deployments

**Priority:** High | **Effort:** High | **Impact:** High

### Overview
Deploy to a subset of traffic first, monitor for errors, and automatically rollback if issues detected.

### Current State
- All-or-nothing deployments
- Manual monitoring required
- Manual rollback

### Proposed Solution

#### Architecture
Use Dokku's process scaling with a canary container:

```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │     (nginx)     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │  Stable  │  │  Stable  │  │  Canary  │
        │  (v1.0)  │  │  (v1.0)  │  │  (v1.1)  │
        │   90%    │  │   90%    │  │   10%    │
        └──────────┘  └──────────┘  └──────────┘
```

#### Canary Deployment Workflow
```yaml
# .github/workflows/canary-deploy.yml
name: Canary Deployment

on:
  workflow_dispatch:
    inputs:
      app_name:
        required: true
      canary_percent:
        description: 'Percentage of traffic to canary (10-50)'
        default: '10'
      monitoring_duration:
        description: 'Minutes to monitor before full rollout'
        default: '15'
      error_threshold:
        description: 'Error rate % to trigger rollback'
        default: '5'

jobs:
  canary-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOKKU_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

      - name: Get current stable version
        id: stable
        run: |
          STABLE_SHA=$(ssh -i ~/.ssh/deploy_key dokku@${{ secrets.DOKKU_HOST }} \
            config:get ${{ inputs.app_name }} GIT_REV)
          echo "sha=$STABLE_SHA" >> $GITHUB_OUTPUT
          echo "Stable version: $STABLE_SHA"

      - name: Deploy canary version
        run: |
          APP="${{ inputs.app_name }}"
          CANARY_APP="${APP}-canary"

          # Create canary app if not exists
          ssh dokku apps:exists $CANARY_APP 2>/dev/null || \
            ssh dokku apps:create $CANARY_APP

          # Clone config from stable
          ssh dokku config:export $APP | ssh dokku config:set $CANARY_APP

          # Deploy canary
          git remote add canary dokku@${{ secrets.DOKKU_HOST }}:$CANARY_APP 2>/dev/null || true
          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key" git push canary HEAD:main --force

          # Tag canary version
          ssh dokku config:set $CANARY_APP CANARY=true GIT_REV=${{ github.sha }}

      - name: Configure traffic split
        run: |
          APP="${{ inputs.app_name }}"
          CANARY_APP="${APP}-canary"
          CANARY_PCT="${{ inputs.canary_percent }}"
          STABLE_PCT=$((100 - CANARY_PCT))

          # Get app domains
          DOMAIN=$(ssh dokku domains:report $APP --domains-app-vhosts | head -1)

          # Configure nginx upstream with weights
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo tee /etc/nginx/conf.d/${APP}-canary.conf << EOF
          upstream ${APP}_canary {
              server $(ssh dokku network:report $CANARY_APP --network-container-ip-addresses):5000 weight=$CANARY_PCT;
          }

          upstream ${APP}_stable {
              server $(ssh dokku network:report $APP --network-container-ip-addresses):5000 weight=$STABLE_PCT;
          }

          upstream ${APP}_combined {
              server $(ssh dokku network:report $APP --network-container-ip-addresses):5000 weight=$STABLE_PCT;
              server $(ssh dokku network:report $CANARY_APP --network-container-ip-addresses):5000 weight=$CANARY_PCT;
          }
          EOF

          # Update nginx config to use combined upstream
          ssh dokku nginx:build-config $APP
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo nginx -s reload

      - name: Monitor canary
        id: monitor
        run: |
          DURATION=${{ inputs.monitoring_duration }}
          ERROR_THRESHOLD=${{ inputs.error_threshold }}
          APP="${{ inputs.app_name }}"
          CANARY_APP="${APP}-canary"

          echo "Monitoring canary for $DURATION minutes..."
          echo "Error threshold: $ERROR_THRESHOLD%"

          TOTAL_REQUESTS=0
          ERROR_REQUESTS=0

          for i in $(seq 1 $DURATION); do
            sleep 60

            # Get metrics from canary app logs
            MINUTE_TOTAL=$(ssh dokku logs $CANARY_APP --num 100 | grep -c "HTTP" || echo "0")
            MINUTE_ERRORS=$(ssh dokku logs $CANARY_APP --num 100 | grep -E "HTTP [45][0-9]{2}" | wc -l || echo "0")

            TOTAL_REQUESTS=$((TOTAL_REQUESTS + MINUTE_TOTAL))
            ERROR_REQUESTS=$((ERROR_REQUESTS + MINUTE_ERRORS))

            if [ "$TOTAL_REQUESTS" -gt 0 ]; then
              ERROR_RATE=$((ERROR_REQUESTS * 100 / TOTAL_REQUESTS))
            else
              ERROR_RATE=0
            fi

            echo "Minute $i: $MINUTE_TOTAL requests, $MINUTE_ERRORS errors (${ERROR_RATE}% total error rate)"

            if [ "$ERROR_RATE" -gt "$ERROR_THRESHOLD" ]; then
              echo "::error::Error rate ${ERROR_RATE}% exceeds threshold ${ERROR_THRESHOLD}%"
              echo "rollback=true" >> $GITHUB_OUTPUT
              exit 0
            fi
          done

          echo "Canary healthy after $DURATION minutes"
          echo "rollback=false" >> $GITHUB_OUTPUT

      - name: Rollback canary
        if: steps.monitor.outputs.rollback == 'true'
        run: |
          echo "Rolling back canary deployment..."

          # Remove canary from traffic
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo rm -f /etc/nginx/conf.d/${{ inputs.app_name }}-canary.conf
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo nginx -s reload

          # Destroy canary app
          ssh dokku apps:destroy ${{ inputs.app_name }}-canary --force

          echo "::error::Canary deployment rolled back due to high error rate"
          exit 1

      - name: Promote canary to stable
        if: steps.monitor.outputs.rollback == 'false'
        run: |
          APP="${{ inputs.app_name }}"
          CANARY_APP="${APP}-canary"

          echo "Promoting canary to stable..."

          # Deploy canary version to main app
          git remote add dokku dokku@${{ secrets.DOKKU_HOST }}:$APP 2>/dev/null || true
          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key" git push dokku HEAD:main --force

          # Remove canary config
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo rm -f /etc/nginx/conf.d/${APP}-canary.conf
          ssh dokku@${{ secrets.DOKKU_HOST }} sudo nginx -s reload

          # Cleanup canary app
          ssh dokku apps:destroy $CANARY_APP --force

          echo "✅ Canary promoted to stable"

      - name: Notify result
        if: always()
        run: |
          if [ "${{ steps.monitor.outputs.rollback }}" == "true" ]; then
            TITLE="❌ Canary Deployment Failed"
            COLOR=15158332
          else
            TITLE="✅ Canary Deployment Successful"
            COLOR=3066993
          fi

          curl -H "Content-Type: application/json" \
            -d "{\"embeds\": [{\"title\": \"$TITLE\", \"color\": $COLOR, \"fields\": [
              {\"name\": \"App\", \"value\": \"${{ inputs.app_name }}\", \"inline\": true},
              {\"name\": \"Canary %\", \"value\": \"${{ inputs.canary_percent }}%\", \"inline\": true},
              {\"name\": \"Duration\", \"value\": \"${{ inputs.monitoring_duration }} min\", \"inline\": true}
            ]}]}" \
            "${{ secrets.DISCORD_WEBHOOK_URL }}"
```

#### Configuration
```yaml
# .dokku/config.yml
canary:
  enabled: true
  environments:
    production:
      initial_percent: 10
      increment_percent: 20
      monitoring_duration: 15  # minutes per stage
      error_threshold: 5       # percent
      metrics:
        - error_rate
        - response_time_p99
        - cpu_usage
      rollback_on:
        error_rate: "> 5%"
        response_time_p99: "> 2000ms"
```

### Files to Create/Modify
- `.github/workflows/canary-deploy.yml` - New workflow
- `docs/CANARY.md` - New documentation

### Acceptance Criteria
- [ ] Deploy to configurable traffic percentage
- [ ] Monitor error rate during canary
- [ ] Automatic rollback on threshold breach
- [ ] Gradual traffic increase option
- [ ] Notifications for canary status
- [ ] Cleanup on success/failure

---

## 11. Deployment Notifications to PR/Commit

**Priority:** High | **Effort:** Low | **Impact:** High

### Overview
Enhanced deployment feedback directly on PRs and commits beyond status checks.

### Current State
- Bot comments on PR for preview URLs
- Status checks (planned in #1)

### Proposed Solution

#### Deployment Summary Comment
```yaml
- name: Post deployment summary
  uses: actions/github-script@v7
  if: always()
  with:
    script: |
      const status = '${{ job.status }}';
      const emoji = status === 'success' ? '✅' : '❌';
      const domain = '${{ env.DOMAIN }}';
      const environment = '${{ env.ENVIRONMENT }}';
      const duration = '${{ steps.deploy.outputs.duration }}';
      const sha = context.sha.substring(0, 7);

      const body = `## ${emoji} Deployment ${status === 'success' ? 'Successful' : 'Failed'}

      | | |
      |---|---|
      | **Environment** | ${environment} |
      | **URL** | ${status === 'success' ? `[${domain}](https://${domain})` : 'N/A'} |
      | **Commit** | \`${sha}\` |
      | **Duration** | ${duration} |
      | **Workflow** | [View logs](${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}) |

      ${status !== 'success' ? '### ⚠️ Check the workflow logs for details' : ''}
      `;

      // Find PR associated with this commit
      const prs = await github.rest.repos.listPullRequestsAssociatedWithCommit({
        owner: context.repo.owner,
        repo: context.repo.repo,
        commit_sha: context.sha
      });

      if (prs.data.length > 0) {
        // Comment on PR
        for (const pr of prs.data) {
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: pr.number,
            body
          });
        }
      }
```

#### Commit Comment for Non-PR Deploys
```yaml
- name: Comment on commit
  if: github.event_name == 'push'
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.repos.createCommitComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        commit_sha: context.sha,
        body: `Deployed to ${{ env.ENVIRONMENT }}: https://${{ env.DOMAIN }}`
      });
```

#### GitHub Deployment API
Track deployments properly in GitHub:

```yaml
- name: Create deployment
  id: deployment
  uses: actions/github-script@v7
  with:
    script: |
      const deployment = await github.rest.repos.createDeployment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        ref: context.sha,
        environment: '${{ env.ENVIRONMENT }}',
        auto_merge: false,
        required_contexts: []
      });
      return deployment.data.id;

- name: Update deployment status
  if: always()
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.repos.createDeploymentStatus({
        owner: context.repo.owner,
        repo: context.repo.repo,
        deployment_id: ${{ steps.deployment.outputs.result }},
        state: '${{ job.status }}' === 'success' ? 'success' : 'failure',
        environment_url: 'https://${{ env.DOMAIN }}',
        log_url: `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`
      });
```

### Files to Modify
- `.github/workflows/deploy.yml`
- `.github/workflows/preview.yml`

### Acceptance Criteria
- [ ] Deployment summary comment on PRs
- [ ] Commit comments for direct pushes
- [ ] GitHub Deployments API integration
- [ ] Environment URLs in deployment history

---

## 12. Multi-Region/Multi-Server Support

**Priority:** Medium | **Effort:** High | **Impact:** High

### Overview
Deploy to multiple Dokku servers for redundancy or geographic distribution.

### Current State
- Single server deployment
- No multi-region support

### Proposed Solution

#### Server Configuration
```yaml
# .dokku/config.yml
servers:
  us-east:
    host: dokku-us-east.example.com
    primary: true
    region: us-east-1
  us-west:
    host: dokku-us-west.example.com
    region: us-west-2
  eu-west:
    host: dokku-eu.example.com
    region: eu-west-1

deployment:
  strategy: all          # all, primary-only, nearest
  failover: true         # Deploy to others if one fails
  parallel: true         # Deploy to all servers simultaneously
```

#### Multi-Server Deploy Workflow
```yaml
jobs:
  setup:
    outputs:
      servers: ${{ steps.servers.outputs.matrix }}
    steps:
      - name: Determine target servers
        id: servers
        run: |
          if [ -f ".dokku/config.yml" ]; then
            SERVERS=$(yq e '.servers | keys | @json' .dokku/config.yml)
          else
            SERVERS='["default"]'
          fi
          echo "matrix={\"server\":$SERVERS}" >> $GITHUB_OUTPUT

  deploy:
    needs: setup
    strategy:
      matrix: ${{ fromJson(needs.setup.outputs.servers) }}
      fail-fast: false  # Continue deploying to other servers on failure
    steps:
      - name: Get server config
        id: config
        run: |
          if [ "${{ matrix.server }}" == "default" ]; then
            echo "host=${{ secrets.DOKKU_HOST }}" >> $GITHUB_OUTPUT
          else
            HOST=$(yq e ".servers.${{ matrix.server }}.host" .dokku/config.yml)
            echo "host=$HOST" >> $GITHUB_OUTPUT
          fi

      - name: Deploy to ${{ matrix.server }}
        run: |
          git remote add ${{ matrix.server }} dokku@${{ steps.config.outputs.host }}:$APP_NAME
          git push ${{ matrix.server }} HEAD:main --force

  verify:
    needs: deploy
    steps:
      - name: Verify all deployments
        run: |
          # Check health on all servers
          for SERVER in $SERVERS; do
            DOMAIN="$APP_NAME.$(get_domain $SERVER)"
            curl -sf "https://$DOMAIN/health" || echo "::warning::$SERVER unhealthy"
          done
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add multi-server support
- `docs/MULTI-REGION.md` - New documentation

### Acceptance Criteria
- [ ] Configure multiple servers in config
- [ ] Parallel deployment to all servers
- [ ] Failover if one server fails
- [ ] Server-specific secrets support
- [ ] Health check across all servers

---

## 13. Resource Auto-Scaling

**Priority:** Medium | **Effort:** High | **Impact:** High

### Overview
Automatically scale app resources based on metrics or schedules.

### Current State
- Fixed resource allocation
- Manual scaling via SSH

### Proposed Solution

#### Scaling Configuration
```yaml
# .dokku/config.yml
scaling:
  production:
    min_instances: 2
    max_instances: 10

    metrics:
      cpu:
        target: 70           # Target CPU %
        scale_up_threshold: 80
        scale_down_threshold: 50
      memory:
        scale_up_threshold: 85

    schedule:
      - cron: "0 9 * * 1-5"  # 9 AM weekdays
        instances: 5          # Scale up for business hours
      - cron: "0 18 * * 1-5" # 6 PM weekdays
        instances: 2          # Scale down after hours

    cooldown:
      scale_up: 3m
      scale_down: 10m
```

#### Autoscaler Workflow
```yaml
# .github/workflows/autoscaler.yml
name: Autoscaler

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes

jobs:
  scale:
    runs-on: ubuntu-latest
    steps:
      - name: Check metrics and scale
        run: |
          for APP in $(ssh dokku apps:list | tail -n +2); do
            # Get current metrics
            CPU=$(ssh dokku ps:report $APP --ps-running-cpu 2>/dev/null || echo "0")
            MEMORY=$(ssh dokku ps:report $APP --ps-running-memory 2>/dev/null || echo "0")
            CURRENT=$(ssh dokku ps:scale $APP | grep web | awk '{print $2}')

            # Get config
            MIN=$(yq e ".scaling.production.min_instances" .dokku/config.yml)
            MAX=$(yq e ".scaling.production.max_instances" .dokku/config.yml)
            CPU_UP=$(yq e ".scaling.production.metrics.cpu.scale_up_threshold" .dokku/config.yml)
            CPU_DOWN=$(yq e ".scaling.production.metrics.cpu.scale_down_threshold" .dokku/config.yml)

            # Determine scaling action
            if [ "$CPU" -gt "$CPU_UP" ] && [ "$CURRENT" -lt "$MAX" ]; then
              NEW=$((CURRENT + 1))
              ssh dokku ps:scale $APP web=$NEW
              echo "Scaled $APP up to $NEW instances (CPU: $CPU%)"
            elif [ "$CPU" -lt "$CPU_DOWN" ] && [ "$CURRENT" -gt "$MIN" ]; then
              NEW=$((CURRENT - 1))
              ssh dokku ps:scale $APP web=$NEW
              echo "Scaled $APP down to $NEW instances (CPU: $CPU%)"
            fi
          done
```

### Files to Create/Modify
- `.github/workflows/autoscaler.yml` - New workflow
- `docs/SCALING.md` - New documentation

### Acceptance Criteria
- [ ] Metric-based scaling (CPU, memory)
- [ ] Scheduled scaling
- [ ] Min/max instance limits
- [ ] Cooldown periods
- [ ] Scale to zero for previews

---

## 14. Cost Tracking

**Priority:** Low | **Effort:** Medium | **Impact:** Medium

### Overview
Track resource usage and estimate costs per app.

### Proposed Solution

#### Resource Metrics Collection
```yaml
# .github/workflows/cost-report.yml
name: Cost Report

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - name: Collect resource usage
        run: |
          echo "# Monthly Resource Report" > report.md
          echo "" >> report.md

          TOTAL_CPU=0
          TOTAL_MEMORY=0

          for APP in $(ssh dokku apps:list | tail -n +2); do
            CPU=$(ssh dokku resource:report $APP --resource-limits-cpu || echo "0")
            MEMORY=$(ssh dokku resource:report $APP --resource-limits-memory || echo "0")

            # Estimate cost (example: $0.01/CPU-hour, $0.005/GB-hour)
            CPU_HOURS=$((CPU * 720))  # 720 hours/month
            MEM_GB=$(echo "$MEMORY" | sed 's/m//' | awk '{print $1/1024}')
            MEM_HOURS=$(echo "$MEM_GB * 720" | bc)

            CPU_COST=$(echo "$CPU_HOURS * 0.01" | bc)
            MEM_COST=$(echo "$MEM_HOURS * 0.005" | bc)

            echo "| $APP | $CPU | $MEMORY | \$$CPU_COST | \$$MEM_COST |" >> report.md
          done

      - name: Send report
        run: |
          # Email or Slack the report
```

### Files to Create/Modify
- `.github/workflows/cost-report.yml` - New workflow
- `dashboard/` - Add cost section

### Acceptance Criteria
- [ ] Monthly cost reports
- [ ] Per-app breakdown
- [ ] Budget alerts
- [ ] Historical trends

---

## 15. Log Aggregation

**Priority:** Medium | **Effort:** Medium | **Impact:** Medium

### Overview
Ship logs to external services for centralized search and alerting.

### Proposed Solution

#### Log Shipping Configuration
```yaml
# .dokku/config.yml
logging:
  destinations:
    - type: datadog
      api_key_env: DD_API_KEY
    - type: papertrail
      host: logs.papertrailapp.com
      port: 12345
    - type: loki
      url: http://loki.example.com:3100
```

#### Dokku Log Drain Setup
```yaml
- name: Configure log drains
  run: |
    APP="${{ env.APP_NAME }}"

    # Datadog
    if [ -n "$DD_API_KEY" ]; then
      ssh dokku docker-options:add $APP deploy,run \
        "-e DD_API_KEY=$DD_API_KEY"
    fi

    # Papertrail via logspout
    ssh dokku logs:set $APP drain "syslog+tls://logs.papertrailapp.com:12345"
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add log drain setup
- `docs/LOGGING.md` - New documentation

### Acceptance Criteria
- [ ] Datadog integration
- [ ] Papertrail integration
- [ ] Loki/Grafana integration
- [ ] Log-based alerting

---

## 16. Performance Monitoring

**Priority:** Medium | **Effort:** Medium | **Impact:** High

### Overview
Track response times, error rates, and performance metrics over time.

### Proposed Solution

#### Dashboard Metrics Enhancement
Add performance data to `apps.json`:

```json
{
  "apps": [{
    "name": "myapp",
    "metrics": {
      "response_time": {
        "p50": 145,
        "p95": 320,
        "p99": 580
      },
      "error_rate": 0.02,
      "requests_per_minute": 150,
      "apdex": 0.94
    }
  }]
}
```

#### Metrics Collection
```yaml
- name: Collect performance metrics
  run: |
    DOMAIN="${{ env.DOMAIN }}"

    # Run multiple requests for percentile calculation
    for i in {1..100}; do
      curl -s -o /dev/null -w "%{time_total}\n" "https://$DOMAIN/health" >> times.txt
    done

    # Calculate percentiles
    P50=$(sort -n times.txt | awk 'NR==50{print $1*1000}')
    P95=$(sort -n times.txt | awk 'NR==95{print $1*1000}')
    P99=$(sort -n times.txt | awk 'NR==99{print $1*1000}')

    echo "Response times: p50=${P50}ms p95=${P95}ms p99=${P99}ms"
```

### Files to Create/Modify
- `.github/workflows/scheduled.yml` - Add metrics collection
- `dashboard/` - Add performance charts

### Acceptance Criteria
- [ ] Response time percentiles
- [ ] Error rate tracking
- [ ] Historical charts in dashboard
- [ ] Apdex score calculation

---

## 17. Database Management UI

**Priority:** Low | **Effort:** High | **Impact:** Medium

### Overview
Dashboard interface for database operations.

### Proposed Solution

Add to dashboard:
- Database size and connection count
- One-click backup/restore
- Query performance (if available)
- Connection string viewer (masked)

### Files to Create/Modify
- `dashboard/index.html` - Add database section
- `.github/workflows/` - Add database API endpoints via workflow_dispatch

### Acceptance Criteria
- [ ] View database stats
- [ ] Trigger backups from UI
- [ ] View backup history
- [ ] Database cloning

---

## 18. App Templates

**Priority:** Medium | **Effort:** Low | **Impact:** Medium

### Overview
Pre-configured templates for common application stacks.

### Proposed Solution

#### Template Repository Structure
```
template-repo/
├── templates/
│   ├── python-fastapi/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   ├── Procfile
│   │   ├── .dokku/
│   │   └── .github/workflows/
│   ├── node-express/
│   ├── ruby-rails/
│   └── go-fiber/
└── scripts/
    └── create-from-template.sh
```

#### Template CLI
```bash
# Create new app from template
./scripts/create-from-template.sh python-fastapi my-new-app

# Or via GitHub template repos
gh repo create my-new-app --template signalwire-demos/template-python-fastapi
```

### Files to Create
- `templates/` directory with starter apps
- `scripts/create-from-template.sh`
- `docs/TEMPLATES.md`

### Acceptance Criteria
- [ ] Python FastAPI template
- [ ] Node.js Express template
- [ ] Ruby Rails template
- [ ] Go template
- [ ] One-command setup

---

## 19. CLI Improvements

**Priority:** Medium | **Effort:** Medium | **Impact:** Medium

### Overview
Enhance the dokku-cli tool with interactive mode, completions, and more features.

### Proposed Solution

#### Interactive Mode
```bash
dokku-cli interactive
# Opens TUI with app selection, logs, etc.
```

#### Shell Completions
```bash
# bash completion
_dokku_cli_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local commands="list info logs restart config deploy rollback lock unlock db"

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  elif [ $COMP_CWORD -eq 2 ]; then
    # Complete with app names
    local apps=$(dokku-cli list --quiet 2>/dev/null)
    COMPREPLY=($(compgen -W "$apps" -- "$cur"))
  fi
}
complete -F _dokku_cli_completions dokku-cli
```

#### Config File
```yaml
# ~/.dokku-cli.yml
default_server: dokku.example.com
default_user: dokku
ssh_key: ~/.ssh/dokku_deploy_key

aliases:
  prod: myapp
  stg: myapp-staging

notifications:
  slack_webhook: https://...
```

### Files to Create/Modify
- `cli/dokku-cli` - Add features
- `cli/completions/` - Shell completions
- `docs/CLI.md` - Enhanced documentation

### Acceptance Criteria
- [ ] Interactive TUI mode
- [ ] Bash/Zsh/Fish completions
- [ ] Config file support
- [ ] App aliases
- [ ] Output formatting options

---

## 20. Monorepo Support

**Priority:** Medium | **Effort:** Medium | **Impact:** Medium

### Overview
Deploy specific subdirectories from monorepos and detect which apps changed.

### Current State
- Deploys entire repository
- No change detection

### Proposed Solution

#### Monorepo Configuration
```yaml
# .dokku/monorepo.yml
apps:
  api:
    path: packages/api
    triggers:
      - packages/api/**
      - packages/shared/**
  web:
    path: packages/web
    triggers:
      - packages/web/**
      - packages/shared/**
  worker:
    path: services/worker
    triggers:
      - services/worker/**
```

#### Change Detection
```yaml
- name: Detect changed apps
  id: changes
  run: |
    CHANGED_FILES=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }})
    APPS_TO_DEPLOY=""

    for APP in $(yq e '.apps | keys[]' .dokku/monorepo.yml); do
      TRIGGERS=$(yq e ".apps.$APP.triggers[]" .dokku/monorepo.yml)

      for TRIGGER in $TRIGGERS; do
        if echo "$CHANGED_FILES" | grep -q "$TRIGGER"; then
          APPS_TO_DEPLOY="$APPS_TO_DEPLOY $APP"
          break
        fi
      done
    done

    echo "apps=$APPS_TO_DEPLOY" >> $GITHUB_OUTPUT

- name: Deploy changed apps
  run: |
    for APP in ${{ steps.changes.outputs.apps }}; do
      APP_PATH=$(yq e ".apps.$APP.path" .dokku/monorepo.yml)

      # Create subtree and push
      git subtree split --prefix=$APP_PATH -b deploy-$APP
      git push dokku deploy-$APP:main --force
    done
```

### Files to Create/Modify
- `.github/workflows/deploy.yml` - Add monorepo support
- `docs/MONOREPO.md` - New documentation

### Acceptance Criteria
- [ ] Configure multiple apps per repo
- [ ] Automatic change detection
- [ ] Deploy only changed apps
- [ ] Parallel deployment option
- [ ] Shared dependency handling

---

## Implementation Timeline

### Phase 1: Quick Wins ✅ COMPLETED
1. ✅ GitHub Commit Status Checks (#1)
2. ✅ Deploy Scheduling (#3)
3. ✅ Audit Log (#4)
4. ✅ Deployment Notifications (#11)

### Phase 2: Security & Compliance ✅ COMPLETED
5. ✅ Approval Gates (#2) - Using GitHub Environment Protection
6. ✅ Dependency Scanning (#6) - Trivy integration
7. ✅ Webhook Integrations (#7) - Custom webhooks, Datadog, PagerDuty

### Phase 3: Advanced Deployment
8. Environment Promotion (#5)
9. Custom Domain Management (#8)
10. Secrets Management (#9)

### Phase 4: Reliability
11. Canary Deployments (#10)
12. Multi-Region Support (#12)
13. Resource Auto-Scaling (#13)

### Phase 5: Observability
14. Log Aggregation (#15)
15. Performance Monitoring (#16)
16. Cost Tracking (#14)

### Phase 6: Developer Experience
17. App Templates (#18)
18. CLI Improvements (#19)
19. Monorepo Support (#20)
20. Database Management UI (#17)

---

## Contributing

To contribute to any of these features:

1. Create an issue referencing the feature number
2. Fork and create a feature branch
3. Implement with tests where applicable
4. Submit PR with documentation updates
5. Request review from maintainers

## Questions?

- Open an issue for clarification
- Join #deployments channel on Slack
