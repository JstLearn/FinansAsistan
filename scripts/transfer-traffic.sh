#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Transfer Traffic Script
# Kademeli trafik aktarımı (%10 → %50 → %100)
# ════════════════════════════════════════════════════════════

set -euo pipefail

BUCKET="${S3_BUCKET:-finans-asistan-backups}"
LEADER_KEY="current-leader.json"
NEW_LEADER_IP="${1:-}"
NAMESPACE="${NAMESPACE:-finans-asistan}"

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

# Check prerequisites
if [ -z "$NEW_LEADER_IP" ]; then
    log_error "Usage: $0 <new_leader_ip>"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

# Get current leader info
CURRENT_LEADER=$(aws s3 cp "s3://${BUCKET}/${LEADER_KEY}" - 2>/dev/null || echo "")
if [ -z "$CURRENT_LEADER" ]; then
    log_error "No current leader found"
    exit 1
fi

CURRENT_LEADER_IP=$(echo "$CURRENT_LEADER" | jq -r '.node_ip // ""' 2>/dev/null || echo "")
if [ -z "$CURRENT_LEADER_IP" ] || [ "$CURRENT_LEADER_IP" = "$NEW_LEADER_IP" ]; then
    log_info "No traffic transfer needed (same leader or no IP)"
    exit 0
fi

log_info "Starting gradual traffic transfer..."
log_info "  Current leader: $CURRENT_LEADER_IP"
log_info "  New leader: $NEW_LEADER_IP"

# Step 1: Add new leader with 10% weight
log_info "Step 1: Adding new leader with 10% traffic..."
kubectl patch ingress backend-ingress -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/rules/0/http/paths/-",
    "value": {
      "path": "/",
      "pathType": "Prefix",
      "backend": {
        "service": {
          "name": "backend-new",
          "port": {
            "number": 5000
          }
        },
        "weight": 10
      }
    }
  },
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/0/backend/weight",
    "value": 90
  }
]' || log_warn "Failed to update ingress (may not exist yet)"

log_info "Waiting 2 minutes for traffic to stabilize..."
sleep 120

# Step 2: Increase to 50% weight
log_info "Step 2: Increasing new leader traffic to 50%..."
kubectl patch ingress backend-ingress -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/0/backend/weight",
    "value": 50
  },
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/1/backend/weight",
    "value": 50
  }
]' || log_warn "Failed to update ingress"

log_info "Waiting 2 minutes for traffic to stabilize..."
sleep 120

# Step 3: Increase to 100% weight
log_info "Step 3: Transferring all traffic to new leader (100%)..."
kubectl patch ingress backend-ingress -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/0/backend/weight",
    "value": 0
  },
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/1/backend/weight",
    "value": 100
  }
]' || log_warn "Failed to update ingress"

log_info "Waiting 1 minute before removing old leader..."
sleep 60

# Step 4: Remove old leader
log_info "Step 4: Removing old leader from ingress..."
kubectl patch ingress backend-ingress -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "remove",
    "path": "/spec/rules/0/http/paths/0"
  },
  {
    "op": "replace",
    "path": "/spec/rules/0/http/paths/0/backend/weight",
    "value": null
  }
]' || log_warn "Failed to remove old leader from ingress"

log_success "Traffic transfer completed!"
log_info "All traffic is now routed to: $NEW_LEADER_IP"

