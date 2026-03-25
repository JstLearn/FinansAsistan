#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - k3s Snapshot Script
# Leader node'da çalışır, k3s/etcd snapshot alır ve S3'e yükler
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

# Configuration
S3_BUCKET="${S3_BUCKET:-finans-asistan-backups}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
SNAPSHOT_PREFIX="k3s/snapshots/"
SNAPSHOT_DIR="/tmp/k3s-snapshots"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
SNAPSHOT_FILE="${SNAPSHOT_DIR}/etcd-snapshot-${TIMESTAMP}.db"

# Check if running as root (k3s commands need root)
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (for k3s commands)"
    exit 1
fi

# Check if k3s is installed
if ! command -v k3s &> /dev/null; then
    log_error "k3s is not installed or not in PATH"
    exit 1
fi

# Check if k3s server is running
if ! systemctl is-active --quiet k3s 2>/dev/null; then
    log_error "k3s server is not running"
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    exit 1
fi

log_info "Starting k3s snapshot creation..."

# Create snapshot directory
mkdir -p "$SNAPSHOT_DIR"

# Create k3s etcd snapshot
log_info "Creating k3s etcd snapshot..."
# Note: Script runs as root, no need for sudo
if k3s etcd-snapshot save "$SNAPSHOT_FILE"; then
    log_success "Snapshot created: $SNAPSHOT_FILE"
else
    log_error "Failed to create k3s snapshot"
    exit 1
fi

# Check if snapshot file exists
if [ ! -f "$SNAPSHOT_FILE" ]; then
    log_error "Snapshot file not found: $SNAPSHOT_FILE"
    exit 1
fi

# Get snapshot size
SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_FILE" | cut -f1)
log_info "Snapshot size: $SNAPSHOT_SIZE"

# Upload to S3
SNAPSHOT_KEY="${SNAPSHOT_PREFIX}etcd-snapshot-${TIMESTAMP}.db"
log_info "Uploading snapshot to S3: s3://${S3_BUCKET}/${SNAPSHOT_KEY}"

if aws s3 cp "$SNAPSHOT_FILE" "s3://${S3_BUCKET}/${SNAPSHOT_KEY}" \
    --region "$AWS_REGION" \
    --storage-class STANDARD; then
    log_success "Snapshot uploaded to S3: ${SNAPSHOT_KEY}"
else
    log_error "Failed to upload snapshot to S3"
    rm -f "$SNAPSHOT_FILE"
    exit 1
fi

# Clean up local snapshot file (keep only in S3)
rm -f "$SNAPSHOT_FILE"
log_info "Local snapshot file removed (stored in S3)"

# List snapshots in S3 (for verification)
log_info "Current snapshots in S3:"
aws s3 ls "s3://${S3_BUCKET}/${SNAPSHOT_PREFIX}" --recursive | \
    grep "\.db$" | \
    tail -n 5 | \
    awk '{print "  " $4 " (" $1 " " $2 ")"}'

log_success "k3s snapshot completed successfully!"
log_info "Snapshot location: s3://${S3_BUCKET}/${SNAPSHOT_KEY}"

