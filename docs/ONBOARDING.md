# Developer Onboarding Guide

Welcome! This guide will help you get set up for deploying applications with our Dokku-based deployment system.

## Overview

Our deployment system provides:

- **Auto-deploy on push** - Push to `main`, `staging`, or `develop` and your app deploys automatically
- **Preview environments** - Every pull request gets its own live preview URL
- **Automatic SSL** - Let's Encrypt certificates are provisioned automatically
- **Zero-downtime deploys** - Traffic switches only after health checks pass
- **Service provisioning** - PostgreSQL, Redis, etc. are created automatically

## Prerequisites

Before you begin, ensure you have:

- [ ] Access to the GitHub organization
- [ ] SSH key configured for your machine
- [ ] Git installed locally

## Quick Start (5 minutes)

### Step 1: Clone the Template

```bash
# Option A: Use GitHub template feature
gh repo create signalwire-demos/my-new-app --template signalwire-demos/app-template --private

# Option B: Copy from existing repo
git clone https://github.com/signalwire-demos/app-template my-new-app
cd my-new-app
rm -rf .git
git init
```

### Step 2: Configure Your App

1. **Edit `Procfile`** with your start command:
   ```
   web: uvicorn app:app --host 0.0.0.0 --port $PORT
   ```

2. **Edit `runtime.txt`** if needed:
   ```
   python-3.11
   ```

3. **Enable services** in `.dokku/services.yml`:
   ```yaml
   services:
     postgres:
       enabled: true
     redis:
       enabled: true
   ```

### Step 3: Push to GitHub

```bash
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/signalwire-demos/my-new-app.git
git push -u origin main
```

### Step 4: Verify Deployment

1. Go to **Actions** tab in GitHub
2. Watch the deployment workflow run
3. Once complete, your app is live at `https://my-new-app.yourdomain.com`

## Branch → Environment Mapping

| Branch | Environment | URL |
|--------|-------------|-----|
| `main` | Production | `app.yourdomain.com` |
| `staging` | Staging | `app-staging.yourdomain.com` |
| `develop` | Development | `app-dev.yourdomain.com` |
| PR #42 | Preview | `app-pr-42.yourdomain.com` |

## GitHub Secrets (Infrastructure Only)

These are configured organization-wide for infrastructure:

**Secrets:**
| Secret | Description |
|--------|-------------|
| `DOKKU_HOST` | Dokku server hostname |
| `DOKKU_SSH_PRIVATE_KEY` | SSH key for deployments |

**Variables:**
| Variable | Description |
|----------|-------------|
| `BASE_DOMAIN` | Base domain for apps |

**Note**: `BASE_DOMAIN` is a variable (not secret) so URLs are visible in logs. App-specific config uses Environment Variables.

## Adding App-Specific Configuration

For app configuration, use **GitHub Environment Variables** (not secrets):

1. Go to your repo → **Settings** → **Environments**
2. Select the environment (e.g., `production`)
3. Under **Environment variables**, add your config

| Variable | Example |
|----------|---------|
| `SIGNALWIRE_SPACE_NAME` | `myspace` |
| `SIGNALWIRE_PROJECT_ID` | `abc-123` |
| `SIGNALWIRE_TOKEN` | `PTxxx` |
| `RAPIDAPI_KEY` | `your-key` |

**Why Variables instead of Secrets?**
- Variables are visible in logs (easier debugging)
- Variables can be edited after creation
- The workflow dynamically sets all variables on each deploy
- Config is cleared and reset to ensure changes apply

Use in your app:
```python
import os
api_key = os.environ.get('RAPIDAPI_KEY')
```

**For truly sensitive values** (like production database passwords), you can still use GitHub Secrets at the repository level.

## Health Checks

Your app must respond to `/health` with HTTP 200 for zero-downtime deploys:

```python
# Python/FastAPI
@app.get("/health")
def health():
    return {"status": "ok"}
```

```javascript
// Node.js/Express
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});
```

## Working with Preview Environments

1. Create a branch and open a PR
2. GitHub Actions automatically deploys a preview (org members only)
3. Preview URL is posted as a comment on the PR
4. Preview is destroyed when PR is closed/merged
5. Daily cleanup catches any missed previews (6 AM UTC)

**Note for external contributors**: Preview auto-deploy is restricted to org members for security. If you're not an org member, a maintainer can manually trigger the preview from the Actions tab. See [Preview Security](FEATURES.md#preview-security) for details.

## Common Tasks

### View Logs

```bash
# Using CLI
dokku-cli logs myapp

# Or via SSH
ssh dokku@server logs myapp -t
```

### Set Environment Variables

```bash
# Using CLI
dokku-cli config:set myapp DEBUG=true

# Or via SSH
ssh dokku@server config:set myapp DEBUG=true
```

### Restart App

```bash
dokku-cli restart myapp
```

### Rollback

```bash
# Via CLI
dokku-cli rollback myapp

# Via GitHub Actions
# Go to Actions → Rollback → Run workflow
```

### Run One-Off Command

```bash
# Database migration
dokku-cli run myapp python manage.py migrate

# Open shell
dokku-cli shell myapp
```

## Installing the CLI (Optional)

For easier local management:

```bash
# Download CLI
curl -o dokku-cli https://raw.githubusercontent.com/signalwire-demos/dokku-deploy-system/main/cli/dokku-cli
chmod +x dokku-cli
sudo mv dokku-cli /usr/local/bin/

# Configure
dokku-cli setup
```

## Project Structure

```
my-app/
├── .github/workflows/
│   ├── deploy.yml       # Main deployment workflow
│   └── preview.yml      # PR preview workflow
├── .dokku/
│   ├── services.yml     # Database/cache configuration
│   └── config.yml       # Resource limits, health checks
├── Procfile             # Process definitions
├── runtime.txt          # Runtime version
├── CHECKS               # Health check configuration
├── app.json             # App metadata
├── .env.example         # Environment template
├── requirements.txt     # Python dependencies
└── app.py               # Your application
```

## Getting Help

- **Slack**: #deployments
- **Wiki**: /wiki/dokku
- **Issues**: Create a ticket in the platform repo

## FAQ

### Q: My deployment failed. What do I do?

1. Check the GitHub Actions logs
2. Look for error messages in the deploy step
3. Check app logs: `dokku-cli logs myapp`

### Q: How do I add a custom domain?

1. Go to Actions → "Add Custom Domain" workflow
2. Run the workflow with your domain
3. Configure DNS as instructed

### Q: How do I access the database?

```bash
# Connect to PostgreSQL
dokku-cli db myapp connect postgres

# Get connection URL
dokku-cli config myapp | grep DATABASE_URL
```

### Q: How do I scale my app?

```bash
# Scale to 2 web processes
dokku-cli scale myapp web=2
```

### Q: Preview URL shows 502 error

Wait 1-2 minutes for the app to fully start. If still failing:
1. Check workflow logs
2. Check app logs: `ssh dokku@server logs myapp-pr-XX`

---

Happy deploying! 🚀
