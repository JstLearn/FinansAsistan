# ════════════════════════════════════════════════════════════
# FinansAsistan - Remove ArgoCD from default namespace
# Removes ArgoCD from default namespace (should be in finans-asistan)
# ════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"

function Write-Info {
    Write-Host "[INFO] $args" -ForegroundColor Blue
}

function Write-Success {
    Write-Host "[SUCCESS] $args" -ForegroundColor Green
}

function Write-Warn {
    Write-Host "[WARN] $args" -ForegroundColor Yellow
}

$SOURCE_NAMESPACE = "default"
$TARGET_NAMESPACE = "finans-asistan"

Write-Info "Removing ArgoCD from '$SOURCE_NAMESPACE' namespace..."

# Check if ArgoCD exists in default namespace
$deployments = kubectl get deployments -n $SOURCE_NAMESPACE -o name 2>&1 | Select-String argocd
if (-not $deployments) {
    Write-Info "No ArgoCD deployments found in $SOURCE_NAMESPACE namespace"
    exit 0
}

Write-Warn "Found ArgoCD in $SOURCE_NAMESPACE namespace. This should be in $TARGET_NAMESPACE namespace."
Write-Info "Removing ArgoCD from $SOURCE_NAMESPACE namespace..."

# Delete ArgoCD deployments
Write-Info "Deleting ArgoCD deployments..."
kubectl delete deployment -n $SOURCE_NAMESPACE -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
kubectl delete deployment argocd-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete deployment argocd-repo-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete deployment argocd-applicationset-controller -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete deployment argocd-dex-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete deployment argocd-notifications-controller -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete deployment argocd-redis -n $SOURCE_NAMESPACE 2>&1 | Out-Null

# Delete ArgoCD statefulsets
Write-Info "Deleting ArgoCD statefulsets..."
kubectl delete statefulset argocd-application-controller -n $SOURCE_NAMESPACE 2>&1 | Out-Null

# Delete ArgoCD services
Write-Info "Deleting ArgoCD services..."
kubectl delete service -n $SOURCE_NAMESPACE -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
kubectl delete service argocd-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-repo-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-redis -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-dex-server -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-applicationset-controller -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-metrics -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-server-metrics -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete service argocd-notifications-controller-metrics -n $SOURCE_NAMESPACE 2>&1 | Out-Null

# Delete ArgoCD configmaps
Write-Info "Deleting ArgoCD configmaps..."
kubectl delete configmap -n $SOURCE_NAMESPACE -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
kubectl delete configmap argocd-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-rbac-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-cmd-params-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-gpg-keys-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-notifications-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-ssh-known-hosts-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete configmap argocd-tls-certs-cm -n $SOURCE_NAMESPACE 2>&1 | Out-Null

# Delete ArgoCD secrets
Write-Info "Deleting ArgoCD secrets..."
kubectl delete secret -n $SOURCE_NAMESPACE -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
kubectl delete secret argocd-secret -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete secret argocd-initial-admin-secret -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete secret argocd-notifications-secret -n $SOURCE_NAMESPACE 2>&1 | Out-Null
kubectl delete secret argocd-redis -n $SOURCE_NAMESPACE 2>&1 | Out-Null

# Wait for resources to be deleted
Write-Info "Waiting for resources to be deleted..."
Start-Sleep -Seconds 5

# Check remaining ArgoCD resources
Write-Info "Checking remaining ArgoCD resources in $SOURCE_NAMESPACE namespace..."
$remaining = kubectl get all,configmaps,secrets -n $SOURCE_NAMESPACE 2>&1 | Select-String argocd
if ($remaining) {
    Write-Warn "Some ArgoCD resources are still present:"
    $remaining | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Success "All ArgoCD resources removed from $SOURCE_NAMESPACE namespace!"
}

Write-Info "ArgoCD should now be installed in $TARGET_NAMESPACE namespace using bootstrap script."

