#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - S3 Backup Cleanup Script
# Son 1 günlük tüm yedekleri tutar, eğer son gün yedek yoksa en az 10 tane tutar
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
S3_BUCKET="${S3_BUCKET:-finans-asistan-backups}"
S3_PREFIX="${S3_PREFIX:-postgres/backups}"
MIN_KEEP_COUNT="${MIN_KEEP_COUNT:-10}"  # En az tutulacak yedek sayısı
KEEP_DAYS="${KEEP_DAYS:-1}"  # Son kaç günlük yedekler tutulacak
AWS_REGION="${AWS_REGION:-eu-central-1}"
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"  # Non-interactive mode (skip confirmation)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log_error "AWS credentials not configured or invalid"
    exit 1
fi

log_info "Starting backup cleanup..."
log_info "S3 Bucket: ${S3_BUCKET}"
log_info "Prefix: ${S3_PREFIX}"
log_info "Keeping all backups from last ${KEEP_DAYS} day(s)"
log_info "Minimum backups to keep: ${MIN_KEEP_COUNT}"

# Calculate cutoff time (KEEP_DAYS ago)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CUTOFF_TIME=$(date -u -v-${KEEP_DAYS}d +%s)
    CUTOFF_DISPLAY=$(date -u -r "${CUTOFF_TIME}" +"%Y-%m-%d %H:%M:%S UTC")
else
    # Linux
    CUTOFF_TIME=$(date -u -d "${KEEP_DAYS} days ago" +%s)
    CUTOFF_DISPLAY=$(date -u -d "@${CUTOFF_TIME}" +"%Y-%m-%d %H:%M:%S UTC")
fi

log_info "Cutoff time: ${CUTOFF_DISPLAY}"

# List all backup files, sorted by last modified date (newest first)
log_info "Listing backup files..."
BACKUP_FILES=$(aws s3api list-objects-v2 \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}/" \
    --query "sort_by(Contents[?contains(Key, '.sql.gz') || contains(Key, '.sql') && !contains(Key, '.checksum')], &LastModified)[*].[Key,LastModified]" \
    --output text \
    --region "${AWS_REGION}" | sort -k2 -r)

if [ -z "$BACKUP_FILES" ]; then
    log_warn "No backup files found in s3://${S3_BUCKET}/${S3_PREFIX}/"
    exit 0
fi

# Count total backups
TOTAL_COUNT=$(echo "$BACKUP_FILES" | wc -l)
log_info "Total backups found: ${TOTAL_COUNT}"

# Find backups from last KEEP_DAYS days
RECENT_BACKUPS=""
RECENT_COUNT=0

while IFS=$'\t' read -r key last_modified; do
    # Parse AWS S3 LastModified format (ISO 8601: 2025-01-19T12:34:56.000Z)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - remove .000Z and convert
        modified_clean="${last_modified%.*}"
        file_time=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$modified_clean" +%s 2>/dev/null || echo "0")
    else
        # Linux
        file_time=$(date -u -d "$last_modified" +%s 2>/dev/null || echo "0")
    fi
    
    if [ "$file_time" != "0" ] && [ "$file_time" -ge "$CUTOFF_TIME" ]; then
        RECENT_BACKUPS="${RECENT_BACKUPS}${key}${IFS}"
        RECENT_COUNT=$((RECENT_COUNT + 1))
    fi
done <<< "$BACKUP_FILES"

log_info "Backups from last ${KEEP_DAYS} day(s): ${RECENT_COUNT}"

# Determine files to keep
if [ "$RECENT_COUNT" -gt 0 ]; then
    # Keep all recent backups (last KEEP_DAYS days)
    FILES_TO_KEEP="$RECENT_BACKUPS"
    KEEP_COUNT=$RECENT_COUNT
    log_info "Keeping all ${RECENT_COUNT} backups from last ${KEEP_DAYS} day(s)"
else
    # No recent backups, keep at least MIN_KEEP_COUNT
    KEEP_COUNT=$MIN_KEEP_COUNT
    if [ "$TOTAL_COUNT" -le "$MIN_KEEP_COUNT" ]; then
        log_info "No recent backups found, but only ${TOTAL_COUNT} backups exist (keeping all)"
        exit 0
    fi
    FILES_TO_KEEP=$(echo "$BACKUP_FILES" | head -n "$MIN_KEEP_COUNT" | awk '{print $1}')
    log_info "No backups from last ${KEEP_COUNT} day(s), keeping last ${MIN_KEEP_COUNT} backups"
