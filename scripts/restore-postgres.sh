#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - PostgreSQL Restore Script
# Docker Compose için PostgreSQL geri yükleme
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
S3_PREFIX="${S3_PREFIX:-postgres/backups}"
if [ -z "$AWS_REGION" ]; then
    echo "Error: AWS_REGION environment variable must be set"
    exit 1
fi

# Backup file (can be S3 path or local file)
BACKUP_FILE="${1:-LATEST}"

# Restore directory
RESTORE_DIR="/tmp/postgres-restore"
mkdir -p "${RESTORE_DIR}"

# Export password for psql
export PGPASSWORD="${DB_PASSWORD}"

echo "═══════════════════════════════════════════════════════════"
echo "  PostgreSQL Restore Started"
echo "═══════════════════════════════════════════════════════════"
echo "Database: ${DB_NAME}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "Backup: ${BACKUP_FILE}"
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

# Determine backup file
LOCAL_BACKUP_FILE=""

if [ "${BACKUP_FILE}" = "LATEST" ]; then
    echo "📋 Finding latest backup in S3..."
    LATEST_BACKUP=$(aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" \
        --region "${AWS_REGION}" \
        --recursive \
        | sort | tail -n 1 | awk '{print $4}')
    
    if [ -z "${LATEST_BACKUP}" ]; then
        echo "❌ Error: No backups found in S3"
        exit 1
    fi
    
    BACKUP_FILE="s3://${S3_BUCKET}/${LATEST_BACKUP}"
    echo "✅ Found latest backup: ${BACKUP_FILE}"
fi

# Download from S3 if needed
if [[ "${BACKUP_FILE}" == s3://* ]]; then
    echo ""
    echo "☁️  Downloading backup from S3..."
    BACKUP_FILENAME=$(basename "${BACKUP_FILE}")
    LOCAL_BACKUP_FILE="${RESTORE_DIR}/${BACKUP_FILENAME}"
    
    aws s3 cp "${BACKUP_FILE}" "${LOCAL_BACKUP_FILE}" \
        --region "${AWS_REGION}"
    
    if [ ! -f "${LOCAL_BACKUP_FILE}" ] || [ ! -s "${LOCAL_BACKUP_FILE}" ]; then
        echo "❌ Error: Failed to download backup from S3"
        exit 1
    fi
    
    echo "✅ Backup downloaded: ${LOCAL_BACKUP_FILE}"
else
    LOCAL_BACKUP_FILE="${BACKUP_FILE}"
    
    if [ ! -f "${LOCAL_BACKUP_FILE}" ]; then
        echo "❌ Error: Backup file not found: ${LOCAL_BACKUP_FILE}"
        exit 1
    fi
fi

# Confirm restore
echo ""
echo "⚠️  WARNING: This will DROP and RECREATE the database!"
echo "   Database: ${DB_NAME}"
echo "   Backup: ${LOCAL_BACKUP_FILE}"
read -p "   Are you sure you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "❌ Restore cancelled"
    exit 0
fi

# Restore database
echo ""
echo "🔄 Restoring database..."

# Drop existing database (if exists)
echo "   Dropping existing database..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres \
    -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";" || true

# Restore from backup
echo "   Restoring from backup..."
gunzip -c "${LOCAL_BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres

if [ $? -eq 0 ]; then
    echo "✅ Database restored successfully!"
else
    echo "❌ Error: Database restore failed"
    exit 1
fi

# Clean up
rm -f "${LOCAL_BACKUP_FILE}"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Restore completed successfully!"
echo "   Database: ${DB_NAME}"
echo "═══════════════════════════════════════════════════════════"

