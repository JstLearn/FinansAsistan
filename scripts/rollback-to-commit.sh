#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Rollback to Previous Commit
# Eski bir commit'e geri döner ve S3'e yükler
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  FinansAsistan - Rollback to Previous Commit"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Check Git
if ! command -v git &> /dev/null; then
    log_error "Git not found. Please install Git first."
    exit 1
fi

# 2. Check if we're in a git repository
if [ ! -d ".git" ]; then
    log_error "Not a git repository. Please run this script from the project root."
    exit 1
fi

# 3. Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# 4. Set AWS Credentials
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    export AWS_ACCESS_KEY_ID="AKIAQXWSM7CDYDJU4X4K"
    log_warn "Using default AWS_ACCESS_KEY_ID. Override with environment variable for security."
fi
if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    export AWS_SECRET_ACCESS_KEY="kRWuY3YpBw4mR5KYsaCSKHvNmDvs"
    log_warn "Using default AWS_SECRET_ACCESS_KEY. Override with environment variable for security."
fi

AWS_REGION=${AWS_REGION:-eu-central-1}
S3_BUCKET=${S3_BUCKET:-finans-asistan-backups-production}

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are invalid!"
    exit 1
fi
log_success "AWS credentials verified"

# 5. Show commit history
log_info "Recent commits:"
echo ""
git log --oneline -10
echo ""

# 6. Get commit hash from user
read -p "Enter commit hash to rollback to (or press Enter for previous commit): " COMMIT_HASH

if [ -z "$COMMIT_HASH" ]; then
    COMMIT_HASH=$(git rev-parse HEAD~1)
    log_info "Using previous commit: ${COMMIT_HASH:0:7}"
else
    # Validate commit hash
    if ! git cat-file -e "$COMMIT_HASH" 2>/dev/null; then
        log_error "Invalid commit hash: $COMMIT_HASH"
        exit 1
    fi
fi

COMMIT_SHORT="${COMMIT_HASH:0:7}"
COMMIT_MESSAGE=$(git log -1 --pretty=format:"%s" "$COMMIT_HASH")

log_info "Rolling back to:"
log_info "  Commit: $COMMIT_SHORT"
log_info "  Message: $COMMIT_MESSAGE"

# 7. Confirm
echo ""
read -p "Are you sure you want to rollback? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_warn "Rollback cancelled"
    exit 0
fi

# 8. Checkout to commit
log_info "Checking out to commit $COMMIT_SHORT..."
git checkout "$COMMIT_HASH" || {
    log_error "Failed to checkout commit"
    exit 1
}

# 9. Upload to S3
log_info "Uploading to S3..."

# Create manifest
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

cat > /tmp/rollback-manifest.json <<EOF
{
  "commit": "${COMMIT_HASH}",
  "branch": "${BRANCH_NAME}",
  "uploaded": "${TIMESTAMP}",
  "location": "s3://${S3_BUCKET}/FinansAsistan/",
  "rollback": true,
  "changed_services": ["backend", "frontend", "event-processor"]
}
EOF

# Upload project to S3
log_info "Uploading project files to S3..."
aws s3 sync . "s3://${S3_BUCKET}/FinansAsistan/" \
    --exclude ".git/*" \
    --exclude ".github/workflows/*.yml" \
    --exclude "*.log" \
    --exclude ".DS_Store" \
    --exclude "Thumbs.db" \
    --exclude ".backup-*" \
    --exclude "node_modules/*" || {
    log_error "Failed to upload to S3"
    git checkout - 2>/dev/null || true
    exit 1
}

# Upload manifest
aws s3 cp /tmp/rollback-manifest.json "s3://${S3_BUCKET}/manifest.json" \
    --content-type "application/json" || {
    log_error "Failed to upload manifest"
    git checkout - 2>/dev/null || true
    exit 1
}

log_success "Rollback completed!"
log_info "  Commit: $COMMIT_SHORT"
log_info "  S3 Location: s3://${S3_BUCKET}/FinansAsistan/"

# 10. Return to original branch
log_info "Returning to original branch..."
git checkout - 2>/dev/null || git checkout master 2>/dev/null || true

echo ""
log_success "✅ Rollback successful!"
log_info "Production machines will automatically update within 10 minutes (if auto-update is enabled)"
log_info "Or run manually: ./scripts/update-from-s3.sh"

rm -f /tmp/rollback-manifest.json