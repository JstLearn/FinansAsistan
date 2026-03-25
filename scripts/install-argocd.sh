#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - ArgoCD Installation Script
# Installs ArgoCD and configures it for GitOps deployment
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

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

log_info "Installing ArgoCD in finans-asistan namespace..."

# Check if ArgoCD is already installed in argocd namespace
if kubectl get deployment argocd-server -n argocd &>/dev/null; then
    log_success "ArgoCD is already installed in argocd namespace!"
    exit 0
fi

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
log_info "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply Patches for HPA (Resource Requests)
log_info "Applying patches for HPA (Resource Requests)..."
kubectl patch deployment argocd-server -n argocd --patch-file k8s/patches/argocd-server-patch.yaml
kubectl patch deployment argocd-repo-server -n argocd --patch-file k8s/patches/argocd-repo-server-patch.yaml

# Wait for ArgoCD to be ready
log_info "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || {
    log_error "ArgoCD installation failed"
    exit 1
}

# Get admin password
log_info "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    log_warn "Could not retrieve ArgoCD password. It may take a few minutes to generate."
    log_info "Run this command later to get the password:"
    echo "kubectl -n finans-asistan get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
else
    log_success "ArgoCD admin password: ${ARGOCD_PASSWORD}"
fi

# Apply ArgoCD configuration
log_info "Applying ArgoCD configuration..."
kubectl apply -f k8s/14-argocd-config.yaml

# Apply ArgoCD Application
log_info "Creating ArgoCD Application..."
kubectl apply -f k8s/13-argocd-application.yaml

log_success "ArgoCD installed successfully!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ArgoCD Access Information"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1. Port forward ArgoCD server:"
echo "   kubectl port-forward svc/argocd-server -n finans-asistan 8080:443"
echo ""
echo "2. Access ArgoCD UI:"
echo "   https://localhost:8080"
echo ""
echo "3. Login credentials:"
echo "   Username: admin"
echo "   Password: ${ARGOCD_PASSWORD:-<run command above to get>}"
echo ""
echo "4. ArgoCD CLI (optional):"
echo "   brew install argocd"
echo "   argocd login localhost:8080"
echo ""
echo "5. View application status:"
echo "   kubectl get applications -n finans-asistan"
echo "   argocd app get finans-asistan -n finans-asistan"
echo ""

