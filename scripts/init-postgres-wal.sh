#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - PostgreSQL WAL Init Script
# PostgreSQL başlangıcında WAL archiving'i aktifleştirir
# ════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  PostgreSQL WAL Archiving Setup"
echo "═══════════════════════════════════════════════════════════"

# Archive script'i zaten read-only mount edilmiş, chmod gerekmez
# Script çalıştırılabilir olarak mount edilmeli

# AWS CLI kontrolü
if ! command -v aws &> /dev/null; then
    echo "⚠️  Warning: AWS CLI not found, installing..."
    apk add --no-cache aws-cli
fi

echo "✅ WAL archiving setup complete"
echo "   Archive command: /scripts/archive-wal.sh"
echo "   S3 Bucket: ${S3_BUCKET:-finans-asistan-backups}"
echo "   S3 Prefix: ${S3_PREFIX:-postgres/wal}"