fi

# Get files to delete (all files except those to keep)
ALL_FILES=$(echo "$BACKUP_FILES" | awk '{print $1}')
FILES_TO_DELETE=""

while IFS= read -r file; do
    if ! echo "$FILES_TO_KEEP" | grep -q "^${file}$"; then
        FILES_TO_DELETE="${FILES_TO_DELETE}${file}${IFS}"
    fi
done <<< "$ALL_FILES"

DELETE_COUNT=$(echo "$FILES_TO_DELETE" | grep -v '^$' | wc -l)

if [ "$DELETE_COUNT" -eq 0 ]; then
    log_info "No files to delete. All backups are within retention policy."
    exit 0
fi

log_info "Files to keep: ${KEEP_COUNT}"
echo "$FILES_TO_KEEP" | grep -v '^$' | awk '{print "  - " $0}'

# Confirm deletion (skip if AUTO_CONFIRM is set)
if [ "$AUTO_CONFIRM" != "true" ] && [ "$AUTO_CONFIRM" != "1" ] && [ "$AUTO_CONFIRM" != "yes" ]; then
    echo ""
    log_warn "The following ${DELETE_COUNT} files will be deleted:"
    echo "$FILES_TO_DELETE" | awk '{print "  - " $0}'
    echo ""
    read -p "Do you want to proceed? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
else
    log_info "Auto-confirm mode: proceeding with deletion of ${DELETE_COUNT} files"
fi

# Delete files
log_info "Deleting old backup files..."
DELETED=0
FAILED=0

while IFS= read -r file; do
    if [ -n "$file" ]; then
        if aws s3 rm "s3://${S3_BUCKET}/${file}" --region "${AWS_REGION}" 2>&1; then
            DELETED=$((DELETED + 1))
            log_info "Deleted: ${file}"
        else
            FAILED=$((FAILED + 1))
            log_error "Failed to delete: ${file}"
        fi
    fi
done <<< "$FILES_TO_DELETE"

# Also cleanup orphaned checksum files (checksum files without corresponding backup)
log_info "Cleaning up orphaned checksum files..."
CHECKSUM_FILES=$(aws s3api list-objects-v2 \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}/" \
    --query "Contents[?contains(Key, '.checksum')].[Key]" \
    --output text \
    --region "${AWS_REGION}")

ORPHANED_CHECKSUMS=0
while IFS= read -r checksum_file; do
    if [ -n "$checksum_file" ]; then
        # Get corresponding backup file name
        backup_file="${checksum_file%.checksum}.sql.gz"
        # Check if backup file exists
        if ! aws s3api head-object --bucket "${S3_BUCKET}" --key "${backup_file}" --region "${AWS_REGION}" > /dev/null 2>&1; then
            # Backup file doesn't exist, delete checksum
            if aws s3 rm "s3://${S3_BUCKET}/${checksum_file}" --region "${AWS_REGION}" 2>&1; then
                ORPHANED_CHECKSUMS=$((ORPHANED_CHECKSUMS + 1))
                log_info "Deleted orphaned checksum: ${checksum_file}"
            fi
        fi
    fi
done <<< "$CHECKSUM_FILES"

# Also delete checksum files for deleted backups
while IFS= read -r file; do
    if [ -n "$file" ]; then
        checksum_file="${file%.sql.gz}.checksum"
        if aws s3api head-object --bucket "${S3_BUCKET}" --key "${checksum_file}" --region "${AWS_REGION}" > /dev/null 2>&1; then
            if aws s3 rm "s3://${S3_BUCKET}/${checksum_file}" --region "${AWS_REGION}" 2>&1; then
                log_info "Deleted checksum for removed backup: ${checksum_file}"
            fi
        fi
    fi
done <<< "$FILES_TO_DELETE"

log_info "Cleanup complete!"
log_info "Deleted: ${DELETED} backup files"
if [ "$ORPHANED_CHECKSUMS" -gt 0 ]; then
    log_info "Deleted: ${ORPHANED_CHECKSUMS} orphaned checksum files"
fi
if [ "$FAILED" -gt 0 ]; then
    log_warn "Failed: ${FAILED} files"
fi
if [ "$RECENT_COUNT" -gt 0 ]; then
    log_info "Kept: ${KEEP_COUNT} backups from last ${KEEP_DAYS} day(s)"
else
    log_info "Kept: ${KEEP_COUNT} most recent backups (no backups from last ${KEEP_DAYS} day(s))"
fi

