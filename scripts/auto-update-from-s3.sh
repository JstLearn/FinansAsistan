#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Automatic Update from S3 (Development Only)
# Manifest.json'u kontrol eder ve commit hash değişmişse günceller
# Cron job ile kullanım için tasarlanmıştır
# 
# ⚠️ NOTE: This script is for DEVELOPMENT only (Docker Compose)!
# Production uses Kubernetes with ArgoCD for automatic updates.
# ArgoCD automatically syncs from GitHub, no S3 trigger needed.
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$PROJECT_DIR/.s3-manifest.json"
LOCK_FILE="$PROJECT_DIR/.update.lock"

# Lock file kontrolü (aynı anda birden fazla güncelleme çalışmasın)
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$PID" ] && ps -p "$PID" > /dev/null 2>&1; then
        log_info "Update already in progress (PID: $PID), skipping..."
        exit 0
    else
        # Stale lock file, remove it
        rm -f "$LOCK_FILE"
    fi
fi

# Lock file oluştur
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# 1. Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# 2. Check AWS Credentials
# AWS CLI automatically uses credentials from:
# 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
# 2. AWS credentials file (~/.aws/credentials)
# 3. IAM roles (if running on EC2)
# 4. AWS SSO
log_info "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not found or invalid!"
    log_info "Please configure AWS credentials using one of the following methods:"
    log_info "  1. Environment variables:"
    log_info "     export AWS_ACCESS_KEY_ID=your_key"
    log_info "     export AWS_SECRET_ACCESS_KEY=your_secret"
    log_info "  2. AWS credentials file: ~/.aws/credentials"
    log_info "  3. AWS IAM role (if running on EC2)"
    log_info "  4. AWS SSO: aws sso login"
    exit 1
fi
log_success "AWS credentials verified"

AWS_REGION=${AWS_REGION:-eu-central-1}
S3_BUCKET=${S3_BUCKET:-finans-asistan-backups}

# 3. Check if we're in the project directory
cd "$PROJECT_DIR" || {
    log_error "Failed to change to project directory: $PROJECT_DIR"
    exit 1
}

