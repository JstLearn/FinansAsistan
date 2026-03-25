#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - ArgoCD Refresh Script
# Forces ArgoCD to refresh and sync to latest Git commit
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

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-finans-asistan}"
APP_NAME="${APP_NAME:-finans-asistan}"

log_info "Refreshing ArgoCD application: ${APP_NAME}"
log_info "Namespace: ${ARGOCD_NAMESPACE}"

# Check if ArgoCD CLI is available
if command -v argocd &> /dev/null; then
    log_info "Using ArgoCD CLI to refresh application..."
    
    # Refresh application (hard refresh)
    argocd app get "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" &>/dev/null || {
        log_error "Application ${APP_NAME} not found in namespace ${ARGOCD_NAMESPACE}"
        exit 1
    }
    
    # Hard refresh
    argocd app get "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" --refresh || {
        log_warn "Refresh command failed, trying alternative method..."
    }
    
    # Sync application
    log_info "Syncing application to latest commit..."
    argocd app sync "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" || {
        log_warn "Sync command failed, application may be set to auto-sync"
    }
    
    # Show application status
    log_info "Current application status:"
    argocd app get "${APP_NAME}" -n "${ARGOCD_NAMESPACE}"
else
    log_info "ArgoCD CLI not found, using kubectl to refresh..."
    
    # Check if application exists
    if ! kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_error "Application ${APP_NAME} not found in namespace ${ARGOCD_NAMESPACE}"
        exit 1
    fi
    
    # Trigger refresh by patching annotation
    log_info "Triggering hard refresh via annotation..."
    kubectl patch application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" \
        -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
        --type merge
    
    # Wait a moment for refresh to trigger
    sleep 2
    
    # Remove annotation to allow future refreshes
    kubectl patch application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" \
        -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":null}}}' \
        --type merge || true
    
    # Show application status
    log_info "Current application status:"
    kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o yaml | grep -A 5 "status:" || true
    
    log_info "Application revision:"
    kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.revision}' || true
    echo ""
    
    log_info "Sync status:"
    kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}' || true
    echo ""
fi

log_success "Refresh completed!"
log_info "Monitor sync status with:"
echo "  kubectl get application ${APP_NAME} -n ${ARGOCD_NAMESPACE}"
echo "  kubectl get application ${APP_NAME} -n ${ARGOCD_NAMESPACE} -o jsonpath='{.status.sync.revision}'"

