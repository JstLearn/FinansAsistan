#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - PostgreSQL WAL Archiving Script
# Her WAL segment'ini S3'e yükler
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Environment variables
S3_BUCKET="${S3_BUCKET:-finans-asistan-backups}"
S3_PREFIX="${S3_PREFIX:-postgres/wal}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

# WAL file path (PostgreSQL tarafından geçirilir)
WAL_FILE="${1:-}"

if [ -z "$WAL_FILE" ]; then
    echo "Usage: $0 <wal_file_path>"
    exit 1
fi

# WAL file name (örn: 000000010000000000000001)
WAL_NAME=$(basename "$WAL_FILE")

# Date-based directory structure (YYYYMMDD)
DATE_DIR=$(date -u +"%Y%m%d")

# S3 path
S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${DATE_DIR}/${WAL_NAME}"

# Upload to S3
aws s3 cp "$WAL_FILE" "$S3_PATH" \
    --region "$AWS_REGION" \
    --storage-class STANDARD_IA \
    --quiet

# Return success (PostgreSQL için)
exit 0

