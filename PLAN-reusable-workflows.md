# Plan: Reusable Workflows for Dokku Deploy System

## Overview

Convert the current copy-paste workflow model to GitHub Reusable Workflows, where the deploy logic lives in `dokku-deploy-system` and other repos simply call it.

---

## Current State

```
dokku-deploy-system/
├── template-repo/.github/workflows/
│   ├── deploy.yml      # ~160 lines, copied to each repo
│   └── preview.yml     # ~150 lines, copied to each repo

Each project repo:
├── .github/workflows/
│   ├── deploy.yml      # Full copy of template (gets out of sync)
│   └── preview.yml     # Full copy of template (gets out of sync)
```

## Target State

```
dokku-deploy-system/
├── .github/workflows/
│   ├── deploy.yml      # Reusable workflow (workflow_call)
│   └── preview.yml     # Reusable workflow (workflow_call)

Each project repo:
├── .github/workflows/
│   ├── deploy.yml      # ~15 lines, calls reusable workflow
│   └── preview.yml     # ~15 lines, calls reusable workflow
```

---

## Implementation Steps

### Step 1: Create Reusable Deploy Workflow

Create `.github/workflows/deploy.yml` in dokku-deploy-system with `workflow_call` trigger:

```yaml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      app_name_override:
        description: 'Override app name (optional)'
        required: false
        type: string
      health_check_path:
        description: 'Health check endpoint'
        required: false
        type: string
        default: '/health'
    secrets:
      DOKKU_HOST:
        required: true
      DOKKU_SSH_PRIVATE_KEY:
        required: true
      BASE_DOMAIN:
        required: true
      SLACK_WEBHOOK_URL:
        required: false

jobs:
  setup-environments:
    # ... auto-create environments logic

  deploy:
    # ... full deploy logic
    # Uses github.event.repository.name for app name
    # Reads vars from calling repo's environment
```

### Step 2: Create Reusable Preview Workflow

Create `.github/workflows/preview.yml` with same pattern for PR previews.

### Step 3: Create Caller Templates

Create minimal caller workflows in `template-repo/`:

**template-repo/.github/workflows/deploy.yml:**
```yaml
name: Deploy

on:
  workflow_dispatch:
  push:
    branches: [main, staging, develop]

jobs:
  deploy:
    uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main
    secrets: inherit
```

**template-repo/.github/workflows/preview.yml:**
```yaml
name: Preview

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

jobs:
  preview:
    uses: signalwire-demos/dokku-deploy-system/.github/workflows/preview.yml@main
    secrets: inherit
```

### Step 4: Update Documentation

- Update README.md with new caller workflow examples
- Update ONBOARDING.md with simplified setup
- Update SETUP-GUIDE.md with reusable workflow details
- Add MIGRATION.md for existing repos

### Step 5: Migrate Existing Repos

For each repo (santa, myagent, etc.):
1. Replace full workflow with minimal caller
2. Test deployment
3. Verify environment variables still work

---

## Technical Considerations

### Secrets Inheritance

Using `secrets: inherit` passes all secrets from the calling repo to the reusable workflow. This includes:
- Org-level secrets (DOKKU_HOST, etc.)
- Repo-level secrets (if any)

### Environment Variables

The reusable workflow will:
- Run in the context of the **calling repository**
- Have access to the calling repo's environments
- Read `vars` from the calling repo's environment settings

This is critical - `toJSON(vars)` will read from santa's production environment when santa calls the workflow.

### Repository Visibility

For reusable workflows to work across repos in the same org:
- The dokku-deploy-system repo must be **public**, OR
- Configure workflow access in org settings:
  Settings → Actions → General → "Access" → "Accessible from repositories in the organization"

### Versioning

Callers reference a specific ref:
```yaml
uses: signalwire-demos/dokku-deploy-system/.github/workflows/deploy.yml@main
```

Options:
- `@main` - Always latest (recommended for internal use)
- `@v1` - Tagged version (for stability)
- `@abc123` - Specific commit (for debugging)

### Environment Context

The `environment:` setting in the reusable workflow uses the **calling workflow's context**:
```yaml
environment: ${{ github.ref_name == 'main' && 'production' || ... }}
```

This correctly resolves to the calling repo's environments.

---

## File Changes Summary

### New Files in dokku-deploy-system

| File | Purpose |
|------|---------|
| `.github/workflows/deploy.yml` | Reusable deploy workflow |
| `.github/workflows/preview.yml` | Reusable preview workflow |
| `docs/MIGRATION.md` | Guide for migrating existing repos |

### Modified Files

| File | Changes |
|------|---------|
| `template-repo/.github/workflows/deploy.yml` | Replace with minimal caller |
| `template-repo/.github/workflows/preview.yml` | Replace with minimal caller |
| `README.md` | Update workflow examples |
| `docs/ONBOARDING.md` | Simplify setup instructions |
| `docs/SETUP-GUIDE.md` | Add reusable workflow section |

### Files to Delete

| File | Reason |
|------|--------|
| `github-workflows/deploy.yml` | Replaced by reusable workflow |
| `github-workflows/preview.yml` | Replaced by reusable workflow |

---

## Migration Plan for Existing Repos

### Phase 1: Prepare (No Downtime)
1. Create reusable workflows in dokku-deploy-system
2. Test with a new test repo
3. Verify environment variables work correctly

### Phase 2: Migrate One Repo
1. Pick lowest-risk repo (e.g., a dev/test app)
2. Replace workflow with caller
3. Trigger deploy, verify success
4. Monitor for issues

### Phase 3: Migrate Remaining Repos
1. Update santa, myagent, holyguacamole, etc.
2. Each migration is just replacing workflow file content

### Rollback Plan
If issues occur:
1. Revert to full workflow copy
2. Push to trigger redeploy
3. Investigate issue in reusable workflow

---

## Testing Checklist

- [ ] Deploy to production (main branch)
- [ ] Deploy to staging (staging branch)
- [ ] Deploy to development (develop branch)
- [ ] PR preview creation
- [ ] PR preview cleanup on close
- [ ] Environment variables are set correctly
- [ ] SSL certificates provision
- [ ] Health checks pass
- [ ] Slack notifications work
- [ ] Manual workflow_dispatch works

---

## Benefits After Migration

1. **Single Source of Truth** - Deploy logic in one place
2. **Instant Updates** - Fix a bug once, all repos get the fix
3. **Simpler Project Repos** - 15-line workflow vs 160-line workflow
4. **Consistent Behavior** - All repos deploy the same way
5. **Easier Onboarding** - New repos just add minimal caller

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Create reusable workflows | 1-2 hours |
| Test with new repo | 30 min |
| Update documentation | 1 hour |
| Migrate existing repos | 15 min each |
| **Total** | ~4-5 hours |

---

## Next Steps

1. Review and approve this plan
2. Create reusable workflows
3. Test thoroughly
4. Migrate repos one by one
