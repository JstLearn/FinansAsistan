#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Register Leadership Script
# Registers this machine as leader in S3
# ════════════════════════════════════════════════════════════

set -euo pipefail

BUCKET="${S3_BUCKET:-finans-asistan-backups}"
LEADER_KEY="current-leader.json"
LEADER_TYPE="${LEADER_TYPE:-physical}"  # physical or ec2
LEADER_ID="${LEADER_ID:-$(hostname)}"

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

# Create leader info JSON
LEADER_INFO=$(jq -n \
    --arg leader_id "$LEADER_ID" \
    --arg leader_type "$LEADER_TYPE" \
    --arg registered_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg last_heartbeat "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
        leader_id: $leader_id,
        leader_type: $leader_type,
        registered_at: $registered_at,
        last_heartbeat: $last_heartbeat
    }')

# Upload to S3
echo "Registering leader: $LEADER_ID ($LEADER_TYPE)"
aws s3 cp - "s3://${BUCKET}/${LEADER_KEY}" \
    --content-type "application/json" \
    <<< "$LEADER_INFO"

echo "✅ Leader registered successfully"
echo "   Leader ID: $LEADER_ID"
echo "   Leader Type: $LEADER_TYPE"

