#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Check Leadership Script
# Checks current leader from S3
# ════════════════════════════════════════════════════════════

set -euo pipefail

BUCKET="${S3_BUCKET:-finans-asistan-backups}"
LEADER_KEY="current-leader.json"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# Get leader info from S3
echo "Checking current leader..."
LEADER_INFO=$(aws s3 cp "s3://${BUCKET}/${LEADER_KEY}" - 2>/dev/null || echo "")

if [ -z "$LEADER_INFO" ]; then
    echo "No leader found (initial setup or system down)"
    exit 0
fi

# Parse and display leader info
LEADER_ID=$(echo "$LEADER_INFO" | jq -r '.leader_id // "unknown"')
LEADER_TYPE=$(echo "$LEADER_INFO" | jq -r '.leader_type // "unknown"')
LAST_HEARTBEAT=$(echo "$LEADER_INFO" | jq -r '.last_heartbeat // "unknown"')
REGISTERED_AT=$(echo "$LEADER_INFO" | jq -r '.registered_at // "unknown"')

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Current Leader Information"
echo "═══════════════════════════════════════════════════════════"
echo "Leader ID:       $LEADER_ID"
echo "Leader Type:     $LEADER_TYPE"
echo "Last Heartbeat:  $LAST_HEARTBEAT"
echo "Registered At:   $REGISTERED_AT"
echo ""

