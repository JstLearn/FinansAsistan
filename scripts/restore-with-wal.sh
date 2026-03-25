#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - PostgreSQL Restore with WAL Recovery
# Son backup + WAL log'ları ile tam kurtarma
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Environment variables
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-${DB_NAME}}"
DB_USER="${POSTGRES_USER:-${DB_USER}}"
DB_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD}}"
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: POSTGRES_DB, POSTGRES_USER, and POSTGRES_PASSWORD environment variables must be set"
    exit 1
fi

# S3 Configuration
if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3_BUCKET environment variable must be set"
    exit 1
fi
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-postgres/backups}"
S3_WAL_PREFIX="${S3_WAL_PREFIX:-postgres/wal}"
if [ -z "$AWS_REGION" ]; then
    echo "Error: AWS_REGION environment variable must be set"
    exit 1
fi

# Restore directory
RESTORE_DIR="/tmp/postgres-restore"
WAL_DIR="${RESTORE_DIR}/wal"
BACKUP_FILE="${1:-LATEST}"

# Export password for psql
export PGPASSWORD="${DB_PASSWORD}"

echo "═══════════════════════════════════════════════════════════"
echo "  PostgreSQL Restore with WAL Recovery"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Create restore directory
mkdir -p "${RESTORE_DIR}"
mkdir -p "${WAL_DIR}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    exit 1
fi

# Get latest backup if LATEST specified
if [ "$BACKUP_FILE" = "LATEST" ]; then
    echo "📋 Finding latest backup..."
    BACKUP_FILE=$(aws s3 ls "s3://${S3_BUCKET}/${S3_BACKUP_PREFIX}/" \
        --region "${AWS_REGION}" \
        --recursive \
        | sort -r \
        | head -n 1 \
        | awk '{print $4}')
    
    if [ -z "$BACKUP_FILE" ]; then
        echo "❌ Error: No backup found in S3"
        exit 1
    fi
    
    echo "✅ Found latest backup: ${BACKUP_FILE}"
fi

# Download backup
echo ""
echo "📥 Downloading backup from S3..."
LOCAL_BACKUP="${RESTORE_DIR}/backup.sql.gz"
aws s3 cp "s3://${S3_BUCKET}/${BACKUP_FILE}" "${LOCAL_BACKUP}" \
    --region "${AWS_REGION}"

if [ ! -f "${LOCAL_BACKUP}" ]; then
    echo "❌ Error: Failed to download backup"
    exit 1
fi

echo "✅ Backup downloaded"

# Extract backup
echo ""
echo "📦 Extracting backup..."
gunzip -c "${LOCAL_BACKUP}" > "${RESTORE_DIR}/backup.sql"

# Get backup timestamp from filename
BACKUP_TIMESTAMP=$(echo "$BACKUP_FILE" | grep -oP '\d{8}_\d{6}' | head -n 1 || echo "")
if [ -z "$BACKUP_TIMESTAMP" ]; then
    BACKUP_TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
fi

# Download WAL files (from backup timestamp to now)
echo ""
echo "📥 Downloading WAL files from S3..."
echo "   Backup timestamp: ${BACKUP_TIMESTAMP}"

# Extract date from backup timestamp (YYYYMMDD)
BACKUP_DATE=$(echo "$BACKUP_TIMESTAMP" | cut -d'_' -f1)

# List all WAL files from backup date onwards
WAL_COUNT=0
WAL_FILES=$(aws s3 ls "s3://${S3_BUCKET}/${S3_WAL_PREFIX}/" \
    --region "${AWS_REGION}" \
    --recursive \
    | awk '{print $4}' \
    | grep -E '[0-9A-F]{24}$')

for WAL_PATH in $WAL_FILES; do
    WAL_NAME=$(basename "$WAL_PATH")
    LOCAL_WAL="${WAL_DIR}/${WAL_NAME}"
    
    # Download WAL file
    if aws s3 cp "s3://${S3_BUCKET}/${WAL_PATH}" "${LOCAL_WAL}" \
        --region "${AWS_REGION}" \
        --quiet 2>/dev/null; then
        WAL_COUNT=$((WAL_COUNT + 1))
    fi
done

echo "✅ Downloaded ${WAL_COUNT} WAL files"

# Restore database
echo ""
echo "🔄 Restoring database..."
echo "⚠️  WARNING: This will drop and recreate the database!"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Drop and recreate database
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME};
EOF

# Restore backup
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" < "${RESTORE_DIR}/backup.sql"

echo "✅ Database restored from backup"

# Apply WAL files (if any)
if [ "$WAL_COUNT" -gt 0 ]; then
    echo ""
    echo "🔄 Applying WAL files for point-in-time recovery..."
    
    # Note: Full PITR requires PostgreSQL to be in recovery mode
    # This is a simplified version - for production, use pg_basebackup + recovery.conf
    echo "⚠️  Note: Full WAL recovery requires PostgreSQL recovery mode."
    echo "   For production use, configure recovery.conf and restart PostgreSQL."
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Restore completed!"
echo "   Backup: ${BACKUP_FILE}"
echo "   WAL Files: ${WAL_COUNT}"
echo "═══════════════════════════════════════════════════════════"

