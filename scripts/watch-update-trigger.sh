#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Watch Update Trigger from S3 (Development Only)
# S3'teki update-trigger.json dosyasını izler ve anında güncelleme yapar
# Systemd service veya screen/tmux ile çalıştırılmalıdır
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
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AUTO_UPDATE_SCRIPT="$SCRIPT_DIR/auto-update-from-s3.sh"
TRIGGER_FILE="$PROJECT_DIR/.last-trigger-commit"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not found or invalid!"
    exit 1
fi

AWS_REGION=${AWS_REGION:-eu-central-1}
S3_BUCKET=${S3_BUCKET:-finans-asistan-backups}
TRIGGER_KEY="update-trigger.json"
CHECK_INTERVAL=10  # Check every 10 seconds

log_info "Starting update trigger watcher..."
log_info "S3 Bucket: $S3_BUCKET"
log_info "Trigger Key: $TRIGGER_KEY"
log_info "Check Interval: ${CHECK_INTERVAL}s"

# Read last processed commit
LAST_COMMIT=""
if [ -f "$TRIGGER_FILE" ]; then
    LAST_COMMIT=$(cat "$TRIGGER_FILE" 2>/dev/null || echo "")
fi

# Main loop
while true; do
    # Download trigger file
    TEMP_TRIGGER=$(mktemp)
    if aws s3 cp "s3://${S3_BUCKET}/${TRIGGER_KEY}" "$TEMP_TRIGGER" 2>/dev/null; then
        # Parse trigger file
        if command -v jq &> /dev/null; then
            TRIGGER_COMMIT=$(jq -r '.commit' "$TEMP_TRIGGER" 2>/dev/null || echo "")
            TRIGGER_TIMESTAMP=$(jq -r '.timestamp' "$TEMP_TRIGGER" 2>/dev/null || echo "")
            TRIGGERED=$(jq -r '.triggered' "$TEMP_TRIGGER" 2>/dev/null || echo "false")
        else
            TRIGGER_COMMIT=$(grep -o '"commit"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_TRIGGER" | cut -d'"' -f4 || echo "")
            TRIGGER_TIMESTAMP=$(grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_TRIGGER" | cut -d'"' -f4 || echo "")
            TRIGGERED=$(grep -o '"triggered"[[:space:]]*:[[:space:]]*true' "$TEMP_TRIGGER" > /dev/null && echo "true" || echo "false")
        fi
        
        # Check if trigger is set and commit is different
        if [ "$TRIGGERED" = "true" ] && [ -n "$TRIGGER_COMMIT" ] && [ "$TRIGGER_COMMIT" != "$LAST_COMMIT" ]; then
            log_info "Update trigger detected!"
            log_info "  New commit: ${TRIGGER_COMMIT:0:7}"
            log_info "  Timestamp: $TRIGGER_TIMESTAMP"
            log_info "  Last processed: ${LAST_COMMIT:-none}"
            
            # Run auto-update script
            if [ -f "$AUTO_UPDATE_SCRIPT" ]; then
                log_info "Running auto-update script..."
                # Ensure production mode is used (unset USE_DEV_MODE)
                unset USE_DEV_MODE
                bash "$AUTO_UPDATE_SCRIPT"
                UPDATE_EXIT_CODE=$?
                
                if [ $UPDATE_EXIT_CODE -eq 0 ]; then
                    log_success "Update completed successfully!"
                    # Save processed commit
                    echo "$TRIGGER_COMMIT" > "$TRIGGER_FILE"
                else
                    log_error "Update failed with exit code: $UPDATE_EXIT_CODE"
                fi
            else
                log_error "Auto-update script not found: $AUTO_UPDATE_SCRIPT"
            fi
        fi
        
        rm -f "$TEMP_TRIGGER"
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done

