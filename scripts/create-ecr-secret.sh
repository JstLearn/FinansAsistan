#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - ECR Image Pull Secret Creator
# Creates Kubernetes secret for ECR authentication
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-eu-central-1}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

log_info "Creating ECR image pull secret..."
log_info "Registry: ${ECR_REGISTRY}"
log_info "Region: ${AWS_REGION}"

# Get ECR login password
ECR_PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION})

# Create namespace if it doesn't exist
kubectl create namespace finans-asistan --dry-run=client -o yaml | kubectl apply -f -

# Create or update ECR registry secret
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=${ECR_REGISTRY} \
  --docker-username=AWS \
  --docker-password=${ECR_PASSWORD} \
  --namespace=finans-asistan \
  --dry-run=client -o yaml | kubectl apply -f -

log_success "ECR image pull secret created/updated in namespace 'finans-asistan'"
echo ""
echo "Secret name: ecr-registry-secret"
echo "Namespace: finans-asistan"
echo ""
echo "Note: This secret expires after 12 hours. Run this script again to refresh it."
echo "Or set up a cron job to refresh it automatically."

