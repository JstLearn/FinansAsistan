#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Transfer Leadership Script
# Transfers leadership from current leader to new leader
# ════════════════════════════════════════════════════════════

set -euo pipefail

BUCKET="${S3_BUCKET:-finans-asistan-backups}"
LEADER_KEY="current-leader.json"
NEW_LEADER_ID="${1:-}"
NEW_LEADER_TYPE="${2:-physical}"  # physical or ec2

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

# Validate arguments
if [ -z "$NEW_LEADER_ID" ]; then
    echo "Usage: $0 <new_leader_id> [leader_type]"
    echo "Example: $0 ec2-instance-123 ec2"
    exit 1
fi

# Get current leader info
CURRENT_LEADER=$(aws s3 cp "s3://${BUCKET}/${LEADER_KEY}" - 2>/dev/null || echo "")

if [ -z "$CURRENT_LEADER" ]; then
    echo "No current leader found. Registering new leader..."
else
    CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // "unknown"')
    echo "Current leader: $CURRENT_LEADER_ID"
fi

# Create new leader info
NEW_LEADER_INFO=$(jq -n \
    --arg leader_id "$NEW_LEADER_ID" \
    --arg leader_type "$NEW_LEADER_TYPE" \
    --arg registered_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg last_heartbeat "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
        leader_id: $leader_id,
        leader_type: $leader_type,
        registered_at: $registered_at,
        last_heartbeat: $last_heartbeat,
        transferred_from: ($CURRENT_LEADER_ID // null)
    }')

# Upload to S3
echo "Transferring leadership to: $NEW_LEADER_ID ($NEW_LEADER_TYPE)"
aws s3 cp - "s3://${BUCKET}/${LEADER_KEY}" \
    --content-type "application/json" \
    <<< "$NEW_LEADER_INFO"

echo "✅ Leadership transferred successfully"
echo "   New Leader ID: $NEW_LEADER_ID"
echo "   New Leader Type: $NEW_LEADER_TYPE"

