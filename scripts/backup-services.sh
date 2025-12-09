#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# backup-services.sh
# Automated backup script for all Dokku services
# ═══════════════════════════════════════════════════════════════════════════════
#
# Run via cron:
#   0 2 * * * /opt/scripts/backup-services.sh
#
# Or manually:
#   ./backup-services.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/dokku}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
DATE=$(date +%Y%m%d_%H%M%S)

# Optional: S3 backup
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-dokku-backups}"

# Colors (for interactive use)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    BLUE=''
    RED=''
    NC=''
fi

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"/{postgres,mysql,redis,mongo}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Dokku Services Backup - $(date)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

TOTAL_BACKUPS=0
FAILED_BACKUPS=0

# ─────────────────────────────────────────────────────────────────────────────
# Backup PostgreSQL
# ─────────────────────────────────────────────────────────────────────────────

log_info "Backing up PostgreSQL databases..."

for DB in $(dokku postgres:list 2>/dev/null | tail -n +2); do
    BACKUP_FILE="$BACKUP_DIR/postgres/${DB}_${DATE}.sql.gz"

    if dokku postgres:export "$DB" 2>/dev/null | gzip > "$BACKUP_FILE"; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "  $DB → $BACKUP_FILE ($SIZE)"
        ((TOTAL_BACKUPS++))
    else
        log_error "  $DB - backup failed"
        rm -f "$BACKUP_FILE"
        ((FAILED_BACKUPS++))
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Backup MySQL
# ─────────────────────────────────────────────────────────────────────────────

log_info "Backing up MySQL databases..."

for DB in $(dokku mysql:list 2>/dev/null | tail -n +2); do
    BACKUP_FILE="$BACKUP_DIR/mysql/${DB}_${DATE}.sql.gz"

    if dokku mysql:export "$DB" 2>/dev/null | gzip > "$BACKUP_FILE"; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "  $DB → $BACKUP_FILE ($SIZE)"
        ((TOTAL_BACKUPS++))
    else
        log_error "  $DB - backup failed"
        rm -f "$BACKUP_FILE"
        ((FAILED_BACKUPS++))
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Backup Redis
# ─────────────────────────────────────────────────────────────────────────────

log_info "Backing up Redis instances..."

for REDIS in $(dokku redis:list 2>/dev/null | tail -n +2); do
    BACKUP_FILE="$BACKUP_DIR/redis/${REDIS}_${DATE}.rdb.gz"

    if dokku redis:export "$REDIS" 2>/dev/null | gzip > "$BACKUP_FILE"; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "  $REDIS → $BACKUP_FILE ($SIZE)"
        ((TOTAL_BACKUPS++))
    else
        log_warning "  $REDIS - backup skipped (possibly no persistence)"
        rm -f "$BACKUP_FILE"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Backup MongoDB
# ─────────────────────────────────────────────────────────────────────────────

log_info "Backing up MongoDB databases..."

for MONGO in $(dokku mongo:list 2>/dev/null | tail -n +2); do
    BACKUP_FILE="$BACKUP_DIR/mongo/${MONGO}_${DATE}.archive.gz"

    if dokku mongo:export "$MONGO" 2>/dev/null | gzip > "$BACKUP_FILE"; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "  $MONGO → $BACKUP_FILE ($SIZE)"
        ((TOTAL_BACKUPS++))
    else
        log_error "  $MONGO - backup failed"
        rm -f "$BACKUP_FILE"
        ((FAILED_BACKUPS++))
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Upload to S3 (optional)
# ─────────────────────────────────────────────────────────────────────────────

if [ -n "$S3_BUCKET" ]; then
    log_info "Uploading to S3..."

    if command -v aws &>/dev/null; then
        aws s3 sync "$BACKUP_DIR" "s3://$S3_BUCKET/$S3_PREFIX/" \
            --exclude "*" \
            --include "*_${DATE}*" \
            --storage-class STANDARD_IA

        log_success "Uploaded to s3://$S3_BUCKET/$S3_PREFIX/"
    else
        log_warning "AWS CLI not installed, skipping S3 upload"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup old backups
# ─────────────────────────────────────────────────────────────────────────────

log_info "Cleaning up backups older than $RETENTION_DAYS days..."

DELETED=$(find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log_success "Deleted $DELETED old backup files"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Backup Summary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Total backups:  $TOTAL_BACKUPS"
echo "  Failed:         $FAILED_BACKUPS"
echo "  Backup dir:     $BACKUP_DIR"
echo "  Retention:      $RETENTION_DAYS days"
echo ""

# Show disk usage
echo "  Disk usage:"
du -sh "$BACKUP_DIR"/* 2>/dev/null | sed 's/^/    /'
echo ""

# Exit with error if any backups failed
if [ "$FAILED_BACKUPS" -gt 0 ]; then
    log_error "Some backups failed!"
    exit 1
fi

log_success "Backup complete!"
