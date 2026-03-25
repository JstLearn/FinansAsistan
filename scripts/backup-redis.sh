#!/bin/bash
# ============================================================
# FinansAsistan - Redis Backup Script
# Backs up Redis AOF (Append Only File) to S3
# ============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check required environment variables
if [ -z "${S3_BUCKET:-}" ]; then
    log_error "S3_BUCKET environment variable is not set"
    exit 1
fi

if [ -z "${AWS_REGION:-}" ]; then
    AWS_REGION="eu-central-1"
    log_warn "AWS_REGION not set, using default: ${AWS_REGION}"
fi

# Check AWS credentials
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    log_error "AWS credentials not found in environment variables"
    exit 1
fi

# Kubernetes namespace
NAMESPACE="${NAMESPACE:-finans-asistan}"

# S3 prefix for Redis backups
S3_PREFIX="${S3_PREFIX:-redis/backups}"

# Get Redis pod name
log_info "Finding Redis pod..."
REDIS_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$REDIS_POD" ]; then
    log_error "Redis pod not found in namespace ${NAMESPACE}"
    exit 1
fi

log_info "Found Redis pod: ${REDIS_POD}"

# Check if Redis is ready
if ! kubectl wait --for=condition=ready pod/"${REDIS_POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null; then
    log_warn "Redis pod may not be fully ready, continuing anyway..."
fi

# Create backup directory
BACKUP_DIR="/tmp/redis-backups"
mkdir -p "${BACKUP_DIR}"

# Generate timestamp
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/appendonly_${TIMESTAMP}.aof"

log_info "Creating Redis backup..."

# Trigger AOF rewrite to ensure latest data is in AOF file
log_info "Triggering AOF rewrite..."
kubectl exec -n "${NAMESPACE}" "${REDIS_POD}" -- redis-cli BGREWRITEAOF 2>/dev/null || {
    log_warn "AOF rewrite failed or already in progress, continuing with current AOF..."
}

# Wait a bit for AOF rewrite to complete (if it was triggered)
sleep 5

# Copy AOF file from Redis pod
log_info "Copying AOF file from pod..."
kubectl cp "${NAMESPACE}/${REDIS_POD}:/data/appendonly.aof" "${BACKUP_FILE}" 2>/dev/null || {
    log_warn "Failed to copy appendonly.aof, trying appendonlydir..."
    # Try appendonlydir if AOF is in a directory
    kubectl exec -n "${NAMESPACE}" "${REDIS_POD}" -- sh -c "find /data -name 'appendonly.aof' -type f | head -1" | while read -r aof_path; do
        if [ -n "$aof_path" ]; then
            kubectl cp "${NAMESPACE}/${REDIS_POD}:${aof_path}" "${BACKUP_FILE}" 2>/dev/null && break
        fi
    done
}

if [ ! -f "${BACKUP_FILE}" ] || [ ! -s "${BACKUP_FILE}" ]; then
    log_error "Failed to create backup file"
    log_info "Redis may not have AOF enabled or AOF file doesn't exist yet"
    log_info "Checking Redis configuration..."
    kubectl exec -n "${NAMESPACE}" "${REDIS_POD}" -- redis-cli CONFIG GET appendonly 2>/dev/null || true
    exit 1
fi

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
log_success "Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to S3
log_info "Uploading to S3..."
S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/appendonly_${TIMESTAMP}.aof"

aws s3 cp "${BACKUP_FILE}" "${S3_PATH}" \
    --region "${AWS_REGION}" \
    --storage-class STANDARD_IA \
    --metadata "timestamp=${TIMESTAMP},pod=${REDIS_POD}"

if [ $? -eq 0 ]; then
    log_success "Backup uploaded to S3: ${S3_PATH}"
    
    # Clean up local backup file
    rm -f "${BACKUP_FILE}"
    log_success "Local backup file cleaned up"
    
    # Clean up old S3 backups (keep last 10 backups)
    log_info "Cleaning up old S3 backups..."
    MIN_KEEP_COUNT="${MIN_KEEP_COUNT:-10}"
    
    # List all backups, sort by date, keep last MIN_KEEP_COUNT
    aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive | \
        grep "appendonly_.*\.aof$" | \
        sort -r | \
        tail -n +$((MIN_KEEP_COUNT + 1)) | \
        awk '{print $4}' | \
        while read -r old_backup; do
            if [ -n "$old_backup" ]; then
                aws s3 rm "s3://${S3_BUCKET}/${old_backup}" --region "${AWS_REGION}" 2>/dev/null || true
            fi
        done
    
    log_success "Old backups cleaned up (kept last ${MIN_KEEP_COUNT} backups)"
else
    log_error "Failed to upload backup to S3"
    exit 1
fi

log_success "Redis backup completed successfully"

