# BASE_DOMAIN Configuration Options

## Current Issue

`BASE_DOMAIN` is stored as an org-level secret, which causes:
- URLs containing the domain get masked in workflow logs
- Warning: "Skip output 'app_url' since it may contain secret"
- Harder to debug deployment issues

The warning is harmless - values are still passed correctly - but it's noisy.

## Options

### Option A: Keep as Org Secret (Current)
**Status:** Current implementation

- Works but URLs get masked in logs
- Warning is harmless but annoying
- No changes needed

### Option B: Hardcode in Workflow
**Recommended for single-domain setups**

Add directly to `deploy.yml`:
```yaml
env:
  BASE_DOMAIN: "dokku.signalwire.io"
```

Pros:
- Simplest solution
- No masking, full visibility in logs
- No setup required for new repos

Cons:
- Less flexible if domain changes
- Requires workflow update to change domain

### Option C: Workflow Input with Default
**Recommended for flexibility**

```yaml
on:
  workflow_call:
    inputs:
      base_domain:
        description: 'Base domain for apps'
        required: false
        type: string
        default: 'dokku.signalwire.io'
```

Then use `${{ inputs.base_domain || 'dokku.signalwire.io' }}` in the workflow.

Pros:
- Default handles 99% of cases
- Individual repos can override if needed
- Visible in logs (not masked)

Cons:
- Slightly more complex
- Repos wanting custom domain must pass it explicitly

### Option D: Repository Variable
**Most flexible but most setup**

Each repo sets `BASE_DOMAIN` as a repository variable (Settings → Variables → New repository variable).

Pros:
- Fully visible in logs
- Per-repo customization
- Clear separation of config

Cons:
- Requires setup in every repo
- Can't set org-wide default for variables

## Recommendation

**For signalwire-demos:** Option B (hardcode) or Option C (input with default)

Since all apps use the same domain (`dokku.signalwire.io`), hardcoding is simplest. If there's ever a need for different domains per-repo, migrate to Option C.

## Migration Steps

### To implement Option B:

1. Edit `.github/workflows/deploy.yml`
2. Change:
   ```yaml
   env:
     BASE_DOMAIN: "dokku.signalwire.io"
   ```
3. Remove `BASE_DOMAIN` from secrets (optional, can keep as backup)
4. Update all references from `${{ secrets.BASE_DOMAIN }}` to `${{ env.BASE_DOMAIN }}`

### To implement Option C:

1. Edit `.github/workflows/deploy.yml`
2. Add to inputs:
   ```yaml
   inputs:
     base_domain:
       description: 'Base domain for apps'
       required: false
       type: string
       default: 'dokku.signalwire.io'
   ```
3. Add to env:
   ```yaml
   env:
     BASE_DOMAIN: ${{ inputs.base_domain }}
   ```
4. Update all references from `${{ secrets.BASE_DOMAIN }}` to `${{ env.BASE_DOMAIN }}`

## Decision

- [ ] Option A - Keep current (do nothing)
- [ ] Option B - Hardcode in workflow
- [ ] Option C - Input with default
- [ ] Option D - Repository variables