# Check for docker-compose files (prod, dev, or default)
if [ ! -f "docker-compose.prod.yml" ] && [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.dev.yml" ]; then
    log_error "No docker-compose file found. Please run this script from the project root directory."
    exit 1
fi

# 4. Download manifest from S3
log_info "Checking for updates from S3..."

TEMP_MANIFEST=$(mktemp)
if ! aws s3 cp "s3://${S3_BUCKET}/manifest.json" "$TEMP_MANIFEST" 2>/dev/null; then
    log_warn "Could not download manifest.json from S3. Skipping update check."
    rm -f "$TEMP_MANIFEST"
    exit 0
fi

# 5. Parse manifest
if ! command -v jq &> /dev/null; then
    # Fallback: manual JSON parsing
    S3_COMMIT=$(grep -o '"commit"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_MANIFEST" | cut -d'"' -f4 || echo "")
    S3_BRANCH=$(grep -o '"branch"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_MANIFEST" | cut -d'"' -f4 || echo "")
    S3_TIMESTAMP=$(grep -o '"uploaded"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_MANIFEST" | cut -d'"' -f4 || echo "")
else
    S3_COMMIT=$(jq -r '.commit' "$TEMP_MANIFEST" 2>/dev/null || echo "")
    S3_BRANCH=$(jq -r '.branch' "$TEMP_MANIFEST" 2>/dev/null || echo "")
    S3_TIMESTAMP=$(jq -r '.uploaded' "$TEMP_MANIFEST" 2>/dev/null || echo "")
fi

if [ -z "$S3_COMMIT" ]; then
    log_warn "Could not parse commit hash from manifest. Skipping update check."
    rm -f "$TEMP_MANIFEST"
    exit 0
fi

# 6. Check local commit hash
LOCAL_COMMIT=""
if [ -f "$MANIFEST_FILE" ]; then
    if command -v jq &> /dev/null; then
        LOCAL_COMMIT=$(jq -r '.commit' "$MANIFEST_FILE" 2>/dev/null || echo "")
    else
        LOCAL_COMMIT=$(grep -o '"commit"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | cut -d'"' -f4 || echo "")
    fi
fi

# 7. Compare commits
if [ "$S3_COMMIT" = "$LOCAL_COMMIT" ] && [ -n "$LOCAL_COMMIT" ]; then
    log_info "No updates available. Current commit: ${LOCAL_COMMIT:0:7}"
    rm -f "$TEMP_MANIFEST"
    exit 0
fi

# 8. Update available!
log_info "Update available!"
log_info "  Current commit: ${LOCAL_COMMIT:-none}"
log_info "  New commit: ${S3_COMMIT:0:7}"
log_info "  Branch: $S3_BRANCH"
log_info "  Uploaded: $S3_TIMESTAMP"

# 8.1. Check changed services
CHANGED_SERVICES="[]"
if command -v jq &> /dev/null; then
    # Try to parse as JSON first
    CHANGED_SERVICES=$(jq -r '.changed_services // []' "$TEMP_MANIFEST" 2>/dev/null || echo "[]")
    # If jq failed (invalid JSON like [frontend] without quotes), try manual parsing
    if [ "$CHANGED_SERVICES" = "[]" ] || [ -z "$CHANGED_SERVICES" ]; then
        # Extract from [frontend] format and convert to ["frontend"]
        RAW_SERVICES=$(grep -o '"changed_services"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$TEMP_MANIFEST" | sed 's/.*\[\(.*\)\].*/\1/' | tr -d ' ' || echo "")
        if [ -n "$RAW_SERVICES" ] && [ "$RAW_SERVICES" != "frontend" ] && [ "$RAW_SERVICES" != "backend" ]; then
            # Multiple services - convert to proper JSON array format
            CHANGED_SERVICES=$(echo "$RAW_SERVICES" | sed 's/^/["/; s/$/"]/; s/,/","/g' || echo "[]")
        elif [ -n "$RAW_SERVICES" ]; then
            # Single service - wrap in quotes and brackets
            CHANGED_SERVICES="[\"$RAW_SERVICES\"]"
        fi
    fi
else
    # Fallback: manual parsing - handle both [frontend] and ["frontend"] formats
    RAW_SERVICES=$(grep -o '"changed_services"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$TEMP_MANIFEST" | sed 's/.*\[\(.*\)\].*/\1/' | tr -d ' ' || echo "")
    if [ -n "$RAW_SERVICES" ] && [ "$RAW_SERVICES" != "frontend" ] && [ "$RAW_SERVICES" != "backend" ]; then
        # Multiple services - convert to proper JSON array format
        CHANGED_SERVICES=$(echo "$RAW_SERVICES" | sed 's/^/["/; s/$/"]/; s/,/","/g' || echo "[]")
    elif [ -n "$RAW_SERVICES" ]; then
        # Single service - wrap in quotes and brackets
        CHANGED_SERVICES="[\"$RAW_SERVICES\"]"
    fi
fi

if [ "$CHANGED_SERVICES" = "[]" ] || [ -z "$CHANGED_SERVICES" ]; then
    log_info "No service changes detected. Only configuration or other files changed."
    log_info "Skipping service updates."
    # Still update manifest to track commit
    cp "$TEMP_MANIFEST" "$MANIFEST_FILE"
    rm -f "$TEMP_MANIFEST"
    exit 0
fi

log_info "Changed services: $CHANGED_SERVICES"

# 8.2. Check coordination (for gradual rollout)
COORDINATION_KEY="updates/coordination-${S3_COMMIT}.json"
COORDINATION_FILE=$(mktemp)

if aws s3 cp "s3://${S3_BUCKET}/${COORDINATION_KEY}" "$COORDINATION_FILE" 2>/dev/null; then
    log_info "Coordination file found. Checking batch assignment..."
    
    # Detect machine ID
    MACHINE_ID=""
    if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/instance-id &> /dev/null; then
        MACHINE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    else
        MACHINE_ID=$(hostname)
    fi
    
    # Check if this machine should update now
    SHOULD_UPDATE=false
    
    if command -v jq &> /dev/null; then
        # For each changed service, check if this machine is in the current batch
        for SERVICE in $(echo "$CHANGED_SERVICES" | jq -r '.[]' 2>/dev/null); do
            CURRENT_BATCH=$(jq -r ".services[\"$SERVICE\"].current_batch // 0" "$COORDINATION_FILE" 2>/dev/null || echo "0")
            BATCH_SIZE=$(jq -r ".services[\"$SERVICE\"].batch_size // 2" "$COORDINATION_FILE" 2>/dev/null || echo "2")
            
            # Check if machine is registered
            IS_REGISTERED=$(jq -r ".services[\"$SERVICE\"].registered_machines[] | select(. == \"$MACHINE_ID\")" "$COORDINATION_FILE" 2>/dev/null | wc -l)
            
            if [ "$IS_REGISTERED" -eq 0 ]; then
                # Machine not registered yet - register it
                log_info "Registering machine $MACHINE_ID for service $SERVICE..."
                
                # Add machine to registered list
                jq ".services[\"$SERVICE\"].registered_machines += [\"$MACHINE_ID\"]" "$COORDINATION_FILE" > "${COORDINATION_FILE}.tmp"
                mv "${COORDINATION_FILE}.tmp" "$COORDINATION_FILE"
                
                # Assign to next batch
                REGISTERED_COUNT=$(jq -r ".services[\"$SERVICE\"].registered_machines | length" "$COORDINATION_FILE")
                ASSIGNED_BATCH=$(( (REGISTERED_COUNT - 1) / BATCH_SIZE + 1 ))
                
                log_info "Machine $MACHINE_ID assigned to batch $ASSIGNED_BATCH for service $SERVICE"
                
                # Update coordination file
                aws s3 cp "$COORDINATION_FILE" "s3://${S3_BUCKET}/${COORDINATION_KEY}" \
                    --content-type "application/json" || log_warn "Failed to update coordination"
            fi
            
            # Check if this machine's batch is active
            ASSIGNED_BATCH=$(jq -r ".services[\"$SERVICE\"].registered_machines | to_entries | map(select(.value == \"$MACHINE_ID\")) | .[0].key // -1" "$COORDINATION_FILE" 2>/dev/null || echo "-1")
            if [ "$ASSIGNED_BATCH" -ge 0 ]; then
                ASSIGNED_BATCH=$(( ASSIGNED_BATCH / BATCH_SIZE + 1 ))
                CURRENT_BATCH=$(jq -r ".services[\"$SERVICE\"].current_batch // 0" "$COORDINATION_FILE" 2>/dev/null || echo "0")
                
                if [ "$ASSIGNED_BATCH" -le "$CURRENT_BATCH" ]; then
                    SHOULD_UPDATE=true
                    log_info "Machine $MACHINE_ID is in batch $ASSIGNED_BATCH (current: $CURRENT_BATCH) for service $SERVICE"
                else
                    log_info "Machine $MACHINE_ID is in batch $ASSIGNED_BATCH, waiting for batch $CURRENT_BATCH to complete..."
                fi
            fi
        done
    fi
    
    if [ "$SHOULD_UPDATE" = false ]; then
        log_info "This machine is not in the current update batch. Waiting..."
        rm -f "$COORDINATION_FILE" "$TEMP_MANIFEST"
        exit 0
    fi
    
    rm -f "$COORDINATION_FILE"
else
    log_info "No coordination file found. Proceeding with immediate update."
fi

# 9. Run update script with changed services
log_info "Running update script..."
if [ -f "$SCRIPT_DIR/update-from-s3.sh" ]; then
    # Pass changed services as environment variable
    export CHANGED_SERVICES_JSON="$CHANGED_SERVICES"
    # Ensure production mode is used (don't set USE_DEV_MODE)
    unset USE_DEV_MODE
    bash "$SCRIPT_DIR/update-from-s3.sh"
    UPDATE_EXIT_CODE=$?
    
    if [ $UPDATE_EXIT_CODE -eq 0 ]; then
        # Save new manifest
        cp "$TEMP_MANIFEST" "$MANIFEST_FILE"
        log_success "Update completed successfully!"
        
        # Update coordination to mark this machine as completed
        if [ -f "$COORDINATION_FILE" ] || aws s3 cp "s3://${S3_BUCKET}/${COORDINATION_KEY}" "$COORDINATION_FILE" 2>/dev/null; then
            if command -v jq &> /dev/null && [ -n "${MACHINE_ID:-}" ]; then
                for SERVICE in $(echo "$CHANGED_SERVICES" | jq -r '.[]' 2>/dev/null); do
                    # Mark machine as completed in coordination
                    jq ".services[\"$SERVICE\"].completed_machines += [\"$MACHINE_ID\"]" "$COORDINATION_FILE" > "${COORDINATION_FILE}.tmp"
                    mv "${COORDINATION_FILE}.tmp" "$COORDINATION_FILE"
                done
                aws s3 cp "$COORDINATION_FILE" "s3://${S3_BUCKET}/${COORDINATION_KEY}" \
                    --content-type "application/json" || log_warn "Failed to update coordination"
                rm -f "$COORDINATION_FILE"
            fi
        fi
    else
        log_error "Update failed with exit code: $UPDATE_EXIT_CODE"
        rm -f "$TEMP_MANIFEST"
        exit 1
    fi
else
    log_error "update-from-s3.sh not found!"
    rm -f "$TEMP_MANIFEST"
    exit 1
fi

rm -f "$TEMP_MANIFEST"

