#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Quick Setup Script
# S3 Backup için hızlı kurulum
# ════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  FinansAsistan S3 Backup Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Load .env file from QUICK_START directory
ENV_FILE="QUICK_START/.env"
if [ ! -f "$ENV_FILE" ]; then
    # Try relative path if absolute doesn't work
    if [ -f "../QUICK_START/.env" ]; then
        ENV_FILE="../QUICK_START/.env"
    elif [ -f "$(dirname "$0")/../QUICK_START/.env" ]; then
        ENV_FILE="$(dirname "$0")/../QUICK_START/.env"
    else
        echo "❌ Error: .env file not found at QUICK_START/.env"
        echo "   Please create QUICK_START/.env file with required AWS credentials:"
        echo "   AWS_ACCESS_KEY_ID=your-access-key-id"
        echo "   AWS_SECRET_ACCESS_KEY=your-secret-access-key"
        echo "   S3_BUCKET=finans-asistan-backups"
        echo "   AWS_REGION=eu-central-1"
        echo "   BACKUP_INTERVAL=300"
        exit 1
    fi
fi

echo "📝 Loading .env file from: $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

# Check if AWS credentials are set
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "❌ Error: AWS credentials not set in .env file"
    echo "   Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI not found. Installing..."
    echo "   Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Error: AWS credentials are invalid"
    echo "   Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
fi
echo "✅ AWS credentials are valid"

# Create S3 bucket if it doesn't exist
echo ""
echo "☁️  Checking S3 bucket..."
if aws s3 ls "s3://${S3_BUCKET}" > /dev/null 2>&1; then
    echo "✅ S3 bucket exists: ${S3_BUCKET}"
else
    echo "📦 Creating S3 bucket: ${S3_BUCKET}"
    aws s3 mb "s3://${S3_BUCKET}" --region "${AWS_REGION}"
    
    # Enable versioning
    echo "   Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${S3_BUCKET}" \
        --versioning-configuration Status=Enabled
    
    # Set lifecycle policy (30 days retention)
    echo "   Setting lifecycle policy (30 days retention)..."
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "${S3_BUCKET}" \
        --lifecycle-configuration '{
            "Rules": [{
                "Id": "delete-old-backups",
                "Status": "Enabled",
                "Expiration": {"Days": 30}
            }]
        }'
    
    echo "✅ S3 bucket created and configured"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Start Docker Compose:"
echo "   docker compose -f docker-compose.dev.yml up -d"
echo ""
echo "2. Check backup service logs:"
echo "   docker compose -f docker-compose.dev.yml logs -f postgres-backup"
echo ""
echo "3. List backups:"
echo "   docker compose -f docker-compose.dev.yml exec postgres-backup /scripts/list-backups.sh"
echo ""
echo "For more information, see: scripts/BACKUP_README.md"
echo "═══════════════════════════════════════════════════════════"

