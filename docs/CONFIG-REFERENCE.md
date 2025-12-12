# Configuration Reference

Complete reference for all `.dokku/` configuration files used by the Dokku Deploy System.

---

## Table of Contents

- [Overview](#overview)
- [.dokku/config.yml](#dokkuconfigyml)
  - [Resources](#resources)
  - [Health Check](#health-check)
  - [Scaling](#scaling)
  - [Custom Domains](#custom-domains)
  - [Release Tasks](#release-tasks)
  - [Backup Configuration](#backup-configuration)
  - [Security Scanning](#security-scanning)
  - [Environment Overrides](#environment-overrides)
  - [Auto-Scaling (Advanced)](#auto-scaling-advanced)
  - [Multi-Region Servers (Advanced)](#multi-region-servers-advanced)
  - [Canary Deployments (Advanced)](#canary-deployments-advanced)
- [.dokku/services.yml](#dokkuservicesyml)
  - [Supported Services](#supported-services)
  - [Service Configuration](#service-configuration)
  - [External/Managed Services](#externalmanaged-services)
- [Other Configuration Files](#other-configuration-files)
  - [Procfile](#procfile)
  - [CHECKS](#checks)
  - [.trivyignore](#trivyignore)
- [Complete Examples](#complete-examples)

---

## Overview

Configuration files in the `.dokku/` directory control how your application is deployed:

| File | Purpose |
|------|---------|
| `.dokku/config.yml` | App configuration (resources, scaling, domains, etc.) |
| `.dokku/services.yml` | Backing services (databases, caches, queues) |

These files are read during deployment and their settings are applied to your Dokku app.

---

## .dokku/config.yml

Main application configuration file.

### Resources

Control memory and CPU allocation:

```yaml
resources:
  memory: 512m    # 256m, 512m, 1g, 2g, 4g, etc.
  cpu: 1          # Number of cores (can be fractional: 0.5, 1, 2)
```

**Memory formats:**
- `256m` - 256 megabytes
- `1g` - 1 gigabyte
- `2g` - 2 gigabytes

**CPU formats:**
- `0.5` - Half a CPU core
- `1` - One CPU core
- `2` - Two CPU cores

### Health Check

Configure the endpoint used to verify app health after deployment:

```yaml
healthcheck:
  path: /health       # URL path to check (default: /health)
  timeout: 30         # Seconds to wait for response (default: 30)
  attempts: 5         # Number of retry attempts (default: 5)
  wait: 5             # Seconds to wait before first check (default: 5)
```

The deployment succeeds only if the health check returns HTTP 200.

### Scaling

Set the number of process instances:

```yaml
scale:
  web: 2              # Number of web process instances
  worker: 1           # Number of worker process instances
```

Process names must match your `Procfile` entries.

### Custom Domains

Add custom domains (requires DNS configuration):

```yaml
custom_domains:
  - www.example.com
  - api.example.com
  - app.example.com
```

DNS must point to your Dokku server before deployment. SSL is automatically provisioned via Let's Encrypt.

### Release Tasks

Commands to run after deployment, before health check:

```yaml
release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"
      timeout: 120          # Seconds (default: 120)

    - name: "Clear cache"
      command: "python manage.py clear_cache"
      timeout: 30

    - name: "Collect static files"
      command: "python manage.py collectstatic --no-input"
      timeout: 60
```

**Behavior:**
- Tasks run sequentially in order listed
- If any task fails, deployment fails
- Task output visible in workflow logs

### Backup Configuration

Configure automatic database backups:

```yaml
backup:
  enabled: true
  retention_days: 14        # Days to keep backups
  services:
    - postgres
    - mysql
```

Backups run daily at 2 AM UTC via the scheduled workflow.

### Security Scanning

Configure Trivy vulnerability scanning:

```yaml
security:
  block_on_critical: true   # Block deploy on critical vulnerabilities (default: true)
  severity: "CRITICAL,HIGH" # Severities to scan for
```

### Environment Overrides

Override any setting per environment:

```yaml
# Default settings
resources:
  memory: 512m
  cpu: 1

scale:
  web: 1

# Environment-specific overrides
environments:
  production:
    resources:
      memory: 2g
      cpu: 4
    scale:
      web: 4
      worker: 2
    custom_domains:
      - www.example.com
      - example.com

  staging:
    resources:
      memory: 1g
      cpu: 2
    scale:
      web: 2

  development:
    resources:
      memory: 512m
      cpu: 1

  preview:
    resources:
      memory: 256m
      cpu: 0.5
    scale:
      web: 1
    # Override release tasks for previews
    release:
      tasks:
        - name: "Seed demo data"
          command: "python manage.py seed_demo"
```

### Auto-Scaling (Advanced)

Configure automatic scaling based on metrics or schedules (requires `autoscaler.yml` workflow):

```yaml
scaling:
  production:
    min_instances: 2
    max_instances: 10

    # Metric-based scaling
    metrics:
      cpu:
        scale_up_threshold: 80      # Scale up when CPU > 80%
        scale_down_threshold: 50    # Scale down when CPU < 50%
      memory:
        scale_up_threshold: 85      # Scale up when memory > 85%

    # Schedule-based scaling
    schedule:
      - cron: "0 9 * * 1-5"         # 9 AM weekdays (UTC)
        instances: 5                 # Scale up for business hours
      - cron: "0 18 * * 1-5"        # 6 PM weekdays (UTC)
        instances: 2                 # Scale down after hours
      - cron: "0 0 * * 0"           # Midnight Sunday (UTC)
        instances: 1                 # Minimal weekend capacity

    # Cooldown periods to prevent rapid scaling
    cooldown:
      scale_up: 3m                  # Wait 3 min after scale up
      scale_down: 10m               # Wait 10 min after scale down
```

### Multi-Region Servers (Advanced)

Deploy to multiple Dokku servers (requires `multi-region-deploy.yml` workflow):

```yaml
servers:
  us-east:
    host: dokku-us-east.example.com
    primary: true                   # Primary server for single-region deploys
    domain: us-east.example.com

  us-west:
    host: dokku-us-west.example.com
    domain: us-west.example.com

  eu-west:
    host: dokku-eu.example.com
    domain: eu.example.com

deployment:
  strategy: all           # all, primary-only, rolling
  failover: true          # Continue if one region fails
  parallel: true          # Deploy to all regions simultaneously
```

**Strategies:**
- `all` - Deploy to all servers at once
- `primary-only` - Deploy only to primary server
- `rolling` - Deploy one server at a time

**Secrets pattern:** `DOKKU_HOST_US_EAST`, `DOKKU_SSH_KEY_US_WEST`, etc.

### Canary Deployments (Advanced)

Configure canary deployment defaults (requires `canary-deploy.yml` workflow):

```yaml
canary:
  enabled: true
  environments:
    production:
      initial_percent: 10           # Start with 10% traffic to canary
      monitoring_duration: 15       # Minutes to monitor
      error_threshold: 5            # Rollback if error rate > 5%
      metrics:
        - error_rate
        - response_time_p99
      rollback_on:
        error_rate: "> 5%"
        response_time_p99: "> 2000ms"
```

---

## .dokku/services.yml

Define backing services for your application.

### Supported Services

| Service | Environment Variable | URL Format |
|---------|---------------------|------------|
| `postgres` | `DATABASE_URL` | `postgres://user:pass@host:5432/db` |
| `mysql` | `DATABASE_URL` | `mysql://user:pass@host:3306/db` |
| `redis` | `REDIS_URL` | `redis://host:6379` |
| `mongo` | `MONGO_URL` | `mongodb://user:pass@host:27017/db` |
| `rabbitmq` | `RABBITMQ_URL` | `amqp://user:pass@host:5672` |
| `elasticsearch` | `ELASTICSEARCH_URL` | `http://host:9200` |

### Service Configuration

```yaml
services:
  postgres:
    enabled: true                 # Enable this service
    environments:
      production:
        dedicated: true           # Own database instance
      staging:
        dedicated: true
      preview:
        shared: true              # Share database across all previews

  redis:
    enabled: true
    environments:
      production:
        dedicated: true
      staging:
        dedicated: true
      preview:
        shared: true

  mysql:
    enabled: false                # Disabled globally

  rabbitmq:
    enabled: true
    environments:
      preview:
        enabled: false            # Disable for previews (resource intensive)

  elasticsearch:
    enabled: false
    environments:
      preview:
        enabled: false
```

**Options:**
- `enabled: true/false` - Enable or disable the service
- `dedicated: true` - Create a dedicated instance for this environment
- `shared: true` - Share instance across multiple apps (useful for previews)

### External/Managed Services

Use external services (AWS RDS, ElastiCache, etc.) instead of Dokku-managed:

```yaml
external_services:
  production:
    DATABASE_URL: "${secrets.PROD_DATABASE_URL}"
    REDIS_URL: "${secrets.PROD_REDIS_URL}"

  staging:
    DATABASE_URL: "${secrets.STAGING_DATABASE_URL}"
```

**Note:** External service URLs should be stored as GitHub secrets and referenced using `${secrets.SECRET_NAME}` syntax.

---

## Other Configuration Files

### Procfile

Define your application processes:

```procfile
# Python (FastAPI/Gunicorn)
web: gunicorn app:app --workers 4 --bind 0.0.0.0:$PORT

# Python (Uvicorn)
web: uvicorn app:app --host 0.0.0.0 --port $PORT

# Node.js
web: node server.js

# Ruby (Rails)
web: bundle exec puma -C config/puma.rb

# Go
web: ./bin/server

# Background worker
worker: python manage.py runworker
```

**Important:** Process names must match `scale` entries in `config.yml`.

### CHECKS

Health check configuration for zero-downtime deployments:

```
# Format: WAIT_TIME URL EXPECTED_CONTENT
# Simple health check
/health

# With expected content
/health ready

# With wait time and content
WAIT=10 /health {"status":"ok"}

# Multiple checks
/health
/api/status
```

**Format:**
- `WAIT=N` - Seconds to wait before first check
- `TIMEOUT=N` - Seconds to wait for response
- `ATTEMPTS=N` - Number of retry attempts

### .trivyignore

Ignore specific CVEs in security scanning:

```
# Ignore false positives
CVE-2023-12345
CVE-2023-67890

# With comments
# This CVE doesn't affect our usage
CVE-2024-11111
```

---

## Complete Examples

### Minimal Configuration

```yaml
# .dokku/config.yml
resources:
  memory: 512m
  cpu: 1

healthcheck:
  path: /health
```

```yaml
# .dokku/services.yml
services:
  postgres:
    enabled: true
```

### Production-Ready Configuration

```yaml
# .dokku/config.yml
resources:
  memory: 512m
  cpu: 1

healthcheck:
  path: /health
  timeout: 30
  attempts: 5

scale:
  web: 1

release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"
      timeout: 120

security:
  block_on_critical: true

environments:
  production:
    resources:
      memory: 2g
      cpu: 4
    scale:
      web: 4
      worker: 2
    custom_domains:
      - www.example.com
      - example.com

  staging:
    resources:
      memory: 1g
      cpu: 2
    scale:
      web: 2

  preview:
    resources:
      memory: 256m
      cpu: 0.5
    release:
      tasks:
        - name: "Seed demo data"
          command: "python manage.py seed_demo"
```

```yaml
# .dokku/services.yml
services:
  postgres:
    enabled: true
    environments:
      production:
        dedicated: true
      staging:
        dedicated: true
      preview:
        shared: true

  redis:
    enabled: true
    environments:
      production:
        dedicated: true
      staging:
        dedicated: true
      preview:
        shared: true

external_services:
  production:
    DATABASE_URL: "${secrets.PROD_DATABASE_URL}"
    REDIS_URL: "${secrets.PROD_REDIS_URL}"
```

### Full-Featured Configuration (All Options)

```yaml
# .dokku/config.yml
resources:
  memory: 512m
  cpu: 1

healthcheck:
  path: /health
  timeout: 30
  attempts: 5
  wait: 5

scale:
  web: 1
  worker: 1

custom_domains:
  - api.example.com

release:
  tasks:
    - name: "Database migrations"
      command: "python manage.py migrate --no-input"
      timeout: 120
    - name: "Clear cache"
      command: "python manage.py clear_cache"
      timeout: 30

backup:
  enabled: true
  retention_days: 14
  services:
    - postgres

security:
  block_on_critical: true
  severity: "CRITICAL,HIGH"

# Auto-scaling configuration
scaling:
  production:
    min_instances: 2
    max_instances: 10
    metrics:
      cpu:
        scale_up_threshold: 80
        scale_down_threshold: 50
    schedule:
      - cron: "0 9 * * 1-5"
        instances: 5
      - cron: "0 18 * * 1-5"
        instances: 2
    cooldown:
      scale_up: 3m
      scale_down: 10m

# Multi-region configuration
servers:
  us-east:
    host: dokku-us-east.example.com
    primary: true
    domain: us-east.example.com
  us-west:
    host: dokku-us-west.example.com
    domain: us-west.example.com

deployment:
  strategy: all
  failover: true
  parallel: true

# Canary configuration
canary:
  enabled: true
  environments:
    production:
      initial_percent: 10
      monitoring_duration: 15
      error_threshold: 5

# Environment-specific overrides
environments:
  production:
    resources:
      memory: 2g
      cpu: 4
    scale:
      web: 4
      worker: 2

  staging:
    resources:
      memory: 1g
      cpu: 2

  preview:
    resources:
      memory: 256m
      cpu: 0.5
    release:
      tasks:
        - name: "Seed demo data"
          command: "python manage.py seed_demo"
```
