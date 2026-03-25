#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Update Coordination Script
# Servis bazlı kademeli güncelleme için coordination dosyası oluşturur
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

# Parameters
COMMIT_HASH="${1:-}"
CHANGED_SERVICES="${2:-}"  # JSON array: ["backend", "frontend"]
BATCH_SIZE="${3:-2}"  # Her batch'te kaç makine (default: 2 = %20 for 10 machines)

if [ -z "$COMMIT_HASH" ]; then
    log_error "Usage: $0 <commit-hash> <changed-services-json> [batch-size]"
    log_error "Example: $0 abc123 '[\"frontend\"]' 2"
    exit 1
fi

# AWS Configuration
AWS_REGION=${AWS_REGION:-eu-central-1}
S3_BUCKET=${S3_BUCKET:-finans-asistan-backups-production}

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are invalid!"
    exit 1
fi

# Get all machines from leadership (or use a registry)
log_info "Detecting active machines..."

# Try to get machines from leadership registry or use a default list
# For now, we'll create batches based on a machine registry
# In production, this could read from S3://bucket/machines/registry.json

# Parse changed services
if ! command -v jq &> /dev/null; then
    log_error "jq is required for JSON parsing. Please install jq."
    exit 1
fi

CHANGED_SERVICES_ARRAY=$(echo "$CHANGED_SERVICES" | jq -r '.[]' 2>/dev/null || echo "")

if [ -z "$CHANGED_SERVICES_ARRAY" ]; then
    log_warn "No changed services detected. Skipping coordination."
    exit 0
fi

log_info "Changed services: $CHANGED_SERVICES"

# Get machine list (simplified - in production, read from S3 registry)
# For now, we'll create a coordination structure that machines can register to
# Each machine will check if it's in the current batch

COORDINATION_FILE="/tmp/coordination-${COMMIT_HASH}.json"

# Create coordination structure
cat > "$COORDINATION_FILE" <<EOF
{
  "commit": "${COMMIT_HASH}",
  "phase": "rolling",
  "batch_size": ${BATCH_SIZE},
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "services": {}
}
EOF

# For each changed service, create batches
for SERVICE in $CHANGED_SERVICES_ARRAY; do
    log_info "Creating coordination for service: $SERVICE"
    
    # Create service coordination structure
    # Machines will register themselves and be assigned to batches
    SERVICE_COORD=$(jq -n \
        --arg service "$SERVICE" \
        --argjson batch_size "$BATCH_SIZE" \
        '{
            service: $service,
            status: "pending",
            batch_size: $batch_size,
            batches: [],
            registered_machines: [],
            current_batch: 0
        }')
    
    # Add service to coordination
    jq --argjson svc "$SERVICE_COORD" ".services[\"$SERVICE\"] = \$svc" "$COORDINATION_FILE" > "${COORDINATION_FILE}.tmp"
    mv "${COORDINATION_FILE}.tmp" "$COORDINATION_FILE"
done

# Upload to S3
COORDINATION_KEY="updates/coordination-${COMMIT_HASH}.json"
log_info "Uploading coordination to s3://${S3_BUCKET}/${COORDINATION_KEY}..."

aws s3 cp "$COORDINATION_FILE" "s3://${S3_BUCKET}/${COORDINATION_KEY}" \
    --content-type "application/json" || {
    log_error "Failed to upload coordination file"
    exit 1
}

log_success "Coordination file created and uploaded"
log_info "Location: s3://${S3_BUCKET}/${COORDINATION_KEY}"

# Cleanup
rm -f "$COORDINATION_FILE"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Coordination Summary"
echo "═══════════════════════════════════════════════════════════"
echo "Commit: ${COMMIT_HASH}"
echo "Changed Services: ${CHANGED_SERVICES}"
echo "Batch Size: ${BATCH_SIZE} machines per batch"
echo ""
echo "Machines will register themselves and be assigned to batches"
echo "automatically when they check for updates."
echo ""

