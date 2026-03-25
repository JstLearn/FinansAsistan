# ════════════════════════════════════════════════════════════
# FinansAsistan - ArgoCD Refresh Script (PowerShell)
# Forces ArgoCD to refresh and sync to latest Git commit
# ════════════════════════════════════════════════════════════

param(
    [string]$ArgoCDNamespace = "finans-asistan",
    [string]$AppName = "finans-asistan"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed"
    exit 1
}

Write-Info "Refreshing ArgoCD application: $AppName"
Write-Info "Namespace: $ArgoCDNamespace"

# Check if ArgoCD CLI is available
if (Get-Command argocd -ErrorAction SilentlyContinue) {
    Write-Info "Using ArgoCD CLI to refresh application..."
    
    # Check if application exists
    $appExists = argocd app get "$AppName" -n "$ArgoCDNamespace" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Application $AppName not found in namespace $ArgoCDNamespace"
        exit 1
    }
    
    # Hard refresh
    Write-Info "Triggering hard refresh..."
    argocd app get "$AppName" -n "$ArgoCDNamespace" --refresh 2>&1 | Out-Null
    
    # Sync application
    Write-Info "Syncing application to latest commit..."
    argocd app sync "$AppName" -n "$ArgoCDNamespace" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Sync command failed, application may be set to auto-sync"
    }
    
    # Show application status
    Write-Info "Current application status:"
    argocd app get "$AppName" -n "$ArgoCDNamespace"
} else {
    Write-Info "ArgoCD CLI not found, using kubectl to refresh..."
    
    # Check if application exists
    $appCheck = kubectl get application "$AppName" -n "$ArgoCDNamespace" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Application $AppName not found in namespace $ArgoCDNamespace"
        exit 1
    }
    
    # Trigger refresh by patching annotation
    Write-Info "Triggering hard refresh via annotation..."
    $patchJson = @{
        metadata = @{
            annotations = @{
                "argocd.argoproj.io/refresh" = "hard"
            }
        }
    } | ConvertTo-Json -Compress
    
    kubectl patch application "$AppName" -n "$ArgoCDNamespace" `
        -p $patchJson `
        --type merge | Out-Null
    
    # Wait a moment for refresh to trigger
    Start-Sleep -Seconds 2
    
    # Remove annotation to allow future refreshes
    $removePatchJson = @{
        metadata = @{
            annotations = @{
                "argocd.argoproj.io/refresh" = $null
            }
        }
    } | ConvertTo-Json -Compress
    
    kubectl patch application "$AppName" -n "$ArgoCDNamespace" `
        -p $removePatchJson `
        --type merge 2>&1 | Out-Null
    
    # Show application status
    Write-Info "Current application status:"
    kubectl get application "$AppName" -n "$ArgoCDNamespace" -o yaml | Select-String -Pattern "status:" -Context 0,5
    
    Write-Info "Application revision:"
    $revision = kubectl get application "$AppName" -n "$ArgoCDNamespace" -o jsonpath='{.status.sync.revision}' 2>&1
    Write-Host $revision
    Write-Host ""
    
    Write-Info "Sync status:"
    $syncStatus = kubectl get application "$AppName" -n "$ArgoCDNamespace" -o jsonpath='{.status.sync.status}' 2>&1
    Write-Host $syncStatus
    Write-Host ""
}

Write-Success "Refresh completed!"
Write-Info "Monitor sync status with:"
Write-Host "  kubectl get application $AppName -n $ArgoCDNamespace"
Write-Host "  kubectl get application $AppName -n $ArgoCDNamespace -o jsonpath='{.status.sync.revision}'"

