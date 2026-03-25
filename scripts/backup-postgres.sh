#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - PostgreSQL Backup Script
# Docker Compose için PostgreSQL yedekleme
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Environment variables
# Priority: POSTGRES_* > DB_* > defaults
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-${DB_NAME}}"
DB_NAME="${POSTGRES_DB:-${DB_NAME}}"  # Use POSTGRES_DB if available
POSTGRES_USER="${POSTGRES_USER:-${DB_USER}}"
DB_USER="${POSTGRES_USER:-${DB_USER}}"  # Use POSTGRES_USER if available
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD}}"
DB_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD}}"  # Use POSTGRES_PASSWORD if available

# Validate required variables
if [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: POSTGRES_DB, POSTGRES_USER, and POSTGRES_PASSWORD environment variables must be set"
    exit 1
fi

# S3 Configuration
if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3_BUCKET environment variable must be set"
    exit 1
fi
S3_PREFIX="${S3_PREFIX:-postgres/backups}"
if [ -z "$AWS_REGION" ]; then
    echo "Error: AWS_REGION environment variable must be set"
    exit 1
fi

# Backup directory
BACKUP_DIR="/tmp/postgres-backups"
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Export password for pg_dump
export PGPASSWORD="${DB_PASSWORD}"

echo "═══════════════════════════════════════════════════════════"
echo "  PostgreSQL Backup Started"
echo "═══════════════════════════════════════════════════════════"
echo "Database: ${POSTGRES_DB}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "User: ${DB_USER}"
echo "Timestamp: ${TIMESTAMP}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    exit 1
fi

# Check if PostgreSQL is accessible
if ! pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to PostgreSQL at ${DB_HOST}:${DB_PORT}"
    exit 1
fi

# Verify database exists before attempting backup
if ! psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${POSTGRES_DB}" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Error: Database '${POSTGRES_DB}' does not exist or is not accessible"
    echo "   Available databases:"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres -c "\l" 2>&1 | grep -E "^\s+\w+" || true
    exit 1
fi

# Check if database has changed since last backup using WAL LSN (most reliable method)
# WAL LSN changes only when there are actual data modifications
CURRENT_WAL_LSN=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${POSTGRES_DB}" -t -A -c "SELECT pg_current_wal_lsn();" 2>/dev/null | tr -d ' \n\r' || echo "")

if [ -z "$CURRENT_WAL_LSN" ]; then
    echo "⚠️  Warning: Could not get WAL LSN, will create backup anyway..."
    # Continue to backup if LSN check fails
else
    # Get last backup's WAL LSN from S3 metadata or checksum file
    LAST_BACKUP_WAL_LSN=""
    LAST_BACKUP_KEY=""
    
    # Try to get last backup's WAL LSN from S3 metadata (direct head-object call is more reliable)
    LAST_BACKUP_KEY=$(aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --prefix "${S3_PREFIX}/backup_" \
        --query "sort_by(Contents[?contains(Key, '.sql.gz')], &LastModified)[-1].Key" \
        --output text \
        --region "${AWS_REGION}" 2>/dev/null | head -1)
    
    if [ -n "$LAST_BACKUP_KEY" ] && [ "$LAST_BACKUP_KEY" != "None" ]; then
        # Get WAL LSN from backup file metadata
        LAST_BACKUP_WAL_LSN=$(aws s3api head-object \
            --bucket "${S3_BUCKET}" \
            --key "${LAST_BACKUP_KEY}" \
            --query "Metadata.wal" \
            --output text \
            --region "${AWS_REGION}" 2>/dev/null || echo "")
        
        # If no WAL in metadata, try to get it from checksum file (for backward compatibility)
        if [ -z "$LAST_BACKUP_WAL_LSN" ] || [ "$LAST_BACKUP_WAL_LSN" = "None" ]; then
            CHECKSUM_KEY="${LAST_BACKUP_KEY%.sql.gz}.checksum"
            # Try to get WAL from checksum file metadata first
            CHECKSUM_WAL=$(aws s3api head-object \
                --bucket "${S3_BUCKET}" \
                --key "${CHECKSUM_KEY}" \
                --query "Metadata.wal" \
                --output text \
                --region "${AWS_REGION}" 2>/dev/null || echo "")
            
            if [ -n "$CHECKSUM_WAL" ] && [ "$CHECKSUM_WAL" != "None" ]; then
                LAST_BACKUP_WAL_LSN="$CHECKSUM_WAL"
            else
                # Last resort: read checksum file content (might contain WAL LSN if it's a new format)
                CHECKSUM_CONTENT=$(aws s3 cp "s3://${S3_BUCKET}/${CHECKSUM_KEY}" - --region "${AWS_REGION}" 2>/dev/null | tr -d ' \n\r' || echo "")
                # If checksum content looks like a WAL LSN (contains /), use it
                if [ -n "$CHECKSUM_CONTENT" ] && [[ "$CHECKSUM_CONTENT" == *"/"* ]]; then
                    LAST_BACKUP_WAL_LSN="$CHECKSUM_CONTENT"
                fi
            fi
        fi
    fi
    
    # Compare WAL LSNs - if they're the same, no changes occurred (exit silently)
    if [ -n "$LAST_BACKUP_WAL_LSN" ] && [ -n "$CURRENT_WAL_LSN" ] && [ "$LAST_BACKUP_WAL_LSN" = "$CURRENT_WAL_LSN" ]; then
        # No changes detected - exit silently to reduce log noise
        exit 0
    fi
    
    # Changes detected - now log the information
    if [ -n "$LAST_BACKUP_WAL_LSN" ]; then
        echo "🔍 Database changes detected (WAL LSN changed):"
        echo "   Last backup WAL LSN: ${LAST_BACKUP_WAL_LSN}"
        echo "   Current WAL LSN:     ${CURRENT_WAL_LSN}"
        echo "   Last backup: ${LAST_BACKUP_KEY}"
    else
        echo "🔍 No previous backup found, creating new backup..."
    fi
fi

# Create backup
echo ""
echo "📦 Creating backup..."
echo "   Note: WAL archiving is active - all transactions are continuously backed up to S3"

# Ensure we have current WAL LSN (if not already set from change detection)
if [ -z "$CURRENT_WAL_LSN" ]; then
    CURRENT_WAL_LSN=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${POSTGRES_DB}" -t -A -c "SELECT pg_current_wal_lsn();" 2>/dev/null | tr -d ' \n\r' || echo "N/A")
fi
echo "   Current WAL LSN: ${CURRENT_WAL_LSN}"

# Use POSTGRES_DB (already resolved above)
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${POSTGRES_DB}" \
    --clean \
    --if-exists \
    --create \
    --format=plain \
    --no-owner \
    --no-acl \
    | gzip > "${BACKUP_FILE}"

if [ ! -f "${BACKUP_FILE}" ] || [ ! -s "${BACKUP_FILE}" ]; then
    echo "❌ Error: Backup file creation failed"
    exit 1
fi

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "✅ Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to S3
echo ""
echo "☁️  Uploading to S3..."
S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/backup_${TIMESTAMP}.sql.gz"

aws s3 cp "${BACKUP_FILE}" "${S3_PATH}" \
    --region "${AWS_REGION}" \
    --storage-class STANDARD_IA \
    --metadata "wal=${CURRENT_WAL_LSN}"

if [ $? -eq 0 ]; then
    echo "✅ Backup uploaded to S3: ${S3_PATH}"
    
    # Save WAL LSN to a separate file for easier retrieval (backward compatibility)
    CHECKSUM_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/backup_${TIMESTAMP}.checksum"
    echo "${CURRENT_WAL_LSN}" | aws s3 cp - "${CHECKSUM_PATH}" \
        --region "${AWS_REGION}" \
        --content-type "text/plain" \
        --metadata "backup_file=backup_${TIMESTAMP}.sql.gz,wal=${CURRENT_WAL_LSN}"
    
    # Clean up old local backup file (keep last 3 backups locally)
    echo ""
    echo "🧹 Cleaning up old local backups..."
    cd "${BACKUP_DIR}"
    ls -t backup_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null || true
    echo "✅ Local cleanup complete"
    
    # Clean up old S3 backups immediately after successful backup
    # Keep last 1 day of backups or minimum 10 backups (whichever is more)
    echo ""
    echo "🧹 Cleaning up old S3 backups..."
    
    # Configuration for cleanup
    MIN_KEEP_COUNT="${MIN_KEEP_COUNT:-10}"  # Minimum backups to keep
    KEEP_DAYS="${KEEP_DAYS:-1}"  # Keep backups from last N days
    
    # Calculate cutoff time (KEEP_DAYS ago)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CUTOFF_TIME=$(date -u -v-${KEEP_DAYS}d +%s)
    else
        CUTOFF_TIME=$(date -u -d "${KEEP_DAYS} days ago" +%s)
    fi
    
    # List all backup files, sorted by last modified date (newest first)
    BACKUP_FILES=$(aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --prefix "${S3_PREFIX}/backup_" \
        --query "sort_by(Contents[?contains(Key, '.sql.gz')], &LastModified)[*].[Key,LastModified]" \
        --output text \
        --region "${AWS_REGION}" 2>/dev/null | sort -k2 -r || echo "")
    
    if [ -n "$BACKUP_FILES" ]; then
        TOTAL_COUNT=$(echo "$BACKUP_FILES" | wc -l)
        echo "   Found ${TOTAL_COUNT} backup(s) in S3"
        
        # Find backups from last KEEP_DAYS days
        RECENT_BACKUPS=""
        RECENT_COUNT=0
        
        while IFS=$'\t' read -r key last_modified; do
            if [ -z "$key" ]; then
                continue
            fi
            # Parse AWS S3 LastModified format (ISO 8601: 2025-01-19T12:34:56.000Z)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                modified_clean="${last_modified%.*}"
                file_time=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$modified_clean" +%s 2>/dev/null || echo "0")
            else
                file_time=$(date -u -d "$last_modified" +%s 2>/dev/null || echo "0")
            fi
            
            if [ "$file_time" != "0" ] && [ "$file_time" -ge "$CUTOFF_TIME" ]; then
                RECENT_BACKUPS="${RECENT_BACKUPS}${key}${IFS}"
                RECENT_COUNT=$((RECENT_COUNT + 1))
            fi
        done <<< "$BACKUP_FILES"
        
        # Determine files to keep
        if [ "$RECENT_COUNT" -gt 0 ]; then
            FILES_TO_KEEP="$RECENT_BACKUPS"
            KEEP_COUNT=$RECENT_COUNT
            echo "   Keeping ${RECENT_COUNT} backup(s) from last ${KEEP_DAYS} day(s)"
        else
            KEEP_COUNT=$MIN_KEEP_COUNT
            if [ "$TOTAL_COUNT" -le "$MIN_KEEP_COUNT" ]; then
                echo "   No recent backups, but only ${TOTAL_COUNT} backup(s) exist (keeping all)"
            else
                FILES_TO_KEEP=$(echo "$BACKUP_FILES" | head -n "$MIN_KEEP_COUNT" | awk '{print $1}')
                echo "   No backups from last ${KEEP_DAYS} day(s), keeping last ${MIN_KEEP_COUNT} backup(s)"
            fi
        fi
        
        # Get files to delete
        if [ "$TOTAL_COUNT" -gt "$KEEP_COUNT" ]; then
            ALL_FILES=$(echo "$BACKUP_FILES" | awk '{print $1}')
            FILES_TO_DELETE=""
            
            while IFS= read -r file; do
                if [ -n "$file" ] && ! echo "$FILES_TO_KEEP" | grep -q "^${file}$"; then
                    FILES_TO_DELETE="${FILES_TO_DELETE}${file}${IFS}"
                fi
            done <<< "$ALL_FILES"
            
            DELETE_COUNT=$(echo "$FILES_TO_DELETE" | grep -v '^$' | wc -l)
            
            if [ "$DELETE_COUNT" -gt 0 ]; then
                echo "   Deleting ${DELETE_COUNT} old backup(s)..."
                DELETED=0
                FAILED=0
                
                while IFS= read -r file; do
                    if [ -n "$file" ]; then
                        # Delete backup file
                        if aws s3 rm "s3://${S3_BUCKET}/${file}" --region "${AWS_REGION}" > /dev/null 2>&1; then
                            DELETED=$((DELETED + 1))
                            # Also delete corresponding checksum file
                            checksum_file="${file%.sql.gz}.checksum"
                            aws s3 rm "s3://${S3_BUCKET}/${checksum_file}" --region "${AWS_REGION}" > /dev/null 2>&1 || true
                        else
                            FAILED=$((FAILED + 1))
                        fi
                    fi
                done <<< "$FILES_TO_DELETE"
                
                if [ "$DELETED" -gt 0 ]; then
                    echo "   ✅ Deleted ${DELETED} old backup(s) and checksum file(s)"
                fi
                if [ "$FAILED" -gt 0 ]; then
                    echo "   ⚠️  Failed to delete ${FAILED} file(s)"
                fi
            else
                echo "   ✅ No old backups to delete"
            fi
        else
            echo "   ✅ All backups are within retention policy"
        fi
        
        # Also cleanup orphaned checksum files (checksum files without corresponding backup)
        CHECKSUM_FILES=$(aws s3api list-objects-v2 \
            --bucket "${S3_BUCKET}" \
            --prefix "${S3_PREFIX}/backup_" \
            --query "Contents[?contains(Key, '.checksum')].[Key]" \
            --output text \
            --region "${AWS_REGION}" 2>/dev/null || echo "")
        
        if [ -n "$CHECKSUM_FILES" ]; then
            ORPHANED_COUNT=0
            while IFS= read -r checksum_file; do
                if [ -n "$checksum_file" ]; then
                    backup_file="${checksum_file%.checksum}.sql.gz"
                    if ! aws s3api head-object --bucket "${S3_BUCKET}" --key "${backup_file}" --region "${AWS_REGION}" > /dev/null 2>&1; then
                        if aws s3 rm "s3://${S3_BUCKET}/${checksum_file}" --region "${AWS_REGION}" > /dev/null 2>&1; then
                            ORPHANED_COUNT=$((ORPHANED_COUNT + 1))
                        fi
                    fi
                fi
            done <<< "$CHECKSUM_FILES"
            
            if [ "$ORPHANED_COUNT" -gt 0 ]; then
                echo "   ✅ Cleaned up ${ORPHANED_COUNT} orphaned checksum file(s)"
            fi
        fi
    else
        echo "   ℹ️  No backups found in S3 (this is the first backup)"
    fi
    
    echo "✅ S3 cleanup complete"
else
    echo "❌ Error: Failed to upload backup to S3"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Backup completed successfully!"
echo "   S3 Path: ${S3_PATH}"
echo "   Local File: ${BACKUP_FILE}"
echo "═══════════════════════════════════════════════════════════"

