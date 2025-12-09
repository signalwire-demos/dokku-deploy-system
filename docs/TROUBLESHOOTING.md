# Troubleshooting Guide

Quick solutions for common issues with the Dokku deployment system.

## Table of Contents

- [Deployment Failures](#deployment-failures)
- [App Not Responding](#app-not-responding)
- [SSL/Certificate Issues](#sslcertificate-issues)
- [Database Issues](#database-issues)
- [Preview Environment Issues](#preview-environment-issues)
- [Performance Issues](#performance-issues)
- [SSH/Connection Issues](#sshconnection-issues)

---

## Deployment Failures

### Symptom: "Permission denied (publickey)"

**Cause**: SSH key not configured correctly.

**Solution**:
```bash
# 1. Verify the key is in GitHub Secrets
# Go to: Repo → Settings → Secrets → DOKKU_SSH_PRIVATE_KEY

# 2. Verify the public key is on Dokku server
ssh dokku@server ssh-keys:list

# 3. Test SSH connection manually
ssh -i ~/.ssh/deploy_key dokku@server version
```

### Symptom: "App not found" or "does not exist"

**Cause**: App hasn't been created yet.

**Solution**:
```bash
# The workflow should auto-create, but you can manually create:
ssh dokku@server apps:create myapp
```

### Symptom: Build fails with "out of memory"

**Cause**: Server running out of memory during build.

**Solution**:
```bash
# Option 1: Add swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Option 2: Increase container memory for build
ssh dokku@server resource:limit myapp --memory 2048m
```

### Symptom: "Procfile declares no process types"

**Cause**: Missing or malformed Procfile.

**Solution**:
1. Ensure `Procfile` exists in repo root
2. Check format: `web: <command>`
3. No extra spaces or tabs before `web:`

```
# Correct
web: uvicorn app:app --host 0.0.0.0 --port $PORT

# Wrong (has leading space)
 web: uvicorn app:app --host 0.0.0.0 --port $PORT
```

### Symptom: "No matching manifest for linux/amd64"

**Cause**: Docker image architecture mismatch.

**Solution**:
```bash
# For Python apps, ensure requirements.txt doesn't have
# platform-specific packages. Use:
pip freeze | grep -v "@ file" > requirements.txt
```

---

## App Not Responding

### Symptom: 502 Bad Gateway

**Cause**: App crashed or not listening on correct port.

**Solution**:
```bash
# 1. Check if app is running
ssh dokku@server ps:report myapp

# 2. View recent logs
ssh dokku@server logs myapp --num 100

# 3. Check if binding to $PORT
# Your app MUST use the PORT environment variable
# Example: --port $PORT (NOT --port 8000)

# 4. Restart app
ssh dokku@server ps:restart myapp
```

### Symptom: 503 Service Unavailable

**Cause**: App starting up or health check failing.

**Solution**:
```bash
# 1. Wait 30 seconds for startup

# 2. Check health endpoint manually
curl -I https://myapp.domain.com/health

# 3. Review CHECKS file format
cat CHECKS
# Should be:
# /health

# 4. Check app logs for startup errors
ssh dokku@server logs myapp -t
```

### Symptom: App responds but returns errors

**Cause**: Missing environment variables or misconfiguration.

**Solution**:
```bash
# 1. Check environment variables are set
ssh dokku@server config:show myapp

# 2. Verify DATABASE_URL if using database
ssh dokku@server config:get myapp DATABASE_URL

# 3. Check for missing secrets
# Compare with .env.example
```

---

## SSL/Certificate Issues

### Symptom: Let's Encrypt fails with "unauthorized"

**Cause**: DNS not pointing to server, or domain misconfigured.

**Solution**:
```bash
# 1. Verify DNS points to server
dig +short myapp.domain.com
# Should return your server IP

# 2. Check if HTTP is accessible (required for ACME challenge)
curl -I http://myapp.domain.com/.well-known/acme-challenge/test

# 3. If using Cloudflare, disable proxy (orange cloud) temporarily
# Or use DNS-only mode for the wildcard

# 4. Retry certificate
ssh dokku@server letsencrypt:enable myapp
```

### Symptom: Certificate expired

**Cause**: Auto-renewal cron job not running.

**Solution**:
```bash
# 1. Check cron job exists
ssh dokku@server letsencrypt:cron-job --list

# 2. Add if missing
ssh dokku@server letsencrypt:cron-job --add

# 3. Manual renewal
ssh dokku@server letsencrypt:auto-renew
```

### Symptom: "too many certificates" rate limit

**Cause**: Hit Let's Encrypt rate limits.

**Solution**:
```bash
# 1. Wait 1 week (rate limit resets)

# 2. For testing, use staging server
ssh dokku@server letsencrypt:set --global server staging

# 3. Switch back to production when ready
ssh dokku@server letsencrypt:set --global server default
```

---

## Database Issues

### Symptom: "connection refused" to database

**Cause**: Database service not linked to app.

**Solution**:
```bash
# 1. Check if database exists
ssh dokku@server postgres:list

# 2. Check if linked
ssh dokku@server postgres:links postgres-myapp

# 3. Link if not linked
ssh dokku@server postgres:link postgres-myapp myapp

# 4. Verify DATABASE_URL is set
ssh dokku@server config:get myapp DATABASE_URL
```

### Symptom: Database migrations fail

**Cause**: Migration running before database is ready.

**Solution**:
```bash
# 1. Run migrations manually
ssh dokku@server run myapp python manage.py migrate

# 2. Or add to Procfile release phase
# release: python manage.py migrate
```

### Symptom: "too many connections"

**Cause**: Connection pool exhausted.

**Solution**:
```bash
# 1. Check current connections
ssh dokku@server postgres:connect postgres-myapp
# Then run: SELECT count(*) FROM pg_stat_activity;

# 2. Configure connection pooling in your app
# Set pool_size, max_overflow in SQLAlchemy
# Or use PgBouncer

# 3. Restart app to reset connections
ssh dokku@server ps:restart myapp
```

---

## Preview Environment Issues

### Symptom: Preview not created

**Cause**: Workflow not triggered or failed silently.

**Solution**:
1. Check Actions tab for the PR
2. Verify `preview.yml` exists in `.github/workflows/`
3. Ensure PR is against correct base branch

### Symptom: Preview shows old content

**Cause**: Caching or incomplete deploy.

**Solution**:
```bash
# Force redeploy by pushing empty commit
git commit --allow-empty -m "Trigger deploy"
git push
```

### Symptom: Preview not destroyed after PR merge

**Cause**: Cleanup job failed.

**Solution**:
```bash
# Manually destroy
ssh dokku@server apps:destroy myapp-pr-42 --force
```

---

## Performance Issues

### Symptom: App is slow

**Diagnosis**:
```bash
# 1. Check resource usage
ssh dokku@server ps:report myapp

# 2. Check for memory pressure
ssh dokku@server resource:report myapp

# 3. Check database performance
ssh dokku@server postgres:logs postgres-myapp
```

**Solutions**:
```bash
# Increase memory
ssh dokku@server resource:limit myapp --memory 1024m

# Scale horizontally
ssh dokku@server ps:scale myapp web=2

# Enable response caching (app-level)
```

### Symptom: High memory usage

**Solution**:
```bash
# 1. Check current usage
docker stats

# 2. Set memory limit
ssh dokku@server resource:limit myapp --memory 512m

# 3. Review app for memory leaks
# Check for unclosed connections, large caches, etc.
```

---

## SSH/Connection Issues

### Symptom: "Connection timed out"

**Cause**: Firewall blocking SSH or wrong hostname.

**Solution**:
```bash
# 1. Verify hostname resolves
dig +short dokku.domain.com

# 2. Check if port 22 is open
nc -zv dokku.domain.com 22

# 3. Verify firewall allows your IP
# On server: sudo ufw status
```

### Symptom: "Host key verification failed"

**Cause**: Server key changed or not in known_hosts.

**Solution**:
```bash
# 1. Remove old key
ssh-keygen -R dokku.domain.com

# 2. Re-add host
ssh-keyscan -H dokku.domain.com >> ~/.ssh/known_hosts
```

---

## Quick Diagnostic Commands

```bash
# App status
ssh dokku@server ps:report myapp
ssh dokku@server logs myapp --num 100

# Database status
ssh dokku@server postgres:info postgres-myapp

# SSL status
ssh dokku@server letsencrypt:list

# Domain configuration
ssh dokku@server domains:report myapp

# Environment variables
ssh dokku@server config:show myapp

# Recent releases
ssh dokku@server releases:list myapp

# Resource usage
ssh dokku@server resource:report myapp

# NGINX config
ssh dokku@server nginx:show-config myapp
```

---

## Getting Help

If you're still stuck:

1. **Collect diagnostic info**:
   ```bash
   ssh dokku@server report myapp > diagnostic.txt
   ssh dokku@server logs myapp --num 200 >> diagnostic.txt
   ```

2. **Check the wiki**: /wiki/dokku

3. **Ask in Slack**: #deployments

4. **Create an issue** with:
   - App name
   - Error message
   - Steps to reproduce
   - Diagnostic output
