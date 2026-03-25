#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Apply S3 Lifecycle Policy
# S3 bucket'a lifecycle policy uygular
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
S3_BUCKET="${S3_BUCKET:-finans-asistan-backups}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
LIFECYCLE_POLICY_FILE="${1:-s3-lifecycle-policy.json}"

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

# Check if policy file exists
if [ ! -f "$LIFECYCLE_POLICY_FILE" ]; then
    log_error "Lifecycle policy file not found: ${LIFECYCLE_POLICY_FILE}"
    exit 1
fi

# Check if bucket exists
if ! aws s3 ls "s3://${S3_BUCKET}" > /dev/null 2>&1; then
    log_error "S3 bucket does not exist: ${S3_BUCKET}"
    exit 1
fi

log_info "Applying lifecycle policy to bucket: ${S3_BUCKET}"
log_info "Policy file: ${LIFECYCLE_POLICY_FILE}"

# Apply lifecycle policy
if aws s3api put-bucket-lifecycle-configuration \
    --bucket "${S3_BUCKET}" \
    --lifecycle-configuration "file://${LIFECYCLE_POLICY_FILE}" \
    --region "${AWS_REGION}"; then
    log_info "✅ Lifecycle policy applied successfully!"
    
    # Verify policy
    log_info "Verifying lifecycle policy..."
    aws s3api get-bucket-lifecycle-configuration \
        --bucket "${S3_BUCKET}" \
        --region "${AWS_REGION}" \
        --output json | jq '.'
else
    log_error "Failed to apply lifecycle policy"
    exit 1
fi

