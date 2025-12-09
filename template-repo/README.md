# My App

Deployed automatically to Dokku via GitHub Actions.

## Features

- ✅ Auto-deploy on push to `main`, `staging`, `develop`
- ✅ Preview environments for pull requests
- ✅ Automatic SSL via Let's Encrypt
- ✅ Zero-downtime deployments
- ✅ Automatic service provisioning

## Quick Start

### 1. Configure GitHub Secrets

Add these secrets to your repository (Settings → Secrets → Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `DOKKU_HOST` | Dokku server hostname | `dokku.example.com` |
| `DOKKU_SSH_PRIVATE_KEY` | SSH private key | `-----BEGIN OPENSSH...` |
| `BASE_DOMAIN` | Base domain for apps | `example.com` |

### 2. Create GitHub Environments

Create these environments (Settings → Environments):

- `production` - Deploys from `main`
- `staging` - Deploys from `staging`
- `development` - Deploys from `develop`
- `preview` - Deploys from pull requests

### 3. Push to Deploy

```bash
git push origin main      # → app.example.com
git push origin staging   # → app-staging.example.com
git push origin develop   # → app-dev.example.com
```

Or open a PR for an automatic preview environment.

## Branch → URL Mapping

| Branch | App Name | URL |
|--------|----------|-----|
| `main` | `{repo}` | `{repo}.example.com` |
| `staging` | `{repo}-staging` | `{repo}-staging.example.com` |
| `develop` | `{repo}-dev` | `{repo}-dev.example.com` |
| PR #42 | `{repo}-pr-42` | `{repo}-pr-42.example.com` |

## Enable Services

Edit `.dokku/services.yml` to enable databases, caching, etc:

```yaml
services:
  postgres:
    enabled: true
  redis:
    enabled: true
```

Services are automatically provisioned and linked on deploy.

## Local Development

```bash
# Copy environment template
cp .env.example .env

# Install dependencies
pip install -r requirements.txt  # Python
npm install                      # Node.js

# Run locally
uvicorn app:app --reload --port 8000  # Python
npm run dev                            # Node.js
```

## Manual Dokku Commands

```bash
# SSH shorthand
alias dokku="ssh dokku@your-server"

# View logs
dokku logs myapp -t

# View environment
dokku config:show myapp

# Restart app
dokku ps:restart myapp

# Rollback to previous release
dokku releases:rollback myapp

# Run one-off command
dokku run myapp python manage.py shell

# Open database shell
dokku postgres:connect postgres-myapp
```

## Project Structure

```
├── .github/workflows/
│   ├── deploy.yml       # Auto-deploy workflow
│   └── preview.yml      # PR preview workflow
├── .dokku/
│   ├── services.yml     # Service definitions
│   └── config.yml       # App configuration
├── Procfile             # Process definitions
├── runtime.txt          # Runtime version
├── CHECKS               # Health check config
├── app.json             # App manifest
├── .env.example         # Environment template
└── README.md
```

## Health Checks

The app must respond to `/health` with HTTP 200 for zero-downtime deploys.

```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

## Troubleshooting

### Deployment fails

1. Check workflow logs in GitHub Actions
2. View Dokku logs: `dokku logs myapp --num 100`
3. Verify secrets are configured correctly

### SSL certificate fails

1. Ensure DNS is pointing to the server
2. Wait for DNS propagation (up to 48 hours)
3. Manually enable: `dokku letsencrypt:enable myapp`

### App crashes on startup

1. Check Procfile syntax
2. Verify PORT environment variable is used
3. Check for missing dependencies

## Links

- [Dokku Documentation](https://dokku.com/docs/)
- [GitHub Actions](https://docs.github.com/en/actions)
