#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - List PostgreSQL Backups
# S3'teki yedekleri listele
# ════════════════════════════════════════════════════════════

set -euo pipefail

# S3 Configuration
S3_BUCKET="${S3_BUCKET:-finans-asistan-backups}"
S3_PREFIX="${S3_PREFIX:-postgres/backups}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

echo "═══════════════════════════════════════════════════════════"
echo "  PostgreSQL Backups in S3"
echo "═══════════════════════════════════════════════════════════"
echo "Bucket: ${S3_BUCKET}"
echo "Prefix: ${S3_PREFIX}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    exit 1
fi

# List backups
echo "📋 Listing backups..."
aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" \
    --region "${AWS_REGION}" \
    --recursive \
    --human-readable \
    --summarize \
    | grep "backup_.*\.sql\.gz" \
    | sort -k1,2

echo ""
echo "═══════════════════════════════════════════════════════════"

